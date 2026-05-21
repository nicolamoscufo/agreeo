import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/catalog/genre_options.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/utils/movie_night_utils.dart';
import 'package:agreeo/services/real_time_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MovieNightWaitingRoomScreen extends ConsumerStatefulWidget {
  const MovieNightWaitingRoomScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<MovieNightWaitingRoomScreen> createState() =>
      _MovieNightWaitingRoomScreenState();
}

class _MovieNightWaitingRoomScreenState
    extends ConsumerState<MovieNightWaitingRoomScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final socialState = ref.watch(friendsMovieNightControllerProvider);
    final controller = ref.read(friendsMovieNightControllerProvider.notifier);
    final appState = ref.watch(agreeoAppControllerProvider);
    final isLive = ref.watch(realTimeConnectionProvider);
    final event = socialState.eventById(widget.eventId);
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Waiting Room')),
        body: const Center(child: Text('Movie Night not found')),
      );
    }

    if (event.status == MovieNightStatus.voting && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => MovieNightVotingScreen(eventId: event.id),
            ),
          );
        }
      });
    } else if (event.status == MovieNightStatus.completed && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => MovieNightResultScreen(eventId: event.id),
            ),
          );
        }
      });
    }

    final pendingCount = event.participants
        .where(
          (participant) =>
              participant.status == MovieNightParticipantStatus.pending,
        )
        .length;
    final currentUserId = appState.session?.id ?? 'local-host';
    final currentParticipant = _participantFor(event, currentUserId);
    final isHost =
        currentParticipant?.isHost == true || event.hostUserId == currentUserId;
    final canJoin =
        event.status == MovieNightStatus.waiting &&
        currentParticipant?.status == MovieNightParticipantStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ConnectionBadge(isLive: isLive),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await controller.refreshMovieNight(event.id);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: <Widget>[
              SectionHeader(
                title: event.name,
                subtitle: 'Confirm the group and constraints before voting.',
                trailing: InfoBadge(label: movieNightStatusLabel(event.status)),
              ),
              const SizedBox(height: 18),
              _SummaryCard(event: event),
              const SizedBox(height: 18),
              _ParticipantsCard(participants: event.participants),
              if (event.inviteLink.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.link_rounded),
                    title: const Text('Invite Link'),
                    subtitle: Text(
                      event.inviteLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: event.inviteLink),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invite link copied!'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
              if (canJoin) ...<Widget>[
                const SizedBox(height: 12),
                _JoinMovieNightCard(
                  onJoin: () async {
                    final updated = await controller.joinMovieNight(event.id);
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          updated == null
                              ? 'Could not join this Movie Night.'
                              : 'You joined this Movie Night.',
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (pendingCount > 0) ...<Widget>[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.55),
                  child: const ListTile(
                    leading: Icon(Icons.warning_amber_rounded),
                    title: Text('Some friends have not joined yet.'),
                    subtitle: Text('The host can still start voting.'),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (isHost) ...<Widget>[
                const SectionHeader(
                  title: 'Host controls',
                  subtitle:
                      'Adjust constraints, share invite link, or start voting.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final updatedEvent = await controller.createInviteLink(
                          event.id,
                        );
                        if (!context.mounted) return;
                        final link = updatedEvent?.inviteLink;
                        if (link != null && link.isNotEmpty) {
                          await Clipboard.setData(ClipboardData(text: link));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invite link copied to clipboard!'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not create invite link.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share invite link'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final existingIds = event.participants
                            .map((p) => p.userId)
                            .toSet();
                        final invitedIds =
                            await showModalBottomSheet<List<String>>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (_) => _InviteFriendsSheet(
                                friends: socialState.friends,
                                existingParticipantIds: existingIds,
                              ),
                            );
                        if (invitedIds == null || invitedIds.isEmpty) return;
                        final updated = await controller.inviteFriends(
                          eventId: event.id,
                          friendIds: invitedIds,
                        );
                        if (!context.mounted) return;
                        if (updated == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not invite friends.'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invitations sent!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Invite friends'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final updatedConstraints =
                            await showModalBottomSheet<MovieNightConstraints>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (_) => _EditConstraintsSheet(
                                initialConstraints: event.constraints,
                              ),
                            );
                        if (updatedConstraints == null) {
                          return;
                        }
                        final updatedEvent = await controller
                            .updateEventConstraints(
                              eventId: event.id,
                              constraints: updatedConstraints,
                            );
                        if (updatedEvent == null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not update constraints.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Edit constraints'),
                    ),
                    Builder(
                      builder: (context) {
                        final isInFlight = socialState.inflightEventIds
                            .contains(event.id);
                        final canStart = !isInFlight;
                        return FilledButton.icon(
                          onPressed: canStart
                              ? () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Start Voting?'),
                                      content: const Text(
                                        'This will generate the shortlist and begin the voting session. '
                                        'All joined participants will be asked to vote.\n\n'
                                        'This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Start Voting'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true || !context.mounted) {
                                    return;
                                  }
                                  final updated = await controller.startVoting(
                                    event.id,
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  if (updated == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not start voting.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          icon: isInFlight
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.how_to_vote_rounded),
                          label: isInFlight
                              ? const Text('Starting...')
                              : const Text('Start voting'),
                        );
                      },
                    ),
                  ],
                ),
              ] else ...<Widget>[
                const SectionHeader(
                  title: 'Waiting for host',
                  subtitle:
                      'Only the host can edit constraints or start voting.',
                ),
                const SizedBox(height: 12),
                _NonHostInfoCard(
                  event: event,
                  canLeave: currentParticipant != null,
                  onLeave: () => _leaveEvent(event),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leaveEvent(MovieNightEvent event) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave this Movie Night?'),
          content: Text(
            'You will leave "${event.name}" and stop receiving updates.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Leave event'),
            ),
          ],
        );
      },
    );
    if (shouldLeave != true) {
      return;
    }
    final left = await ref
        .read(friendsMovieNightControllerProvider.notifier)
        .leaveMovieNight(event.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          left
              ? 'You left this Movie Night.'
              : 'Could not leave this Movie Night.',
        ),
      ),
    );
    if (left) {
      Navigator.of(context).pop();
    }
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final color = isLive ? AgreeoColors.kernelGold : AgreeoColors.cinematicRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isLive ? 'Live' : 'Offline',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.event});

  final MovieNightEvent event;

  @override
  Widget build(BuildContext context) {
    final constraints = event.constraints;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Event summary',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text(event.contentTypeLabel)),
                if (event.dateTime != null)
                  Chip(
                    label: Text(
                      movieNightDateLabel(event.dateTime, includeTime: true),
                    ),
                  ),
                if (constraints.includedGenres.isNotEmpty)
                  Chip(
                    label: Text(
                      'Include ${constraints.includedGenres.join(', ')}',
                    ),
                  ),
                if (constraints.excludedGenres.isNotEmpty)
                  Chip(
                    label: Text(
                      'Exclude ${constraints.excludedGenres.join(', ')}',
                    ),
                  ),
                if (constraints.maxDurationMinutes != null)
                  Chip(label: Text('Max ${constraints.maxDurationMinutes}m')),
                if (constraints.minimumRating != null)
                  Chip(
                    label: Text(
                      'Rating ${constraints.minimumRating!.toStringAsFixed(0)}+',
                    ),
                  ),
                if (constraints.language != null)
                  Chip(label: Text('Language ${constraints.language}')),
              ],
            ),
            if (event.dateTime != null &&
                event.dateTime!.isAfter(DateTime.now())) ...<Widget>[
              const SizedBox(height: 12),
              _CountdownChip(dateTime: event.dateTime!),
            ],
          ],
        ),
      ),
    );
  }
}

