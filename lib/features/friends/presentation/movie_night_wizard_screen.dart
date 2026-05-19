import 'package:agreeo/features/friends/presentation/movie_night_waiting_room_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/mock_data/mock_movies.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MovieNightWizardScreen extends ConsumerStatefulWidget {
  const MovieNightWizardScreen({super.key});

  @override
  ConsumerState<MovieNightWizardScreen> createState() =>
      _MovieNightWizardScreenState();
}

class _MovieNightWizardScreenState
    extends ConsumerState<MovieNightWizardScreen> {
  final TextEditingController _nameController = TextEditingController(
    text: 'Friday Movie Night',
  );
  final TextEditingController _friendSearchController = TextEditingController();
  int _step = 0;
  DateTime? _dateTime;
  final Set<String> _includedGenres = <String>{};
  final Set<String> _excludedGenres = <String>{};
  int _maxDurationMinutes = 150;
  double? _minimumRating;
  String? _language;
  final Set<String> _selectedFriendIds = <String>{};
  String _friendSearch = '';

  @override
  void dispose() {
    _nameController.dispose();
    _friendSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socialState = ref.watch(friendsMovieNightControllerProvider);
    final filteredFriends = socialState.friends
        .where(
          (friend) =>
              _friendSearch.isEmpty ||
              friend.name.toLowerCase().contains(_friendSearch.toLowerCase()),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Movie Night')),
      body: SafeArea(
        child: Stepper(
          currentStep: _step,
          onStepTapped: (step) => setState(() => _step = step),
          onStepContinue: () {
            _continue(filteredFriends);
          },
          onStepCancel: _step == 0
              ? null
              : () => setState(() => _step = (_step - 1).clamp(0, 2)),
          controlsBuilder: (context, details) {
            final isLast = _step == 2;
            return Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(isLast ? 'Generate Shortlist' : 'Continue'),
                  ),
                  if (_step > 0) ...<Widget>[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: <Step>[
            Step(
              title: const Text('Event basics'),
              subtitle: const Text('Name and optional date'),
              isActive: _step >= 0,
              content: _BasicsStep(
                nameController: _nameController,
                dateTime: _dateTime,
                onPickDateTime: _pickDateTime,
                onClearDateTime: () => setState(() => _dateTime = null),
              ),
            ),
            Step(
              title: const Text('Constraints'),
              subtitle: const Text('Genres, duration, rating, language'),
              isActive: _step >= 1,
              content: _ConstraintsStep(
                includedGenres: _includedGenres,
                excludedGenres: _excludedGenres,
                maxDurationMinutes: _maxDurationMinutes,
                minimumRating: _minimumRating,
                language: _language,
                onIncludedToggle: _toggleIncludedGenre,
                onExcludedToggle: _toggleExcludedGenre,
                onDurationChanged: (value) => setState(() {
                  _maxDurationMinutes = value.round();
                }),
                onMinimumRatingChanged: (value) => setState(() {
                  _minimumRating = value;
                }),
                onLanguageChanged: (value) => setState(() {
                  _language = value;
                }),
              ),
            ),
            Step(
              title: const Text('Invite friends'),
              subtitle: const Text('Select friends and copy invite link'),
              isActive: _step >= 2,
              content: _InviteStep(
                friends: filteredFriends,
                selectedFriendIds: _selectedFriendIds,
                searchController: _friendSearchController,
                previewLink: 'agreeo://invite/new-night',
                onSearchChanged: (value) => setState(() {
                  _friendSearch = value.trim();
                }),
                onToggleFriend: (friendId) => setState(() {
                  if (!_selectedFriendIds.add(friendId)) {
                    _selectedFriendIds.remove(friendId);
                  }
                }),
                onCopyLink: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: 'agreeo://invite/new-night'),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: _dateTime ?? now,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? now),
    );
    if (time == null) {
      setState(() => _dateTime = date);
      return;
    }
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _continue(List<Friend> filteredFriends) async {
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Event name is required.');
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_includedGenres.any(_excludedGenres.contains)) {
        _showError('Included and excluded genres cannot conflict.');
        return;
      }
      if (_maxDurationMinutes <= 0) {
        _showError('Maximum duration must be valid.');
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_selectedFriendIds.isEmpty) {
      _showError('Invite at least one friend before generating the shortlist.');
      return;
    }

    final constraints = MovieNightConstraints(
      includedGenres: _includedGenres.toList(growable: false),
      excludedGenres: _excludedGenres.toList(growable: false),
      maxDurationMinutes: _maxDurationMinutes,
      minimumRating: _minimumRating,
      language: _language,
    );
    final event = await ref
        .read(friendsMovieNightControllerProvider.notifier)
        .createMovieNight(
          name: _nameController.text,
          dateTime: _dateTime,
          constraints: constraints,
          invitedFriendIds: _selectedFriendIds.toList(growable: false),
        );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MovieNightWaitingRoomScreen(eventId: event.id),
      ),
    );
  }

  void _toggleIncludedGenre(String genre) {
    setState(() {
      if (!_includedGenres.add(genre)) {
        _includedGenres.remove(genre);
      }
      _excludedGenres.remove(genre);
    });
  }

  void _toggleExcludedGenre(String genre) {
    setState(() {
      if (!_excludedGenres.add(genre)) {
        _excludedGenres.remove(genre);
      }
      _includedGenres.remove(genre);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BasicsStep extends StatelessWidget {
  const _BasicsStep({
    required this.nameController,
    required this.dateTime,
    required this.onPickDateTime,
    required this.onClearDateTime,
  });

  final TextEditingController nameController;
  final DateTime? dateTime;
  final VoidCallback onPickDateTime;
  final VoidCallback onClearDateTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Event name'),
        ),
        const SizedBox(height: 14),
        const InfoBadge(label: 'Content type: Movie'),
        const SizedBox(height: 14),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_rounded),
          title: Text(
            dateTime == null ? 'Optional date/time' : _dateLabel(dateTime!),
          ),
          subtitle: const Text(
            'Set this only if the group already has a time.',
          ),
          trailing: Wrap(
            spacing: 8,
            children: <Widget>[
              TextButton(onPressed: onPickDateTime, child: const Text('Pick')),
              if (dateTime != null)
                TextButton(
                  onPressed: onClearDateTime,
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConstraintsStep extends StatelessWidget {
  const _ConstraintsStep({
    required this.includedGenres,
    required this.excludedGenres,
    required this.maxDurationMinutes,
    required this.minimumRating,
    required this.language,
    required this.onIncludedToggle,
    required this.onExcludedToggle,
    required this.onDurationChanged,
    required this.onMinimumRatingChanged,
    required this.onLanguageChanged,
  });

  final Set<String> includedGenres;
  final Set<String> excludedGenres;
  final int maxDurationMinutes;
  final double? minimumRating;
  final String? language;
  final ValueChanged<String> onIncludedToggle;
  final ValueChanged<String> onExcludedToggle;
  final ValueChanged<double> onDurationChanged;
  final ValueChanged<double?> onMinimumRatingChanged;
  final ValueChanged<String?> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Included genres', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _GenreWrap(
          selected: includedGenres,
          disabled: excludedGenres,
          onTap: onIncludedToggle,
        ),
        const SizedBox(height: 18),
        Text('Excluded genres', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _GenreWrap(
          selected: excludedGenres,
          disabled: includedGenres,
          onTap: onExcludedToggle,
        ),
        const SizedBox(height: 18),
        Text('Maximum duration: ${maxDurationMinutes}m'),
        Slider(
          value: maxDurationMinutes.toDouble(),
          min: 80,
          max: 210,
          divisions: 13,
          label: '${maxDurationMinutes}m',
          onChanged: onDurationChanged,
        ),
        const SizedBox(height: 12),
        Text('Minimum rating', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          children: <Widget>[
            ChoiceChip(
              selected: minimumRating == null,
              label: const Text('Any'),
              onSelected: (_) => onMinimumRatingChanged(null),
            ),
            for (final rating in const <double>[6, 7, 8])
              ChoiceChip(
                selected: minimumRating == rating,
                label: Text('${rating.toStringAsFixed(0)}+'),
                onSelected: (_) => onMinimumRatingChanged(rating),
              ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String?>(
          initialValue: language,
          decoration: const InputDecoration(labelText: 'Language optional'),
          items: const <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(value: null, child: Text('Any language')),
            DropdownMenuItem<String?>(value: 'en', child: Text('English')),
            DropdownMenuItem<String?>(value: 'it', child: Text('Italian')),
            DropdownMenuItem<String?>(value: 'fr', child: Text('French')),
            DropdownMenuItem<String?>(value: 'ja', child: Text('Japanese')),
          ],
          onChanged: onLanguageChanged,
        ),
      ],
    );
  }
}

class _GenreWrap extends StatelessWidget {
  const _GenreWrap({
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

class _InviteStep extends StatelessWidget {
  const _InviteStep({
    required this.friends,
    required this.selectedFriendIds,
    required this.searchController,
    required this.previewLink,
    required this.onSearchChanged,
    required this.onToggleFriend,
    required this.onCopyLink,
  });

  final List<Friend> friends;
  final Set<String> selectedFriendIds;
  final TextEditingController searchController;
  final String previewLink;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggleFriend;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AgreeoSearchBar(
          controller: searchController,
          hintText: 'Search friends to invite',
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),
        if (friends.isEmpty)
          const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No friends found',
            message: 'Accept requests or search friends before inviting.',
          )
        else
          ...friends.map(
            (friend) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selectedFriendIds.contains(friend.id),
              onChanged: (_) => onToggleFriend(friend.id),
              title: Text(friend.name),
              subtitle: Text(
                '${friend.watchedCount} watched • ${friend.reviewsCount} reviews',
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Shareable invite link'),
            subtitle: Text(previewLink),
            trailing: IconButton(
              onPressed: onCopyLink,
              icon: const Icon(Icons.copy_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

String _dateLabel(DateTime dateTime) {
  final date =
      '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  final time =
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
