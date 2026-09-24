import 'dart:convert';

import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecommendationEngineTab extends StatelessWidget {
  const RecommendationEngineTab({
    super.key,
    required this.future,
    required this.onRetry,
  });

  final Future<Map<String, dynamic>> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _EngineError(
            message: snapshot.error.toString(),
            onRetry: onRetry,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _EngineReport(data: snapshot.data!);
      },
    );
  }
}

class _EngineReport extends StatelessWidget {
  const _EngineReport({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final trace = _map(data['engineTrace']);
    final profile = _map(data['userProfileSignals']);
    final signals = _map(data['recommendationSignals']);
    final pool = _map(data['candidatePoolStats']);
    final feed = _map(data['forYouFeedStats']);
    final daily = _map(data['dailySuggestionsStats']);
    final scoring = _map(data['scoringStats']);
    final stages = _maps(trace['stages']);
    final formulas = _map(trace['formulas']);
    final queries = _maps(trace['queries']);
    final metrics = _maps(trace['metrics']);
    final recommendations = _maps(scoring['sampleRecommendations']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
      children: [
        _TraceHero(
          variant: trace['experimentVariant']?.toString() ?? '?',
          generatedAt: trace['generatedAt']?.toString() ?? '',
          queryCount: queries.length,
          computation: _map(trace['computation']),
        ),
        const SizedBox(height: 14),
        _SectionHeader(
          index: 'A',
          title: 'Input: what does the system know about me?',
          subtitle:
              'These are the nodes and relationships feeding the ranking.',
        ),
        const SizedBox(height: 8),
        _SignalOverview(profile: profile, signals: signals),
        const SizedBox(height: 18),
        _SectionHeader(
          index: 'B',
          title: 'Live pipeline',
          subtitle: 'Execution stages from candidate retrieval to final ranking.',
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < stages.length; index++) ...[
          _StageCard(stage: stages[index], isLast: index == stages.length - 1),
          if (index != stages.length - 1) const _FlowArrow(),
        ],
        const SizedBox(height: 18),
        _SectionHeader(
          index: 'C',
          title: 'Formulas in use',
          subtitle:
              'These are not descriptions: they match the backend scores.',
        ),
        const SizedBox(height: 8),
        for (final entry in formulas.entries)
          _FormulaCard(name: entry.key, formula: entry.value.toString()),
        const SizedBox(height: 18),
        _SectionHeader(
          index: 'D',
          title: 'Filters and pool size',
          subtitle: 'Shows how many movies enter and how many are excluded.',
        ),
        const SizedBox(height: 8),
        _PoolCard(pool: pool, feed: feed, daily: daily),
        const SizedBox(height: 18),
        _SectionHeader(
          index: 'E',
          title: 'Why these movies?',
          subtitle: 'Open a candidate to read every score component.',
        ),
        const SizedBox(height: 8),
        if (recommendations.isEmpty)
          const _EmptyCard(
            message: 'No candidates available: add likes or favorites.',
          )
        else
          for (var index = 0; index < recommendations.length; index++)
            _RecommendationCard(rank: index + 1, movie: recommendations[index]),
        const SizedBox(height: 18),
        _SectionHeader(
          index: 'F',
          title: 'Cypher actually executed',
          subtitle:
              'Queries, sanitized parameters, rows and duration of the current trace.',
        ),
        const SizedBox(height: 8),
        if (queries.isEmpty)
          const _EmptyCard(message: 'No queries captured.')
        else
          for (final query in queries) _QueryTraceCard(query: query),
        const SizedBox(height: 18),
        _SectionHeader(
          index: 'G',
          title: 'Feedback loop and metrics',
          subtitle:
              'Impressions and swipes are used to evaluate and tune the engine.',
        ),
        const SizedBox(height: 8),
        _MetricsCard(metrics: metrics),
      ],
    );
  }
}

class _TraceHero extends StatelessWidget {
  const _TraceHero({
    required this.variant,
    required this.generatedAt,
    required this.queryCount,
    required this.computation,
  });

