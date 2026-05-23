import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MoodPreset {
  const MoodPreset({
    required this.name,
    required this.icon,
    required this.feeling,
    required this.wantToFeel,
  });

  final String name;
  final IconData icon;
  final String feeling;
  final String wantToFeel;
}

const List<MoodPreset> moodPresets = [
  MoodPreset(
    name: 'Stressed',
    icon: Icons.spa_rounded,
    feeling: 'stressed and overwhelmed',
    wantToFeel: 'relaxed, lighthearted, and calm',
  ),
  MoodPreset(
    name: 'Tired',
    icon: Icons.bolt_rounded,
    feeling: 'tired and low energy',
    wantToFeel: 'energized, excited, and motivated',
  ),
  MoodPreset(
    name: 'Bored',
    icon: Icons.psychology_rounded,
    feeling: 'bored and uninspired',
    wantToFeel: 'intrigued, mind-blown, and mystery',
  ),
  MoodPreset(
    name: 'Sad',
    icon: Icons.wb_sunny_rounded,
    feeling: 'a bit sad or down',
    wantToFeel: 'happy, comforted, and uplifted',
  ),
  MoodPreset(
    name: 'Spooky',
    icon: Icons.nights_stay_rounded,
    feeling: 'brave and adventurous',
    wantToFeel: 'scared, thrilled, and suspenseful',
  ),
  MoodPreset(
    name: 'Romantic',
    icon: Icons.favorite_rounded,
    feeling: 'sentimental',
    wantToFeel: 'romantic, moved, and warm',
  ),
];

Future<void> showMoodSelectorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AgreeoColors.anthraciteBlack,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const MoodSelectorSheet(),
  );
}

class MoodSelectorSheet extends ConsumerStatefulWidget {
  const MoodSelectorSheet({super.key});

  @override
  ConsumerState<MoodSelectorSheet> createState() => _MoodSelectorSheetState();
}

class _MoodSelectorSheetState extends ConsumerState<MoodSelectorSheet> {
  final TextEditingController _feelingController = TextEditingController();
  final TextEditingController _wantToFeelController = TextEditingController();
  final FocusNode _feelingFocus = FocusNode();
  final FocusNode _wantToFeelFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  List<Movie> _results = [];
  bool _hasSearched = false;
  MoodPreset? _selectedPreset;

  @override
  void dispose() {
    _feelingController.dispose();
    _wantToFeelController.dispose();
    _feelingFocus.dispose();
    _wantToFeelFocus.dispose();
    super.dispose();
  }

  void _applyPreset(MoodPreset preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPreset = preset;
      _feelingController.text = preset.feeling;
      _wantToFeelController.text = preset.wantToFeel;
    });
  }

  Future<void> _searchMoviesByMood() async {
    final feeling = _feelingController.text.trim();
    final wantToFeel = _wantToFeelController.text.trim();

    if (feeling.isEmpty && wantToFeel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe how you feel or want to feel.'),
        ),
      );
      return;
    }

    // Dismiss keyboard
    _feelingFocus.unfocus();
    _wantToFeelFocus.unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final movieService = ref.read(movieServiceProvider);
      final movies = await movieService.getMoviesByMood(
        feeling: feeling,
        wantToFeel: wantToFeel,
      );

      if (mounted) {
        setState(() {
          _results = movies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error choosing titles for your vibe. Try again!';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        color: AgreeoColors.cinematicRed,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Mood Matcher',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                      if (_hasSearched)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Reset search',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _feelingController.clear();
                              _wantToFeelController.clear();
                              _results = [];
                              _hasSearched = false;
                              _selectedPreset = null;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Let local neural tag-embeddings scan your feelings and matches them with films.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (!_hasSearched) ...[
                    // Preset quick buttons
                    Text(
                      'Quick Vibes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: moodPresets.map((preset) {
                          final isSelected = _selectedPreset == preset;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Row(
                                children: [
                                  Icon(
                                    preset.icon,
                                    size: 16,
                                    color: isSelected
                                        ? Colors.white
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(preset.name),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (_) => _applyPreset(preset),
                              showCheckmark: false,
                              selectedColor: AgreeoColors.cinematicRed,
                              labelStyle: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.white70,
                              ),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.transparent
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Feel field
                    Text(
                      'How do you feel right now?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _feelingController,
                      focusNode: _feelingFocus,
                      maxLines: 2,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'e.g. stressed, anxious, tired, down...',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Want to Feel field
                    Text(
                      'How do you want to feel after the movie?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _wantToFeelController,
                      focusNode: _wantToFeelFocus,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'e.g. relaxed, happy, intrigued, scared...',
                      ),
                      onSubmitted: (_) => _searchMoviesByMood(),
                    ),
                    const SizedBox(height: 24),

                    // Main Gradient Match Button
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            AgreeoColors.cinematicRed,
                            AgreeoColors.kernelGold,
                          ],
                        ),
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _searchMoviesByMood,
                        icon: const Icon(Icons.wb_twilight_rounded),
                        label: const Text(
                          'Match My Mood',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Search results view
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildSearchResultsContent(theme, colorScheme),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsContent(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return Container(
        key: const ValueKey<String>('loading'),
        padding: const EdgeInsets.symmetric(vertical: 48),
        alignment: Alignment.center,
        child: const Column(
          children: [
            CircularProgressIndicator(
              color: AgreeoColors.kernelGold,
            ),
            SizedBox(height: 20),
            Text(
              'Running local transformer model...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              'Comparing tags to find your vibe...',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        key: const ValueKey<String>('error'),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AgreeoColors.cinematicRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _searchMoviesByMood,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Container(
        key: const ValueKey<String>('empty'),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(
              Icons.movie_filter_rounded,
              color: Colors.white24,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'No matches found for your vibe.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your inputs or selecting another Quick Vibe preset.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _hasSearched = false;
                  _selectedPreset = null;
                });
              },
              child: const Text('Back to Inputs'),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const ValueKey<String>('results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Vibe Matches',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${_results.length} titles found',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.secondary.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _results.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final movie = _results[index];
              return _MoodMovieCard(
                movie: movie,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
          onPressed: () {
            setState(() {
              _hasSearched = false;
            });
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Adjust Vibe Inputs'),
        ),
      ],
    );
  }
}

class _MoodMovieCard extends StatelessWidget {
  const _MoodMovieCard({
    required this.movie,
    required this.onTap,
  });

  final Movie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 130,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                    ),
                    child: movie.posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: movie.posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: AgreeoColors.kernelGold,
                                strokeWidth: 2,
                              ),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(
                                Icons.movie_creation_outlined,
                                color: Colors.white54,
                                size: 36,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.movie_creation_outlined,
                              color: Colors.white54,
                              size: 36,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                movie.releaseYear.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
