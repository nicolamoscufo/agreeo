import 'package:agreeo/features/friends/presentation/movie_night_auto_refresh.dart';
import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/mock_data/mock_movies.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
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
    extends ConsumerState<MovieNightWaitingRoomScreen>
    with MovieNightAutoRefresh<MovieNightWaitingRoomScreen> {
  @override
  void initState() {
    super.initState();
    startMovieNightPolling(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    final socialState = ref.watch(friendsMovieNightControllerProvider);
    final controller = ref.read(friendsMovieNightControllerProvider.notifier);
    final appState = ref.watch(agreeoAppControllerProvider);
    final event = socialState.eventById(widget.eventId);
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Waiting Room')),
        body: const Center(child: Text('Movie Night not found')),
      );
    }

    if (event.status == MovieNightStatus.voting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => MovieNightVotingScreen(eventId: event.id),
            ),
          );
        }
      });
    } else if (event.status == MovieNightStatus.completed) {
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
      appBar: AppBar(title: const Text('Waiting Room')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: <Widget>[
            SectionHeader(
              title: event.name,
              subtitle:
                  'Confirm the group, constraints, and shortlist before voting.',
              trailing: InfoBadge(label: _statusLabel(event.status)),
            ),
            const SizedBox(height: 18),
            _SummaryCard(event: event),
            const SizedBox(height: 18),
            _InviteLinkCard(inviteLink: event.inviteLink),
            const SizedBox(height: 18),
            _ParticipantsCard(participants: event.participants),
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
                    'Adjust constraints, refresh the shortlist, or start voting.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
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
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final updated = await controller.refreshShortlist(
                        event.id,
                      );
                      if (updated == null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not refresh shortlist.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Generate/refresh shortlist'),
                  ),
                  FilledButton.icon(
                    onPressed: event.shortlist.isEmpty
                        ? null
                        : () async {
                            final updated = await controller.startVoting(
                              event.id,
                            );
                            if (!context.mounted) {
                              return;
                            }
                            if (updated == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not start voting.'),
                                ),
                              );
                              return;
                            }
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    MovieNightVotingScreen(eventId: event.id),
                              ),
                            );
                          },
                    icon: const Icon(Icons.how_to_vote_rounded),
                    label: const Text('Start voting'),
                  ),
                ],
              ),
            ] else ...<Widget>[
              const SectionHeader(
                title: 'Waiting for host',
                subtitle: 'Only the host can edit constraints or start voting.',
              ),
            ],
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Shortlist preview',
              subtitle:
                  'Generated from constraints, participants, catalog, and movie states.',
            ),
            const SizedBox(height: 12),
            if (event.shortlist.isEmpty)
              EmptyState(
                icon: Icons.movie_filter_outlined,
                title: 'No movies matched this group',
                message:
                    'Try removing some excluded genres or increasing the maximum duration.',
                action: isHost
                    ? FilledButton.tonal(
                        onPressed: () async {
                          final updated =
                              await showModalBottomSheet<MovieNightConstraints>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder: (_) => _EditConstraintsSheet(
                                  initialConstraints: event.constraints,
                                ),
                              );
                          if (updated != null) {
                            await controller.updateEventConstraints(
                              eventId: event.id,
                              constraints: updated,
                            );
                          }
                        },
                        child: const Text('Edit constraints'),
                      )
                    : null,
              )
            else
              ...event.shortlist.map(
                (candidate) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ShortlistPreviewCard(
                    candidate: candidate,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AgreeoMovieDetailsScreen(
                            movieId: candidate.movie.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
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
                  Chip(label: Text(_dateLabel(event.dateTime!))),
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
          ],
        ),
      ),
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard({required this.inviteLink});

  final String inviteLink;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.link_rounded),
        title: const Text('Invite link'),
        subtitle: Text(inviteLink),
        trailing: IconButton(
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: inviteLink));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite link copied.')),
              );
            }
          },
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
          'Join before voting starts so your preferences shape the shortlist.',
        ),
        trailing: FilledButton(onPressed: onJoin, child: const Text('Join')),
      ),
    );
  }
}

class _ShortlistPreviewCard extends StatelessWidget {
  const _ShortlistPreviewCard({required this.candidate, required this.onTap});

  final ShortlistCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final movie = candidate.movie;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.movie_creation_outlined),
        title: Text(movie.title),
        subtitle: Text(
          '${movie.releaseYear} • ${movie.runtimeLabel}\n${candidate.explanationTags.join(' • ')}',
        ),
        isThreeLine: true,
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
          .take(12)
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

MovieNightParticipant? _participantFor(MovieNightEvent event, String userId) {
  for (final participant in event.participants) {
    if (participant.userId == userId) {
      return participant;
    }
  }
  return null;
}

String _dateLabel(DateTime dateTime) {
  final date =
      '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  final time =
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
