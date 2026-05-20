import 'dart:async'; // Necessario per il Timer del Debounce
import 'package:agreeo/features/friends/presentation/friend_profile_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_waiting_room_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_wizard_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Gestione intelligente della ricerca (evita spam al backend)
  void _onSearchChanged(String query) {
    ref
        .read(friendsMovieNightControllerProvider.notifier)
        .searchFriends(query, syncBackend: false);
    setState(
      () {},
    ); // Aggiorna la UI per mostrare i risultati solo se c'è testo

    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref
          .read(friendsMovieNightControllerProvider.notifier)
          .searchFriends(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final socialState = ref.watch(friendsMovieNightControllerProvider);
    final controller = ref.read(friendsMovieNightControllerProvider.notifier);
    final theme = Theme.of(context);
    final searchQuery = _searchController.text.trim();

    // Stile salvavita per evitare il crash "BoxConstraints(w=Infinity)"
    final safeButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      maximumSize: const Size(220, 48), // Impedisce l'espansione infinita
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
          children: <Widget>[
            SectionHeader(
              title: 'Friends',
              subtitle:
                  'Build better movie nights from people, preferences, and clear votes.',
              trailing: FilledButton.icon(
                onPressed: _openCreateMovieNight,
                icon: const Icon(Icons.local_movies_outlined),
                label: const Text('Create Movie Night'),
                style: safeButtonStyle, // Applicato per evitare il crash
              ),
            ),
            const SizedBox(height: 18),
            AgreeoSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Search friends by name',
              onChanged: _onSearchChanged,
            ),
            if (searchQuery.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _SearchResults(
                results: socialState.searchResults,
                socialState: socialState,
                onAccept: (requestId) {
                  controller.acceptFriendRequest(requestId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request accepted.')),
                  );
                },
                onAdd: (friend) {
                  controller.sendFriendRequest(friend.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Friend request sent to ${friend.name}.'),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            _RequestsSection(
              requests: socialState.incomingRequests,
              onAccept: (requestId) {
                controller.acceptFriendRequest(requestId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Friend request accepted.')),
                );
              },
              onDecline: (requestId) {
                controller.declineFriendRequest(requestId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Friend request declined.')),
                );
              },
            ),
            const SizedBox(height: 26),
            const SectionHeader(
              title: 'Your friends',
              subtitle: 'People available for future Movie Nights.',
            ),
            const SizedBox(height: 14),
            _FriendsListSection(
              friends: socialState.friends,
              onFriendTap: _openFriend,
              onRemoveFriend: (friend) {
                controller.removeFriend(friend.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${friend.name} removed.')),
                );
              },
              onBlockFriend: (friend) {
                controller.blockFriend(friend.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${friend.name} blocked.')),
                );
              },
              onFindFriendsTap: () {
                _searchFocusNode.requestFocus(); // Apre la tastiera
                final searchContext = _searchFocusNode.context;
                if (searchContext != null) {
                  Scrollable.ensureVisible(
                    searchContext,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Movie Nights',
              subtitle: 'Active and completed group decisions stay here.',
              trailing: IconButton.filledTonal(
                onPressed: _openCreateMovieNight,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            const SizedBox(height: 14),
            if (socialState.movieNights.isEmpty)
              EmptyState(
                icon: Icons.nightlight_round,
                title: 'No Movie Nights yet',
                message:
                    'Create one, invite friends, generate a shortlist, then vote together.',
                action: FilledButton(
                  onPressed: _openCreateMovieNight,
                  style: safeButtonStyle, // Applicato per evitare il crash
                  child: const Text('Create Movie Night'),
                ),
              )
            else
              ...socialState.movieNights.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MovieNightCard(
                    event: event,
                    onTap: () => _openEvent(event),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFriend(Friend friend) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendProfileScreen(friendId: friend.id),
      ),
    );
  }

  void _openCreateMovieNight() {
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
}

class _FriendsListSection extends StatelessWidget {
  const _FriendsListSection({
    required this.friends,
    required this.onFriendTap,
    required this.onRemoveFriend,
    required this.onBlockFriend,
    required this.onFindFriendsTap,
  });

  final List<Friend> friends;
  final ValueChanged<Friend> onFriendTap;
  final ValueChanged<Friend> onRemoveFriend;
  final ValueChanged<Friend> onBlockFriend;
  final VoidCallback onFindFriendsTap;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No friends yet',
        message:
            'Search for friends and start building better movie nights together.',
        action: FilledButton(
          onPressed: onFindFriendsTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            maximumSize: const Size(200, 48),
          ),
          child: const Text('Find friends'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ...friends.map(
          (friend) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FriendCard(
              friend: friend,
              onTap: () => onFriendTap(friend),
              onRemove: () => onRemoveFriend(friend),
              onBlock: () => onBlockFriend(friend),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.onTap,
    required this.onRemove,
    required this.onBlock,
  });

  final Friend friend;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              UserAvatar(initials: friend.initials),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      friend.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${friend.watchedCount} watched • ${friend.reviewsCount} reviews',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'remove') {
                    onRemove();
                  } else if (value == 'block') {
                    onBlock();
                  }
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Text('Remove friend'),
                  ),
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Text('Block friend'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection({
    required this.requests,
    required this.onAccept,
    required this.onDecline,
  });

  final List<FriendRequest> requests;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Friend requests',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      requests.isEmpty
                          ? 'No pending requests right now.'
                          : '${requests.length} pending request${requests.length == 1 ? '' : 's'} to review.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              InfoBadge(label: '${requests.length}'),
            ],
          ),
          const SizedBox(height: 14),
          if (requests.isEmpty)
            Text(
              'Incoming requests will appear here with Accept and Decline actions.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            )
          else
            ...requests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FriendRequestCard(
                  request: request,
                  onAccept: () => onAccept(request.id),
                  onDecline: () => onDecline(request.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                UserAvatar(initials: request.fromUser.initials, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        request.fromUser.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.fromUser.watchedCount} watched • ${request.fromUser.reviewsCount} reviews',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.socialState,
    required this.onAccept,
    required this.onAdd,
  });

  final List<Friend> results;
  final FriendsMovieNightState socialState;
  final ValueChanged<String> onAccept;
  final ValueChanged<Friend> onAdd;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search_outlined,
        title: 'No matching people',
        message: 'Try another name or invite friends with a Movie Night link.',
      );
    }
    return Column(
      children: results
          .map((friend) {
            final isFriend = socialState.isFriend(friend.id);
            final pending = socialState.isPending(friend.id);
            final incomingRequestId = socialState.incomingRequestIdFor(
              friend.id,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: UserAvatar(initials: friend.initials),
                  title: Text(friend.name),
                  subtitle: const Text('Mutual movie taste preview soon'),
                  trailing: FilledButton.tonal(
                    onPressed:
                        isFriend || (pending && incomingRequestId == null)
                        ? null
                        : incomingRequestId != null
                        ? () => onAccept(incomingRequestId)
                        : () => onAdd(friend),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      maximumSize: const Size(120, 40), // Impedisce crash
                    ),
                    child: Text(
                      isFriend
                          ? 'Friends'
                          : incomingRequestId != null
                          ? 'Accept'
                          : pending
                          ? 'Pending'
                          : 'Add Friend',
                    ),
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _MovieNightCard extends StatelessWidget {
  const _MovieNightCard({required this.event, required this.onTap});

  final MovieNightEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winner = event.winnerCandidate?.movie.title;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      event.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  InfoBadge(label: _statusLabel(event.status)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Host • ${event.participants.length} participants • ${_dateLabel(event.dateTime)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(label: Text(event.contentTypeLabel)),
                  if (event.constraints.includedGenres.isNotEmpty)
                    Chip(
                      label: Text(event.constraints.includedGenres.join(', ')),
                    ),
                  if (event.constraints.maxDurationMinutes != null)
                    Chip(
                      label: Text(
                        'Up to ${event.constraints.maxDurationMinutes}m',
                      ),
                    ),
                  if (winner != null) Chip(label: Text('Winner: $winner')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(MovieNightStatus status) {
    switch (status) {
      case MovieNightStatus.draft:
        return 'Draft';
      case MovieNightStatus.waiting:
        return 'Waiting for friends';
      case MovieNightStatus.voting:
        return 'Voting';
      case MovieNightStatus.completed:
        return 'Completed';
    }
  }
}

String _dateLabel(DateTime? dateTime) {
  if (dateTime == null) {
    return 'Date optional';
  }
  return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
}
