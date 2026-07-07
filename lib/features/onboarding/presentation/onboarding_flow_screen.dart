import 'dart:async';

import 'package:agreeo/shared/catalog/genre_options.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoOnboardingFlowScreen extends ConsumerStatefulWidget {
  const AgreeoOnboardingFlowScreen({super.key});

  @override
  ConsumerState<AgreeoOnboardingFlowScreen> createState() =>
      _AgreeoOnboardingFlowScreenState();
}

class _AgreeoOnboardingFlowScreenState
    extends ConsumerState<AgreeoOnboardingFlowScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  int _pageIndex = 0;
  Timer? _searchDebounce;
  Future<List<Movie>>? _searchFuture;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _scheduleSearchRefresh() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _searchController.text.trim();
      setState(() {
        _searchFuture = query.isEmpty
            ? null
            : ref
                  .read(movieServiceProvider)
                  .searchMovies(query, const MovieSearchFilters());
      });
    });
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    await ref.read(agreeoAppControllerProvider.notifier).finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(agreeoAppControllerProvider);
    final onboarding = state.onboarding;
    final selectedGenres = onboarding.favoriteGenres.toSet();
    final selectedMovieIds = onboarding.favoriteMovieIds.toSet();
    final canContinue = _pageIndex == 0 ? selectedGenres.length >= 3 : true;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _pageIndex == 0 ? 0.5 : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: t.grad,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${_pageIndex + 1} / 2',
                    style: AgText.labelSm.copyWith(color: t.faint),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pageIndex == 0
                        ? 'What do you love\nto watch?'
                        : 'Tap a few you\nalready love',
                    style: AgText.display.copyWith(
                      fontSize: 28,
                      height: 1.05,
                      letterSpacing: -0.7,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pageIndex == 0
                        ? 'Pick at least 3. This shapes your feed.'
                        : "We'll calibrate your recommendations from these.",
                    style: AgText.body.copyWith(color: t.sub),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (v) => setState(() => _pageIndex = v),
                children: [
                  _GenresStep(
                    selected: selectedGenres,
                    onToggle: (genre) {
                      HapticFeedback.selectionClick();
                      final next = selectedGenres.toSet();
                      if (!next.add(genre)) next.remove(genre);
                      ref
                          .read(agreeoAppControllerProvider.notifier)
                          .updateOnboardingGenres(next.toList());
                    },
                  ),
                  _FavoritesStep(
                    searchController: _searchController,
                    onSearchChanged: (_) => _scheduleSearchRefresh(),
                    movies: state.catalog,
                    searchFuture: _searchFuture,
                    selectedIds: selectedMovieIds,
                    onToggle: (m) {
                      HapticFeedback.selectionClick();
                      ref
                          .read(agreeoAppControllerProvider.notifier)
                          .toggleFavoriteMovieSelection(m.id);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              child: AgButton(
                label: _pageIndex == 0
                    ? 'Continue · ${selectedGenres.length} picked'
                    : (_finishing ? 'Building…' : 'Build my feed'),
                icon: _pageIndex == 0 ? AgIcons.arrow : AgIcons.sparkle,
                onPressed: !canContinue || _finishing
                    ? null
                    : _pageIndex == 0
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      )
                    : _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenresStep extends StatelessWidget {
  const _GenresStep({required this.selected, required this.onToggle});
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final g in agreeoGenreOptions)
            GestureDetector(
              onTap: () => onToggle(g),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: selected.contains(g) ? t.grad : null,
                  color: selected.contains(g) ? null : t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected.contains(g) ? Colors.transparent : t.line,
                    width: 1.5,
                  ),
                  boxShadow: selected.contains(g)
                      ? [
                          BoxShadow(
                            color: t.purple.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: -8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected.contains(g)) ...[
                      const Icon(AgIcons.check, size: 15, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      g,
                      style: AgText.label.copyWith(
                        fontSize: 14.5,
                        color: selected.contains(g) ? Colors.white : t.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoritesStep extends StatelessWidget {
  const _FavoritesStep({
    required this.searchController,
    required this.onSearchChanged,
    required this.movies,
    required this.searchFuture,
    required this.selectedIds,
    required this.onToggle,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<Movie> movies;
  final Future<List<Movie>>? searchFuture;
  final Set<String> selectedIds;
  final ValueChanged<Movie> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgSearchField(
            controller: searchController,
            hint: 'Search movies…',
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: searchFuture != null
                ? FutureBuilder<List<Movie>>(
                    future: searchFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: context.tokens.red,
                          ),
                        );
                      }
                      if (snapshot.hasError && !snapshot.hasData) {
                        final t = context.tokens;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AgIcons.wifiOff, size: 32, color: t.faint),
                                const SizedBox(height: 12),
                                Text(
                                  "Couldn't search",
                                  style: AgText.h4.copyWith(color: t.text),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Check your connection and search again.',
                                  textAlign: TextAlign.center,
                                  style: AgText.caption.copyWith(color: t.sub),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return _Grid(
                        movies: snapshot.data ?? const [],
                        selectedIds: selectedIds,
                        onToggle: onToggle,
                      );
                    },
                  )
                : _Grid(
                    movies: movies,
                    selectedIds: selectedIds,
                    onToggle: onToggle,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.movies,
    required this.selectedIds,
    required this.onToggle,
  });
  final List<Movie> movies;
  final Set<String> selectedIds;
  final ValueChanged<Movie> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (movies.isEmpty) {
      return Center(
        child: Text(
          'No movies found.',
          style: AgText.body.copyWith(color: t.faint),
        ),
      );
    }
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
        childAspectRatio: 2 / 3,
      ),
      itemCount: movies.length,
      itemBuilder: (context, i) {
        final m = movies[i];
        final on = selectedIds.contains(m.id);
        return AgPoster(
          imageUrl: m.posterUrl,
          title: m.title,
          radius: 12,
          shadow: false,
          onTap: () => onToggle(m),
          overlay: on
              ? Container(
                  decoration: BoxDecoration(
                    color: t.red.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.red, width: 2.5),
                  ),
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: t.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        AgIcons.check,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
