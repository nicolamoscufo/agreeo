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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socialState = ref.watch(friendsMovieNightControllerProvider);
    final controller = ref.read(friendsMovieNightControllerProvider.notifier);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF07111F), Color(0xFF111827)],
        ),
      ),
      child: SafeArea(
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
              ),
            ),
            const SizedBox(height: 22),
            _FriendsListSection(
              friends: socialState.friends,
              onFriendTap: _openFriend,
            ),
            const SizedBox(height: 26),
            _RequestsSection(
              requests: socialState.incomingRequests,
              onAccept: controller.acceptFriendRequest,
              onDecline: controller.declineFriendRequest,
            ),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Search friends',
              subtitle: 'Invite people who help the group decide faster.',
            ),
            const SizedBox(height: 14),
            AgreeoSearchBar(
              controller: _searchController,
              hintText: 'Search by name',
              onChanged: controller.searchFriends,
            ),
            const SizedBox(height: 14),
            _SearchResults(
              results: socialState.searchResults,
              socialState: socialState,
              onAdd: (friend) {
                controller.sendFriendRequest(friend.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Friend request sent to ${friend.name}.'),
                  ),
                );
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
  const _FriendsListSection({required this.friends, required this.onFriendTap});

  final List<Friend> friends;
  final ValueChanged<Friend> onFriendTap;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No friends yet',
        message:
            'Search for friends and start building better movie nights together.',
        action: FilledButton(
          onPressed: () {},
          child: const Text('Find friends'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Friends list',
          subtitle: 'Tap a friend to view shared movie context.',
        ),
        const SizedBox(height: 14),
        ...friends.map(
          (friend) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FriendCard(
              friend: friend,
              onTap: () => onFriendTap(friend),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend, required this.onTap});

  final Friend friend;
  final VoidCallback onTap;

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
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Text('Remove friend later'),
                  ),
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Text('Block later'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Friend requests',
          subtitle: 'Accept people you want in future Movie Nights.',
        ),
        const SizedBox(height: 14),
        if (requests.isEmpty)
          const EmptyState(
            icon: Icons.mark_email_read_outlined,
            title: 'No pending requests',
            message: 'Incoming requests will appear here.',
          )
        else
          ...requests.map(
            (request) => Card(
              child: ListTile(
                leading: UserAvatar(initials: request.fromUser.initials),
                title: Text(request.fromUser.name),
                subtitle: Text(
                  '${request.fromUser.watchedCount} watched • ${request.fromUser.reviewsCount} reviews',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => onDecline(request.id),
                      child: const Text('Decline'),
                    ),
                    FilledButton(
                      onPressed: () => onAccept(request.id),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.socialState,
    required this.onAdd,
  });

  final List<Friend> results;
  final FriendsMovieNightState socialState;
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: UserAvatar(initials: friend.initials),
                  title: Text(friend.name),
                  subtitle: const Text('Mutual movie taste preview soon'),
                  trailing: FilledButton.tonal(
                    onPressed: isFriend || pending ? null : () => onAdd(friend),
                    child: Text(
                      isFriend
                          ? 'Friends'
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