  final String variant;
  final String generatedAt;
  final int queryCount;
  final Map<String, dynamic> computation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: t.gradSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.purple.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, color: t.purple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recommendation Engine · Live trace',
                  style: AgText.h3.copyWith(color: t.text),
                ),
              ),
              _Pill(text: variant, color: t.purple),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This view recomputes the authenticated user feed and captures the Neo4j queries actually executed across ranking stages.',
            style: AgText.body.copyWith(color: t.sub, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(text: '$queryCount query', color: t.gold),
              _Pill(
                text: 'compute ${computation['forYou'] ?? '?'}',
                color: t.purple,
              ),
              _Pill(text: _shortDate(generatedAt), color: t.green),
              _Pill(text: 'live data', color: t.red),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalOverview extends StatelessWidget {
  const _SignalOverview({required this.profile, required this.signals});

  final Map<String, dynamic> profile;
  final Map<String, dynamic> signals;

  @override
  Widget build(BuildContext context) {
    final positiveGenres = _maps(signals['topPositiveGenres']);
    final negativeGenres = _maps(signals['topNegativeGenres']);
    final positiveTags = _maps(signals['topPositiveTags']);
    final negativeTags = _maps(signals['topNegativeTags']);
    return Column(
      children: [
        _Panel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Metric(
                label: 'Favorites',
                value: _int(profile['favoriteMoviesCount']),
              ),
              _Metric(label: 'Like', value: _int(profile['likedMoviesCount'])),
              _Metric(
                label: 'Dislike',
                value: _int(profile['dislikedMoviesCount']),
              ),
              _Metric(label: 'Seen', value: _int(profile['alreadySeenCount'])),
              _Metric(
                label: 'Watchlist',
                value: _int(profile['watchlistCount']),
              ),
              _Metric(
                label: 'Total feedback',
                value: _int(profile['totalFeedbackActions']),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SignalList(
          title: 'Positive signals',
          color: context.tokens.green,
          entries: [...positiveGenres, ...positiveTags].take(12).toList(),
        ),
        const SizedBox(height: 8),
        _SignalList(
          title: 'Negative signals',
          color: context.tokens.red,
          entries: [...negativeGenres, ...negativeTags].take(12).toList(),
        ),
      ],
    );
  }
}

class _SignalList extends StatelessWidget {
  const _SignalList({
    required this.title,
    required this.color,
    required this.entries,
  });

  final String title;
  final Color color;
  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AgText.label.copyWith(color: color)),
          const SizedBox(height: 9),
          if (entries.isEmpty)
            Text(
              'No signals yet.',
              style: AgText.caption.copyWith(color: t.faint),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final entry in entries)
                  _Pill(
                    text:
                        '${entry['name'] ?? entry['title'] ?? '?'} · ${_num(entry['score']).toStringAsFixed(1)}',
                    color: color,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, required this.isLast});

  final Map<String, dynamic> stage;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Panel(
      borderColor: isLast ? t.gold.withValues(alpha: 0.55) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.purple.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              stage['title']?.toString().split('.').first ?? '?',
              style: AgText.h4.copyWith(color: t.purple),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage['title']?.toString() ?? '?',
                  style: AgText.h4.copyWith(color: t.text),
                ),
                const SizedBox(height: 4),
                Text(
                  stage['description']?.toString() ?? '',
                  style: AgText.caption.copyWith(color: t.sub, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(text: '${_int(stage['outputCount'])} out', color: t.gold),
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Icon(
      Icons.arrow_downward_rounded,
      size: 18,
      color: context.tokens.faint,
    ),
  );
}

class _FormulaCard extends StatelessWidget {
  const _FormulaCard({required this.name, required this.formula});

  final String name;
  final String formula;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.toUpperCase(),
              style: AgText.micro.copyWith(color: t.gold),
            ),
            const SizedBox(height: 7),
            SelectableText(
              formula,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.5,
              ).copyWith(color: t.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({
    required this.pool,
    required this.feed,
    required this.daily,
  });

  final Map<String, dynamic> pool;
  final Map<String, dynamic> feed;
  final Map<String, dynamic> daily;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Metric(
          label: 'Catalog',
          value: _int(pool['totalCandidatesConsidered']),
        ),
        _Metric(
          label: 'Already seen',
          value: _int(pool['filteredAlreadySeen']),
        ),
        _Metric(label: 'Dislike', value: _int(pool['filteredDisliked'])),
        _Metric(
          label: 'Already swiped',
          value: _int(pool['filteredAlreadySwiped']),
        ),
        _Metric(
          label: 'After filters',
          value: _int(pool['remainingAfterFiltering']),
        ),
        _Metric(label: 'Made for you', value: _int(feed['resultCount'])),
        _Metric(
          label: 'Daily personalized',
          value: _int(daily['personalizedCandidateCount']),
        ),
        _Metric(
          label: 'Daily exploratory',
          value: _int(daily['exploratoryCandidateCount']),
        ),
      ],
    ),
  );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rank, required this.movie});

  final int rank;
  final Map<String, dynamic> movie;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tags = _maps(movie['matchedTags']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Panel(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            backgroundColor: t.purple.withValues(alpha: 0.15),
            child: Text('$rank', style: AgText.label.copyWith(color: t.purple)),
          ),
          title: Text(
            movie['title']?.toString() ?? '?',
            style: AgText.label.copyWith(color: t.text),
          ),
          subtitle: Text(
            '${movie['source'] ?? '?'} · final ${_num(movie['finalScore']).toStringAsFixed(3)}',
            style: AgText.micro.copyWith(color: t.sub),
          ),
          children: [
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _ScorePill(label: 'collab', value: movie['collaborativeScore']),
                _ScorePill(label: 'semantic', value: movie['semanticScore']),
                _ScorePill(label: 'RRF', value: movie['rankFusionScore']),
                _ScorePill(
                  label: 'popularity',
                  value: movie['popularityScore'],
                ),
                _ScorePill(label: 'penalty', value: movie['negativePenalty']),
                _ScorePill(
                  label: 'exposures',
                  value: movie['unactedExposureCount'],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                movie['reason']?.toString() ?? '',
                style: AgText.caption.copyWith(color: t.sub, height: 1.4),
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in tags.take(8))
                    _Pill(text: '#${tag['tag']}', color: t.green),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueryTraceCard extends StatelessWidget {
  const _QueryTraceCard({required this.query});

  final Map<String, dynamic> query;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cypher = query['query']?.toString() ?? '';
    final params = const JsonEncoder.withIndent(
      '  ',
    ).convert(query['params'] ?? const {});
    final error = query['error']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Panel(
        borderColor: error == null ? null : t.red.withValues(alpha: 0.5),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: _Pill(text: '#${query['order'] ?? '?'}', color: t.purple),
          title: Text(
            query['name']?.toString() ?? 'Neo4j query',
            style: AgText.label.copyWith(color: t.text),
          ),
          subtitle: Text(
            '${query['durationMs'] ?? '?'} ms · ${query['records'] ?? '?'} rows',
            style: AgText.micro.copyWith(
              color: error == null ? t.faint : t.red,
            ),
          ),
          trailing: IconButton(
            tooltip: 'Copy Cypher',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => Clipboard.setData(ClipboardData(text: cypher)),
          ),
          children: [
            _CodeBlock(label: 'CYPHER', value: cypher),
            const SizedBox(height: 8),
            _CodeBlock(label: 'PARAMETERS', value: params),
            if (error != null) ...[
              const SizedBox(height: 8),
              _CodeBlock(label: 'ERROR', value: error, error: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metrics});

  final List<Map<String, dynamic>> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const _EmptyCard(
        message:
            'No batches observed yet: use Discover to generate impressions and swipes.',
      );
    }
    return _Panel(
      child: Column(
        children: [
          for (var index = 0; index < metrics.length; index++) ...[
            if (index > 0) Divider(color: context.tokens.line),
            _MetricRow(metric: metrics[index]),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});

  final Map<String, dynamic> metric;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric['source']?.toString() ?? '?',
              style: AgText.label.copyWith(color: context.tokens.text),
            ),
            Text(
              metric['experimentVariant']?.toString() ?? '',
              style: AgText.micro.copyWith(color: context.tokens.faint),
            ),
          ],
        ),
      ),
      _Pill(
        text: '${_int(metric['served'])} served',
        color: context.tokens.purple,
      ),
      const SizedBox(width: 6),
      _Pill(
        text:
            '${(_num(metric['swipeThroughRate']) * 100).toStringAsFixed(0)}% swipe',
        color: context.tokens.green,
      ),
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final String index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Pill(text: index, color: context.tokens.gold),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AgText.h4.copyWith(color: context.tokens.text)),
            Text(
              subtitle,
              style: AgText.micro.copyWith(color: context.tokens.faint),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.tokens.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? context.tokens.line),
    ),
    child: child,
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(text, style: AgText.labelSm.copyWith(color: color)),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 102,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.tokens.surface2,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: AgText.h3.copyWith(color: context.tokens.text)),
        Text(label, style: AgText.micro.copyWith(color: context.tokens.faint)),
      ],
    ),
  );
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.value});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => _Pill(
    text: '$label ${_num(value).toStringAsFixed(2)}',
    color: context.tokens.purple,
  );
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.label,
    required this.value,
    this.error = false,
  });

  final String label;
  final String value;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.tokens.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: error ? context.tokens.red : context.tokens.line2,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AgText.micro.copyWith(
            color: error ? context.tokens.red : context.tokens.gold,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            height: 1.45,
            color: context.tokens.text,
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Text(
      message,
      style: AgText.caption.copyWith(color: context.tokens.faint),
    ),
  );
}

class _EngineError extends StatelessWidget {
  const _EngineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: _Panel(
        borderColor: context.tokens.red,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trace unavailable',
              style: AgText.h4.copyWith(color: context.tokens.red),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AgText.caption.copyWith(color: context.tokens.sub),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, entry) => MapEntry(key.toString(), entry))
    : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.map(_map).toList(growable: false)
    : const <Map<String, dynamic>>[];

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double _num(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _shortDate(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return 'live';
  return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}:${parsed.second.toString().padLeft(2, '0')}';
}
