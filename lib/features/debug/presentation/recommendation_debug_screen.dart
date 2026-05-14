import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecommendationDebugScreen extends ConsumerStatefulWidget {
  const RecommendationDebugScreen({super.key});

  @override
  ConsumerState<RecommendationDebugScreen> createState() =>
      _RecommendationDebugScreenState();
}

class _RecommendationDebugScreenState
    extends ConsumerState<RecommendationDebugScreen> {
  late Future<Map<String, dynamic>> _debugFuture;

  @override
  void initState() {
    super.initState();
    _debugFuture = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return ref.read(movieServiceProvider).getRecommendationDebugStats();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _debugFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recommendation Debug')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _debugFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.bug_report_outlined,
                  title: 'Debug stats unavailable',
                  message: snapshot.error.toString(),
                  action: FilledButton(
                    onPressed: () {
                      setState(() {
                        _debugFuture = _load();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data ?? <String, dynamic>{};
          if (data.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.analytics_outlined,
                  title: 'No debug payload yet',
                  message:
                      'The backend returned no diagnostic payload for this user. Retry after onboarding and at least one recommendation request.',
                  action: FilledButton(
                    onPressed: () {
                      setState(() {
                        _debugFuture = _load();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ),
              ),
            );
          }

          final userSignals = _map(data['userProfileSignals']);
          final recommendationSignals = _map(data['recommendationSignals']);
          final forYouFeedStats = _map(data['forYouFeedStats']);
          final candidatePoolStats = _map(data['candidatePoolStats']);
          final scoringStats = _map(data['scoringStats']);
          final dailyStats = _map(data['dailySuggestionsStats']);
          final fallbackStats = _map(data['fallbackStats']);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: <Widget>[
                SectionHeader(
                  title: 'Recommendation engine',
                  subtitle:
                      'Live backend diagnostics for the current user profile, candidate pool, ranking, and daily exploration mix.',
                  trailing: IconButton(
                    onPressed: () {
                      setState(() {
                        _debugFuture = _load();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatCard(
                      label: 'Feedback',
                      value: '${userSignals['totalFeedbackActions'] ?? 0}',
                    ),
                    _StatCard(
                      label: 'Candidates',
                      value:
                          '${candidatePoolStats['remainingAfterFiltering'] ?? 0}',
                    ),
                    _StatCard(
                      label: 'Home mode',
                      value: _boolLabel(
                        forYouFeedStats['fallbackUsed'] == true,
                      ),
                    ),
                    _StatCard(
                      label: 'Swipe split',
                      value:
                          '${dailyStats['personalizedPercentage'] ?? 0}/${dailyStats['exploratoryPercentage'] ?? 0}',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _DebugCard(
                  title: 'Current feed status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _KeyValueRow(
                        label: 'Home result count',
                        value: '${forYouFeedStats['resultCount'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Home fallback active',
                        value: _boolLabel(
                          forYouFeedStats['fallbackUsed'] == true,
                        ),
                      ),
                      _KeyValueRow(
                        label: 'Home fallback strategy',
                        value: '${forYouFeedStats['fallbackStrategy'] ?? '-'}',
                      ),
                      _KeyValueRow(
                        label: 'Home fallback reason',
                        value: '${forYouFeedStats['fallbackReason'] ?? '-'}',
                      ),
                      _TokenWrap(
                        label: 'Home source breakdown',
                        entries: _sourceBreakdown(
                          forYouFeedStats['sourceBreakdown'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _KeyValueRow(
                        label: 'Swipe fallback active',
                        value: _boolLabel(dailyStats['fallbackUsed'] == true),
                      ),
                      _KeyValueRow(
                        label: 'Swipe fallback strategy',
                        value: '${dailyStats['fallbackStrategy'] ?? '-'}',
                      ),
                      _KeyValueRow(
                        label: 'Swipe fallback reason',
                        value: '${dailyStats['fallbackReason'] ?? '-'}',
                      ),
                      _TokenWrap(
                        label: 'Swipe source breakdown',
                        entries: _sourceBreakdown(
                          dailyStats['sourceBreakdown'],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugCard(
                  title: 'User profile signals',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _KeyValueRow(
                        label: 'User id',
                        value: '${userSignals['uid'] ?? '-'}',
                      ),
                      _KeyValueRow(
                        label: 'Onboarding genres',
                        value: _join(userSignals['onboardingGenres']),
                      ),
                      _KeyValueRow(
                        label: 'Favorite movies',
                        value: '${userSignals['favoriteMoviesCount'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Liked movies',
                        value: '${userSignals['likedMoviesCount'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Disliked movies',
                        value: '${userSignals['dislikedMoviesCount'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Already seen',
                        value: '${userSignals['alreadySeenCount'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Watchlist',
                        value: '${userSignals['watchlistCount'] ?? 0}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugCard(
                  title: 'Recommendation signals',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _TokenWrap(
                        label: 'Top positive genres',
                        entries:
                            _listOfMaps(
                                  recommendationSignals['topPositiveGenres'],
                                )
                                .map(
                                  (entry) =>
                                      '${entry['name']} (${entry['score']})',
                                )
                                .toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      _TokenWrap(
                        label: 'Top negative genres',
                        entries:
                            _listOfMaps(
                                  recommendationSignals['topNegativeGenres'],
                                )
                                .map(
                                  (entry) =>
                                      '${entry['name']} (${entry['score']})',
                                )
                                .toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      _TokenWrap(
                        label: 'Influential liked/favorite movies',
                        entries:
                            _listOfMaps(
                                  recommendationSignals['influentialPositiveMovies'],
                                )
                                .map(
                                  (entry) =>
                                      '${entry['title']} (${entry['signalType']})',
                                )
                                .toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      _TokenWrap(
                        label: 'Penalized disliked movies',
                        entries:
                            _listOfMaps(
                                  recommendationSignals['penalizedNegativeMovies'],
                                )
                                .map((entry) => '${entry['title']}')
                                .toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      _KeyValueRow(
                        label: 'Response mode',
                        value:
                            '${recommendationSignals['responseMode'] ?? '-'}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugCard(
                  title: 'Candidate pool',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _KeyValueRow(
                        label: 'Total considered',
                        value:
                            '${candidatePoolStats['totalCandidatesConsidered'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Filtered already seen',
                        value:
                            '${candidatePoolStats['filteredAlreadySeen'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Filtered disliked',
                        value: '${candidatePoolStats['filteredDisliked'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Filtered already swiped',
                        value:
                            '${candidatePoolStats['filteredAlreadySwiped'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Filtered missing metadata',
                        value:
                            '${candidatePoolStats['filteredMissingMetadata'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Remaining',
                        value:
                            '${candidatePoolStats['remainingAfterFiltering'] ?? 0}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugCard(
                  title: 'Scoring sample',
                  child:
                      _listOfMaps(scoringStats['sampleRecommendations']).isEmpty
                      ? const Text('No ranked sample is available yet.')
                      : Column(
                          children:
                              _listOfMaps(scoringStats['sampleRecommendations'])
                                  .map(
                                    (entry) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('${entry['title']}'),
                                      subtitle: Text(
                                        '${entry['reason'] ?? ''}',
                                      ),
                                      trailing: Text(
                                        '${entry['finalScore'] ?? 0}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                        ),
                ),
                const SizedBox(height: 16),
                _DebugCard(
                  title: 'Daily suggestions mix',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _KeyValueRow(
                        label: 'Personalized candidates',
                        value:
                            '${dailyStats['personalizedCandidateCount'] ?? 0}',
                      ),
                      _KeyValueRow(
                        label: 'Exploratory candidates',
                        value:
                            '${dailyStats['exploratoryCandidateCount'] ?? 0}',
                      ),
                      const SizedBox(height: 12),
                      if (_listOfMaps(dailyStats['sampleQueue']).isEmpty)
                        const Text('No daily sample queue is available yet.')
                      else
                        ..._listOfMaps(dailyStats['sampleQueue']).map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${entry['title']}'),
                            subtitle: Text('${entry['reason'] ?? ''}'),
                            trailing: Text(
                              _formatSourceLabel('${entry['source'] ?? ''}'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugCard(
                  title: 'Fallback status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _KeyValueRow(
                        label: 'Fallback used',
                        value: fallbackStats['used'] == true ? 'Yes' : 'No',
                      ),
                      _KeyValueRow(
                        label: 'Reason',
                        value: '${fallbackStats['reason'] ?? '-'}',
                      ),
                      _KeyValueRow(
                        label: 'Strategy',
                        value: '${fallbackStats['strategy'] ?? '-'}',
                      ),
                      _KeyValueRow(
                        label: 'Fallback candidate count',
                        value: '${fallbackStats['candidateCount'] ?? 0}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listOfMaps(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList(growable: false);
  }

  String _join(Object? value) {
    if (value is! List || value.isEmpty) {
      return '-';
    }
    return value.map((item) => item.toString()).join(', ');
  }

  String _boolLabel(bool value) {
    return value ? 'Fallback' : 'Personal';
  }

  List<String> _sourceBreakdown(Object? value) {
    return _listOfMaps(value)
        .map(
          (entry) =>
              '${_formatSourceLabel('${entry['source'] ?? 'unknown'}')}: ${entry['count'] ?? 0}',
        )
        .toList(growable: false);
  }

  String _formatSourceLabel(String source) {
    switch (source) {
      case 'personalized':
      case 'daily-personalized':
        return 'Personal';
      case 'exploratory':
      case 'exploratory-fallback':
        return 'Explore';
      case 'fallback':
      case 'popular-fallback':
        return 'Fallback';
      default:
        return source.isEmpty ? 'Unknown' : source;
    }
  }
}

class _DebugCard extends StatelessWidget {
  const _DebugCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _TokenWrap extends StatelessWidget {
  const _TokenWrap({required this.label, required this.entries});

  final String label;
  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries.isEmpty
              ? <Widget>[const Text('-')]
              : entries
                    .map(
                      (entry) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        child: Text(entry),
                      ),
                    )
                    .toList(growable: false),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(label),
        ],
      ),
    );
  }
}
