import 'package:agreeo/providers/app_controller.dart';
import 'package:agreeo/screens/home/home_shell.dart';
import 'package:agreeo/widgets/gradient_scaffold.dart';
import 'package:agreeo/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  final Set<String> _genres = <String>{};
  final Set<String> _services = <String>{};
  bool _dailyRecommendationsEnabled = true;

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

  static const List<String> _serviceOptions = <String>[
    'Netflix',
    'Prime Video',
    'Disney+',
    'Max',
    'Apple TV+',
    'Paramount+',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final controller = ref.read(appControllerProvider.notifier);
    if (ref.read(appControllerProvider).session == null) {
      await controller.createOrUpdateSession(
        displayName: 'Guest',
        email: 'guest@agreeo.app',
        isGuest: true,
      );
    }

    await controller.completeOnboarding(
      favoriteGenres: _genres.isEmpty
          ? <String>{'Drama', 'Comedy'}.toList()
          : _genres.toList(),
      streamingServices: _services.isEmpty
          ? <String>{'Netflix', 'Prime Video'}.toList()
          : _services.toList(),
      dailyRecommendationsEnabled: _dailyRecommendationsEnabled,
    );

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  void _next() {
    if (_pageIndex < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GradientScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(
              title: 'Set up Agreeo',
              subtitle: 'A few taps now makes tomorrow night much easier.',
            ),
            const SizedBox(height: 18),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _pageIndex = value),
                children: <Widget>[
                  _IntroStep(
                    title: 'Welcome to zero-friction movie decisions.',
                    message:
                        'Agreeo spreads the decision across small daily interactions so group nights stay fast and fun.',
                    icon: Icons.auto_awesome_rounded,
                    accent: colorScheme.primaryContainer,
                  ),
                  _ChoiceStep(
                    title: 'Pick your favorite genres',
                    message:
                        'Choose as many as you want. This powers the daily queue.',
                    options: _genreOptions,
                    selectedValues: _genres,
                    onChanged: (genre, selected) {
                      setState(() {
                        selected ? _genres.add(genre) : _genres.remove(genre);
                      });
                    },
                  ),
                  _ChoiceStep(
                    title: 'Choose streaming services',
                    message: 'Only show options your group can actually watch.',
                    options: _serviceOptions,
                    selectedValues: _services,
                    onChanged: (service, selected) {
                      setState(() {
                        selected
                            ? _services.add(service)
                            : _services.remove(service);
                      });
                    },
                    footer: SwitchListTile.adaptive(
                      value: _dailyRecommendationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _dailyRecommendationsEnabled = value;
                        });
                      },
                      title: const Text('Daily recommendations'),
                      subtitle: const Text(
                        'Turn this on for a movie of the day.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _next,
              child: Text(_pageIndex < 2 ? 'Continue' : 'Finish setup'),
            ),
            if (_pageIndex > 0) ...<Widget>[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                  );
                },
                child: const Text('Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[accent.withOpacity(0.62), colorScheme.surface],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 82, color: colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.title,
    required this.message,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.footer,
  });

  final String title;
  final String message;
  final List<String> options;
  final Set<String> selectedValues;
  final void Function(String value, bool selected) onChanged;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options
                .map(
                  (option) => FilterChip(
                    label: Text(option),
                    selected: selectedValues.contains(option),
                    onSelected: (selected) => onChanged(option, selected),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          if (footer != null) ...<Widget>[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}