class _NonHostInfoCard extends StatelessWidget {
  const _NonHostInfoCard({
    required this.event,
    required this.canLeave,
    required this.onLeave,
  });

  final MovieNightEvent event;
  final bool canLeave;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'What happens next',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(movieNightConstraintsLabel(event.constraints)),
            const SizedBox(height: 10),
            const Text(
              'The system will shortlist movies from everyone\'s taste and constraints, then the group votes together.',
            ),
            const SizedBox(height: 14),
            if (canLeave)
              OutlinedButton.icon(
                onPressed: onLeave,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Leave event'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantsCard extends StatelessWidget {
  const _ParticipantsCard({required this.participants});

  final List<MovieNightParticipant> participants;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Participants',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...participants.map(
              (participant) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(initials: participant.initials),
                title: Text(participant.name),
                subtitle: Text(participant.isHost ? 'Host' : 'Invited friend'),
                trailing: InfoBadge(
                  label:
                      participant.status == MovieNightParticipantStatus.joined
                      ? 'Joined'
                      : 'Pending',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinMovieNightCard extends StatelessWidget {
  const _JoinMovieNightCard({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: ListTile(
        leading: const Icon(Icons.group_add_rounded),
        title: const Text('Join this Movie Night'),
        subtitle: const Text(
          'Join before voting starts so your preferences shape the recommendations.',
        ),
        trailing: FilledButton(onPressed: onJoin, child: const Text('Join')),
      ),
    );
  }
}

class _EditConstraintsSheet extends StatefulWidget {
  const _EditConstraintsSheet({required this.initialConstraints});

  final MovieNightConstraints initialConstraints;

  @override
  State<_EditConstraintsSheet> createState() => _EditConstraintsSheetState();
}

class _EditConstraintsSheetState extends State<_EditConstraintsSheet> {
  late final Set<String> _included = widget.initialConstraints.includedGenres
      .toSet();
  late final Set<String> _excluded = widget.initialConstraints.excludedGenres
      .toSet();
  late int _maxDuration = widget.initialConstraints.maxDurationMinutes ?? 150;
  late double? _minimumRating = widget.initialConstraints.minimumRating;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Edit constraints',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Included genres'),
              const SizedBox(height: 8),
              _GenreSheetWrap(
                selected: _included,
                disabled: _excluded,
                onTap: (genre) => setState(() {
                  if (!_included.add(genre)) {
                    _included.remove(genre);
                  }
                  _excluded.remove(genre);
                }),
              ),
              const SizedBox(height: 16),
              const Text('Excluded genres'),
              const SizedBox(height: 8),
              _GenreSheetWrap(
                selected: _excluded,
                disabled: _included,
                onTap: (genre) => setState(() {
                  if (!_excluded.add(genre)) {
                    _excluded.remove(genre);
                  }
                  _included.remove(genre);
                }),
              ),
              const SizedBox(height: 16),
              Text('Maximum duration: ${_maxDuration}m'),
              Slider(
                value: _maxDuration.toDouble(),
                min: 80,
                max: 210,
                divisions: 13,
                onChanged: (value) =>
                    setState(() => _maxDuration = value.round()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    selected: _minimumRating == null,
                    label: const Text('Any rating'),
                    onSelected: (_) => setState(() => _minimumRating = null),
                  ),
                  for (final rating in const <double>[6, 7, 8])
                    ChoiceChip(
                      selected: _minimumRating == rating,
                      label: Text('${rating.toStringAsFixed(0)}+'),
                      onSelected: (_) =>
                          setState(() => _minimumRating = rating),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    widget.initialConstraints.copyWith(
                      includedGenres: _included.toList(growable: false),
                      excludedGenres: _excluded.toList(growable: false),
                      maxDurationMinutes: _maxDuration,
                      minimumRating: _minimumRating,
                      clearMinimumRating: _minimumRating == null,
                    ),
                  );
                },
                child: const Text('Save constraints'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreSheetWrap extends StatelessWidget {
  const _GenreSheetWrap({
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final Set<String> selected;
  final Set<String> disabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: agreeoGenreOptions
          .map((genre) {
            final isDisabled = disabled.contains(genre);
            return Opacity(
              opacity: isDisabled ? 0.45 : 1,
              child: SelectableChip(
                label: genre,
                selected: selected.contains(genre),
                onTap: isDisabled ? () {} : () => onTap(genre),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

MovieNightParticipant? _participantFor(MovieNightEvent event, String userId) {
  for (final participant in event.participants) {
    if (participant.userId == userId) {
      return participant;
    }
  }
  return null;
}

class _InviteFriendsSheet extends StatefulWidget {
  const _InviteFriendsSheet({
    required this.friends,
    required this.existingParticipantIds,
  });

  final List<Friend> friends;
  final Set<String> existingParticipantIds;

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  late final List<Friend> _inviteableFriends;

  @override
  void initState() {
    super.initState();
    _inviteableFriends = widget.friends
        .where((f) => !widget.existingParticipantIds.contains(f.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _inviteableFriends
        : _inviteableFriends
              .where(
                (f) =>
                    f.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Invite Friends',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search friends',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No inviteable friends found.')),
              )
            else
              SizedBox(
                height: 250,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final friend = filtered[index];
                    final isSelected = _selectedIds.contains(friend.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(friend.name),
                      secondary: UserAvatar(initials: friend.initials),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedIds.add(friend.id);
                          } else {
                            _selectedIds.remove(friend.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_selectedIds.toList()),
                child: Text('Invite selected (${_selectedIds.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownChip extends StatelessWidget {
  const _CountdownChip({required this.dateTime});
  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    final diff = dateTime.difference(DateTime.now());
    final label = _formatDuration(diff);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AgreeoColors.kernelGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AgreeoColors.kernelGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_rounded,
            size: 18,
            color: AgreeoColors.kernelGold,
          ),
          const SizedBox(width: 8),
          Text(
            'Starts in $label',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AgreeoColors.kernelGold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) {
      final hours = d.inHours.remainder(24);
      return '${d.inDays}d ${hours}h';
    }
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60);
      return '${d.inHours}h ${minutes}m';
    }
    return '${d.inMinutes}m';
  }
}
