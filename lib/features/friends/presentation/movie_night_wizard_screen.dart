import 'package:agreeo/features/friends/presentation/movie_night_waiting_room_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/shared/catalog/genre_options.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Movie Night · Create. Single Daylight screen: name, friend selection
/// (selected pills + suggested list), and an expandable Filters section that
/// feeds [MovieNightConstraints]. Reference: `ag-social.jsx` NightCreateScreen.
class MovieNightWizardScreen extends ConsumerStatefulWidget {
  const MovieNightWizardScreen({
    super.key,
    this.preSelectedFriendIds = const <String>[],
  });

  final List<String> preSelectedFriendIds;

  @override
  ConsumerState<MovieNightWizardScreen> createState() =>
      _MovieNightWizardScreenState();
}

class _MovieNightWizardScreenState
    extends ConsumerState<MovieNightWizardScreen> {
  late final TextEditingController _nameController;
  late final Set<String> _selected;
  final Set<String> _includedGenres = {};
  int _maxDuration = 150;
  double? _minRating;
  bool _filtersOpen = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _defaultName());
    _selected = widget.preSelectedFriendIds.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _defaultName() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[DateTime.now().weekday - 1]} Movie Night';
  }

  String get _filtersSummary {
    final parts = <String>[];
    if (_includedGenres.isNotEmpty) {
      parts.add(_includedGenres.take(2).join(', '));
    }
    parts.add(
      'Under ${_maxDuration ~/ 60}h${_maxDuration % 60 == 0 ? '' : '½'}',
    );
    if (_minRating != null) parts.add('${_minRating!.toStringAsFixed(0)}+');
    return parts.join(' · ');
  }

  Future<void> _create(List<Friend> friends) async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite at least one friend.')),
      );
      return;
    }
    setState(() => _creating = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final event = await ref
          .read(friendsMovieNightControllerProvider.notifier)
          .createMovieNight(
            name: _nameController.text,
            dateTime: null,
            constraints: MovieNightConstraints(
              includedGenres: _includedGenres.toList(),
              excludedGenres: const [],
              maxDurationMinutes: _maxDuration,
              minimumRating: _minRating,
              language: null,
            ),
            invitedFriendIds: _selected.toList(),
          );
      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MovieNightWaitingRoomScreen(eventId: event.id),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not create this Movie Night.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final friends = ref.watch(friendsMovieNightControllerProvider).friends;
    final selectedFriends = friends
        .where((f) => _selected.contains(f.id))
        .toList();

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _NightHeader(step: 0, title: "Who's in tonight?"),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Name field
                  Container(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.line),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _nameController,
                      cursorColor: t.red,
                      style: AgText.label.copyWith(fontSize: 15, color: t.text),
                      decoration: agBareInput(
                        hint: 'Session name',
                        hintStyle: AgText.body.copyWith(color: t.faint),
                        collapsed: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Selected pills
                  if (selectedFriends.isNotEmpty)
                    SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedFriends.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, i) {
                          final f = selectedFriends[i];
                          return SizedBox(
                            width: 58,
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _selected.remove(f.id)),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AgAvatar(
                                        name: f.name,
                                        imageUrl: f.avatarUrl,
                                        size: 54,
                                      ),
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: t.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: t.bg,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            AgIcons.close,
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  f.name.split(' ').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AgText.micro.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: t.sub,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (selectedFriends.isNotEmpty) const SizedBox(height: 8),
                  Text(
                    'SUGGESTED',
                    style: AgText.overline.copyWith(color: t.faint),
                  ),
                  const SizedBox(height: 8),
                  if (friends.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'No friends yet — add friends to invite them.',
                        style: AgText.caption.copyWith(color: t.faint),
                      ),
                    )
                  else
                    for (final f in friends)
                      _SuggestedRow(
                        friend: f,
                        selected: _selected.contains(f.id),
                        onTap: () => setState(() {
                          if (!_selected.add(f.id)) _selected.remove(f.id);
                        }),
                      ),
                  const SizedBox(height: 14),
                  _FiltersCard(
                    open: _filtersOpen,
                    summary: _filtersSummary,
                    includedGenres: _includedGenres,
                    maxDuration: _maxDuration,
                    minRating: _minRating,
                    onToggleOpen: () =>
                        setState(() => _filtersOpen = !_filtersOpen),
                    onGenreTap: (g) => setState(() {
                      if (!_includedGenres.add(g)) _includedGenres.remove(g);
                    }),
                    onDuration: (v) => setState(() => _maxDuration = v.round()),
                    onRating: (v) => setState(() => _minRating = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: AgButton(
                label: _creating
                    ? 'Creating…'
                    : 'Create session · ${_selected.length} invited',
                icon: AgIcons.arrow,
                onPressed: _creating ? null : () => _create(friends),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NightHeader extends StatelessWidget {
  const _NightHeader({required this.step, required this.title});
  final int step;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.line),
                  ),
                  child: Icon(AgIcons.chevronLeft, size: 20, color: t.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: i <= step ? t.grad : null,
                            color: i <= step ? null : t.surface,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      if (i < 3) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MOVIE NIGHT · STEP ${step + 1}',
                style: AgText.overline.copyWith(color: t.red),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AgText.h1.copyWith(letterSpacing: -0.6, color: t.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestedRow extends StatelessWidget {
  const _SuggestedRow({
    required this.friend,
    required this.selected,
    required this.onTap,
  });
  final Friend friend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            AgAvatar(name: friend.name, imageUrl: friend.avatarUrl, size: 42),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: AgText.label.copyWith(fontSize: 14.5, color: t.text),
                  ),
                  Text(
                    '${friend.watchedCount} watched · ${friend.reviewsCount} reviews',
                    style: AgText.micro.copyWith(color: t.faint),
                  ),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected ? t.grad : null,
                shape: BoxShape.circle,
                border: selected ? null : Border.all(color: t.line2, width: 2),
              ),
              child: selected
                  ? const Icon(AgIcons.check, size: 15, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.open,
    required this.summary,
    required this.includedGenres,
    required this.maxDuration,
    required this.minRating,
    required this.onToggleOpen,
    required this.onGenreTap,
    required this.onDuration,
    required this.onRating,
  });

  final bool open;
  final String summary;
  final Set<String> includedGenres;
  final int maxDuration;
  final double? minRating;
  final VoidCallback onToggleOpen;
  final ValueChanged<String> onGenreTap;
  final ValueChanged<double> onDuration;
  final ValueChanged<double?> onRating;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggleOpen,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(AgIcons.sliders, size: 18, color: t.sub),
                const SizedBox(width: 9),
                Text(
                  'Filters',
                  style: AgText.label.copyWith(fontSize: 14, color: t.text),
                ),
                const Spacer(),
                Text(summary, style: AgText.caption.copyWith(color: t.faint)),
                const SizedBox(width: 6),
                Icon(
                  open ? AgIcons.chevronDown : AgIcons.chevron,
                  size: 18,
                  color: t.faint,
                ),
              ],
            ),
          ),
          if (open) ...[
            const SizedBox(height: 16),
            Text(
              'Genres',
              style: AgText.h4.copyWith(fontSize: 13.5, color: t.text),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in agreeoGenreOptions.take(10))
                  AgChip(
                    label: g,
                    active: includedGenres.contains(g),
                    onTap: () => onGenreTap(g),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Max duration · ${maxDuration}m',
              style: AgText.h4.copyWith(fontSize: 13.5, color: t.text),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: t.red,
                thumbColor: t.red,
                inactiveTrackColor: t.line2,
              ),
              child: Slider(
                value: maxDuration.toDouble(),
                min: 80,
                max: 210,
                divisions: 13,
                onChanged: onDuration,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Minimum rating',
              style: AgText.h4.copyWith(fontSize: 13.5, color: t.text),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              children: [
                AgChip(
                  label: 'Any',
                  active: minRating == null,
                  onTap: () => onRating(null),
                ),
                for (final r in const [6.0, 7.0, 8.0])
                  AgChip(
                    label: '${r.toStringAsFixed(0)}+',
                    active: minRating == r,
                    onTap: () => onRating(r),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
