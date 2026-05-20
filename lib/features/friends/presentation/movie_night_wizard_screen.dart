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
  final PageController _pageController = PageController();
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
    _pageController.dispose();
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

    final pages = <_WizardPageData>[
      _WizardPageData(
        eyebrow: 'Step 1 of 3',
        title: 'Set the vibe',
        subtitle:
            'Give the night a name, then lock the time only if it exists.',
        icon: Icons.nightlight_round,
        accent: const Color(0xFF8B5CF6),
        child: _BasicsStep(
          nameController: _nameController,
          dateTime: _dateTime,
          onPickDateTime: _pickDateTime,
          onClearDateTime: () => setState(() => _dateTime = null),
        ),
      ),
      _WizardPageData(
        eyebrow: 'Step 2 of 3',
        title: 'Tune the shortlist',
        subtitle: 'Shape recommendations before everyone starts voting.',
        icon: Icons.tune_rounded,
        accent: const Color(0xFF06B6D4),
        child: _ConstraintsStep(
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
      _WizardPageData(
        eyebrow: 'Step 3 of 3',
        title: 'Bring the crew',
        subtitle: 'Invite friends now, or copy the link for later.',
        icon: Icons.groups_rounded,
        accent: const Color(0xFFF97316),
        child: _InviteStep(
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
    ];
    final page = pages[_step];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Create Movie Night')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: <Widget>[
                  _WizardHero(page: page, step: _step),
                  const SizedBox(height: 18),
                  _StepDots(step: _step),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.58,
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pages.length,
                      itemBuilder: (context, index) {
                        return _WizardCard(page: pages[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
            _WizardActions(
              step: _step,
              onBack: _step == 0 ? null : () => _goToStep(_step - 1),
              onContinue: _continue,
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

  Future<void> _continue() async {
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Event name is required.');
        return;
      }
      _goToStep(1);
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
      _goToStep(2);
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

  void _goToStep(int step) {
    final nextStep = step.clamp(0, 2);
    setState(() => _step = nextStep);
    _pageController.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WizardPageData {
  const _WizardPageData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;
}

class _WizardHero extends StatelessWidget {
  const _WizardHero({required this.page, required this.step});

  final _WizardPageData page;
  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          colors: <Color>[
            page.accent.withValues(alpha: 0.9),
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: page.accent.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -18,
            top: -18,
            child: Icon(
              page.icon,
              size: 132,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InfoBadge(label: page.eyebrow),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      page.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(page.icon, color: Colors.white, size: 30),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                page.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: (step + 1) / 3,
                minHeight: 7,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const labels = <String>['Basics', 'Taste', 'Friends'];

    return Row(
      children: List<Widget>.generate(labels.length, (index) {
        final selected = index == step;
        final done = index < step;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.14)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
              border: Border.all(
                color: selected
                    ? colorScheme.primary.withValues(alpha: 0.28)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  done ? Icons.check_circle_rounded : Icons.circle_rounded,
                  size: 14,
                  color: selected || done
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    labels[index],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected || done
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _WizardCard extends StatelessWidget {
  const _WizardCard({required this.page});

  final _WizardPageData page;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: page.accent.withValues(alpha: 0.18)),
      ),
      child: SingleChildScrollView(child: page.child),
    );
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    required this.step,
    required this.onBack,
    required this.onContinue,
  });

  final int step;
  final VoidCallback? onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = step == 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: Icon(
                isLast
                    ? Icons.auto_awesome_rounded
                    : Icons.arrow_forward_rounded,
              ),
              label: Text(isLast ? 'Generate Shortlist' : 'Continue'),
            ),
          ),
        ],
      ),
    );
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
