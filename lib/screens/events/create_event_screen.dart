import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/providers/app_controller.dart';
import 'package:agreeo/screens/events/voting_screen.dart';
import 'package:agreeo/widgets/empty_state.dart';
import 'package:agreeo/widgets/gradient_scaffold.dart';
import 'package:agreeo/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import necessario per le funzionalità di clipboard (come richiesto dal debugger)
import 'package:flutter/services.dart'; 

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final PageController _pageController = PageController();
  int _stepIndex = 0;
  String? _selectedGroupId;
  MediaType _format = MediaType.movie;
  final Set<String> _includeGenres = <String>{};
  final Set<String> _excludeGenres = <String>{};
  double _durationHours = 2.5;
  bool _creating = false;

  static const List<String> _genreOptions = <String>[
    'Action',
    'Comedy',
    'Drama',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Thriller',
    'Adventure',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final controller = ref.read(appControllerProvider.notifier);
    final group = await controller.createGroup('Movie Night Crew');
    setState(() {
      _selectedGroupId = group.id;
    });
  }

  Future<void> _generateEvent() async {
    final groupId =
        _selectedGroupId ?? ref.read(appControllerProvider).activeGroup?.id;
    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or select a group first.')),
      );
      return;
    }

    setState(() {
      _creating = true;
    });

    final event = await ref
        .read(appControllerProvider.notifier)
        .createEvent(
          EventConstraints(
            groupId: groupId,
            format: _format,
            includeGenres: _includeGenres.toList(growable: false),
            excludeGenres: _excludeGenres.toList(growable: false),
            maxDurationMinutes: (_durationHours * 60).round(),
          ),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _creating = false;
    });

    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the event yet.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => VotingScreen(eventId: event.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final groups = state.groups;
    final selectedGroup = groups.firstWhere(
      (group) => group.id == _selectedGroupId,
      orElse: () => groups.isNotEmpty
          ? groups.first
          : state.activeGroup ??
                groups.firstWhere(
                  (_) => false,
                  orElse: () => MovieGroup(
                    id: '',
                    name: '',
                    inviteCode: '',
                    ownerId: '',
                    memberIds: const <String>[],
                    sharedWatchlist: const <Movie>[],
                    createdAt: DateTime.now(),
                  ),
                ),
    );

    return GradientScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(
              title: 'Create movie night',
              subtitle: 'Three quick steps and the shortlist is ready.',
            ),
            const SizedBox(height: 18),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _stepIndex = value),
                children: <Widget>[
                  _StepCard(
                    title: '1. Select a group',
                    subtitle: 'Choose an existing group or create a new one.',
                    child: groups.isEmpty
                        ? EmptyState(
                            icon: Icons.group_add_rounded,
                            title: 'No groups yet',
                            message:
                                'Create one now and invite friends by code.',
                            action: FilledButton(
                              onPressed: _createGroup,
                              child: const Text('Create group'),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: groups
                                    .map(
                                      (group) => ChoiceChip(
                                        label: Text(group.name),
                                        selected: _selectedGroupId == group.id,
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedGroupId = group.id;
                                          });
                                        },
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _createGroup,
                                child: const Text('Create a new group'),
                              ),
                            ],
                          ),
                  ),
                  _StepCard(
                    title: '2. Set constraints',
                    subtitle:
                        'Format, genres, and duration shape the shortlist.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ToggleButtons(
                          isSelected: <bool>[
                            _format == MediaType.movie,
                            _format == MediaType.series,
                          ],
                          onPressed: (index) {
                            setState(() {
                              _format = index == 0
                                  ? MediaType.movie
                                  : MediaType.series;
                            });
                          },
                          children: const <Widget>[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('Movie'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('TV Series'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Include genres',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _genreOptions
                              .map(
                                (genre) => FilterChip(
                                  label: Text(genre),
                                  selected: _includeGenres.contains(genre),
                                  onSelected: (selected) {
                                    setState(() {
                                      selected
                                          ? _includeGenres.add(genre)
                                          : _includeGenres.remove(genre);
                                    });
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Exclude genres',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _genreOptions
                              .map(
                                (genre) => FilterChip(
                                  label: Text('No $genre'),
                                  selected: _excludeGenres.contains(genre),
                                  onSelected: (selected) {
                                    setState(() {
                                      selected
                                          ? _excludeGenres.add(genre)
                                          : _excludeGenres.remove(genre);
                                    });
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Max duration: ${_durationHours.toStringAsFixed(1)}h',
                        ),
                        Slider(
                          value: _durationHours,
                          min: 1.0,
                          max: 3.0,
                          divisions: 8,
                          label: '${_durationHours.toStringAsFixed(1)}h',
                          onChanged: (value) {
                            setState(() {
                              _durationHours = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  _StepCard(
                    title: '3. Invite friends',
                    subtitle:
                        'Agreeo will send the group a signal and compute the shortlist.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (selectedGroup.id.isNotEmpty) ...<Widget>[
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.key_rounded),
                              title: Text(selectedGroup.inviteCode),
                              subtitle: const Text(
                                'Share this code to invite friends.',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_rounded),
                                onPressed: () {
                                  // Soluzione al problema degli errori di compilazione (Clipboard)
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: selectedGroup.inviteCode,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invite code copied'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SwitchListTile.adaptive(
                          value: true,
                          onChanged: (_) {},
                          title: const Text('Send notifications'),
                          subtitle: const Text(
                            'The app will notify the group when the shortlist is ready.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_creating)
                          const Center(child: CircularProgressIndicator())
                        else
                          FilledButton(
                            onPressed: _generateEvent,
                            child: const Text('Generate shortlist'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _stepIndex < 2
                  ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                    )
                  : _generateEvent,
              child: Text(_stepIndex < 2 ? 'Continue' : 'Create event'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}
