import 'dart:async';

import 'package:agreeo/features/friends/presentation/friend_profile_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_waiting_room_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_wizard_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/profile/presentation/profile_screen.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:agreeo/shared/utils/movie_night_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(friendsMovieNightControllerProvider.notifier).searchFriends(query, syncBackend: false);
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(friendsMovieNightControllerProvider.notifier).searchFriends(query);
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openFriend(Friend friend) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FriendProfileScreen(friendId: friend.id)),
    );
  }

  void _openCreateMovieNight() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MovieNightWizardScreen()),
    );
  }

  void _openEvent(MovieNightEvent event) {
    final route = switch (event.status) {
      MovieNightStatus.draft || MovieNightStatus.waiting =>
        MovieNightWaitingRoomScreen(eventId: event.id),
      MovieNightStatus.voting => MovieNightVotingScreen(eventId: event.id),
      MovieNightStatus.completed => MovieNightResultScreen(eventId: event.id),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => route));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final social = ref.watch(friendsMovieNightControllerProvider);
    final controller = ref.read(friendsMovieNightControllerProvider.notifier);
    final appState = ref.watch(agreeoAppControllerProvider);
    final query = _searchController.text.trim();
    final friends = [...social.friends]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final requests = social.incomingRequests;
    final activeNights = social.movieNights
        .where((e) => e.status != MovieNightStatus.completed)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: controller.refreshSocialLayer,
              color: t.red,
              backgroundColor: t.surface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 180),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Friends',
                          style: TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontWeight: FontWeight.w800,
                            fontSize: 27,
                            letterSpacing: -0.6,
                            color: t.text,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const AgreeoProfileScreen()),
                        ),
                        child: AgAvatar(name: appState.session?.displayName ?? 'You', color: t.red, size: 42),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AgSearchField(
                    controller: _searchController,
                    hint: 'Find friends by name…',
                    onChanged: _onSearchChanged,
                  ),
                  if (query.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SearchResults(
                      results: social.searchResults,
                      social: social,
                      onAccept: (id) {
                        controller.acceptFriendRequest(id);
                        _toast('Friend request accepted.');
                      },
                      onAdd: (f) {
                        controller.sendFriendRequest(f.id);
                        _toast('Friend request sent to ${f.name}.');
                      },
                    ),
                  ],
                  if (requests.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Text(
                          'Requests',
                          style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 15, color: t.text),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: t.red, shape: BoxShape.circle),
                          child: Text(
                            '${requests.length}',
                            style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final r in requests)
                      _RequestRow(
                        request: r,
                        onAccept: () {
                          controller.acceptFriendRequest(r.id);
                          _toast('Friend request accepted.');
                        },
                        onDecline: () {
                          controller.declineFriendRequest(r.id);
                          _toast('Friend request declined.');
                        },
                      ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'All friends · ${friends.length}',
                    style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 15, color: t.text),
                  ),
                  const SizedBox(height: 12),
                  if (friends.isEmpty)
                    Text(
                      'No friends yet — search above to connect.',
                      style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, color: t.faint),
                    )
                  else
                    for (final f in friends)
                      _FriendRow(friend: f, onTap: () => _openFriend(f), onInvite: _openCreateMovieNight),
                  if (activeNights.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'Movie Nights',
                      style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 15, color: t.text),
                    ),
                    const SizedBox(height: 12),
                    for (final e in activeNights)
                      _MovieNightRow(event: e, onTap: () => _openEvent(e)),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 96,
              child: AgButton(label: 'Start a Movie Night', icon: AgIcons.film, onPressed: _openCreateMovieNight),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onTap, required this.onInvite});
  final Friend friend;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
        child: Row(
          children: [
            AgAvatar(name: friend.name, imageUrl: friend.avatarUrl, size: 46),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 15, color: t.text),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${friend.watchedCount} watched · ${friend.reviewsCount} reviews',
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: t.faint),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onInvite,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: t.gradSoft,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: t.line2),
                ),
                child: Text(
                  'Invite',
                  style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12.5, color: t.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request, required this.onAccept, required this.onDecline});
  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final f = request.fromUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          AgAvatar(name: f.name, imageUrl: f.avatarUrl, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.name,
                  style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 15, color: t.text),
                ),
                const SizedBox(height: 1),
                Text(
                  '${f.watchedCount} watched · ${f.reviewsCount} reviews',
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: t.faint),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAccept,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(gradient: t.grad, borderRadius: BorderRadius.circular(11)),
              child: const Icon(AgIcons.check, size: 19, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDecline,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: t.line2),
              ),
              child: Icon(AgIcons.close, size: 18, color: t.sub),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.social,
    required this.onAccept,
    required this.onAdd,
  });
  final List<Friend> results;
  final FriendsMovieNightState social;
  final ValueChanged<String> onAccept;
  final ValueChanged<Friend> onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line),
        ),
        child: Text(
          'No matching people. Try another name.',
          style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, color: t.sub),
        ),
      );
    }
    return Column(
      children: [
        for (final f in results)
          Builder(builder: (context) {
            final isFriend = social.isFriend(f.id);
            final pending = social.isPending(f.id);
            final incomingId = social.incomingRequestIdFor(f.id);
            final label = isFriend
                ? 'Friends'
                : incomingId != null
                    ? 'Accept'
                    : pending
                        ? 'Pending'
                        : 'Add';
            final enabled = !isFriend && !(pending && incomingId == null);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  AgAvatar(name: f.name, imageUrl: f.avatarUrl, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f.name,
                      style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 14.5, color: t.text),
                    ),
                  ),
                  GestureDetector(
                    onTap: enabled
                        ? () => incomingId != null ? onAccept(incomingId) : onAdd(f)
                        : null,
                    child: Opacity(
                      opacity: enabled ? 1 : 0.5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: enabled ? t.grad : null,
                          color: enabled ? null : t.surface2,
                          borderRadius: BorderRadius.circular(11),
                          border: enabled ? null : Border.all(color: t.line2),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: enabled ? Colors.white : t.sub,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _MovieNightRow extends StatelessWidget {
  const _MovieNightRow({required this.event, required this.onTap});
  final MovieNightEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.line),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(gradient: t.grad, borderRadius: BorderRadius.circular(14)),
              child: const Icon(AgIcons.film, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 16, color: t.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.participants.length} participants · ${movieNightStatusLabel(event.status)}',
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 12.5, color: t.sub),
                  ),
                ],
              ),
            ),
            Icon(AgIcons.chevron, size: 20, color: t.faint),
          ],
        ),
      ),
    );
  }
}
