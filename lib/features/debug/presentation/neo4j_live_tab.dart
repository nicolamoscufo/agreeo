import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:agreeo/services/neo4j_debug_service.dart';
import 'package:agreeo/services/neo4j_live_push.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef OpenInQuery =
    void Function(String query, Map<String, dynamic> params, String note);

/// Observes committed actions without triggering a recommendation calculation.
class Neo4jLiveTab extends StatefulWidget {
  const Neo4jLiveTab({
    super.key,
    required this.service,
    required this.active,
    this.push,
    this.onOpenQuery,
  });

  final Neo4jDebugService service;
  final bool active;
  final Neo4jLivePush? push;
  final OpenInQuery? onOpenQuery;

  @override
  State<Neo4jLiveTab> createState() => _Neo4jLiveTabState();
}

class _Neo4jLiveTabState extends State<Neo4jLiveTab> {
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _pushSubscription;
  Map<String, dynamic>? _data;
  String? _error;
  String? _selectedId;
  String? _highlightId;
  int _pushEvents = 0;
  String _relation = 'LIKED';
  bool _loading = false;
  bool _paused = false;

  Map<String, dynamic>? _path;
  String? _pathError;
  bool _pathLoading = false;

  List<_RankedMovie>? _rankingBaseline;
  List<_RankedMovie>? _rankingCurrent;
  String? _rankingError;
  String? _rankingCapturedAt;
  bool _rankingBusy = false;

  @override
  void initState() {
    super.initState();
    _schedule();
    _syncPush();
  }

  @override
  void didUpdateWidget(covariant Neo4jLiveTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _schedule();
      _syncPush();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!widget.active || _paused) return;
    _refresh();
    if (_path == null && !_pathLoading) _loadPath();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  void _syncPush() {
    if (widget.push == null || !widget.active) return;
    _pushSubscription ??= widget.push!.events.listen(_onPushEvent);
    widget.push!.connect();
  }

  void _onPushEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    setState(() {
      _pushEvents++;
      _highlightId = event['id']?.toString();
    });
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await widget.service.getLiveTrace();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _loading = false;
    }
  }

  Future<void> _loadPath() async {
    setState(() => _pathLoading = true);
    try {
      final data = await widget.service.getRecommendationPath();
      if (!mounted) return;
      setState(() {
        _path = data;
        _pathError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _pathError = error.toString());
    } finally {
      if (mounted) setState(() => _pathLoading = false);
    }
  }

  Future<void> _captureRanking({required bool baseline}) async {
    setState(() {
      _rankingBusy = true;
      _rankingError = null;
    });
    try {
      final report = await widget.service.getRecommendationEngine();
      final ranking = _parseRanking(report);
      if (!mounted) return;
      setState(() {
        if (baseline) {
          _rankingBaseline = ranking;
          _rankingCurrent = null;
          _rankingCapturedAt = DateTime.now().toString().substring(11, 19);
        } else {
          _rankingCurrent = ranking;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _rankingError = error.toString());
    } finally {
      if (mounted) setState(() => _rankingBusy = false);
    }
  }

  void _resetRanking() {
    setState(() {
      _rankingBaseline = null;
      _rankingCurrent = null;
      _rankingError = null;
      _rankingCapturedAt = null;
    });
  }

  static List<_RankedMovie> _parseRanking(Map<String, dynamic> report) {
    final samples = _maps(
      _map(report['scoringStats'])['sampleRecommendations'],
    );
    return [
      for (var index = 0; index < samples.length; index++)
        _RankedMovie(
          rank: index + 1,
          tmdbId: int.tryParse(samples[index]['tmdbId']?.toString() ?? '') ?? 0,
          title: samples[index]['title']?.toString() ?? 'Film',
          score: (samples[index]['finalScore'] as num?)?.toDouble() ?? 0,
          source: samples[index]['source']?.toString() ?? '',
        ),
    ];
  }

  void _openInQuery(Map<String, dynamic> query) {
    final onOpenQuery = widget.onOpenQuery;
    if (onOpenQuery == null) return;
    final params = <String, dynamic>{};
    var skipped = 0;
    final raw = query['params'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is String && value.startsWith('<') && value.endsWith('>')) {
          skipped++;
        } else {
          params[entry.key.toString()] = value;
        }
      }
    }
    final note = skipped == 0
        ? 'Query transferred from the Live tab.'
        : '$skipped sanitized parameters were not transferred; \$uid is bound by the backend.';
    onOpenQuery(query['query']?.toString() ?? '', params, note);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pushSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final entries = _maps(_data?['entries']);
    final library = _maps(_data?['library']);
    final selected = entries.where((entry) => entry['id'] == _selectedId);
    final entry = selected.isNotEmpty
        ? selected.first
        : entries.isNotEmpty
        ? entries.first
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Live · ${_data?['displayName'] ?? 'Current user'}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: t.text,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() => _paused = !_paused);
                _schedule();
              },
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              label: Text(_paused ? 'Resume' : 'Pause updates'),
            ),
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Aggiorna',
            ),
            if (widget.push != null)
              Chip(
                avatar: Icon(
                  _pushEvents > 0 ? Icons.bolt : Icons.bolt_outlined,
                  size: 16,
                  color: _pushEvents > 0 ? t.green : t.faint,
                ),
                label: Text(
                  _pushEvents > 0 ? 'socket push' : 'push waiting',
                  style: TextStyle(fontSize: 11, color: t.sub),
                ),
              ),
          ],
        ),
        Text(
          'Run an action in the app, even in another window with the same account. '
          'Queries appear here after the request completes. '
          'History: last 30 actions, expiring after 30 minutes of inactivity or a backend restart.',
          style: TextStyle(color: t.sub),
        ),
        if (_data != null)
          Text(
            'Current state read at ${_data!['observedAt']}',
            style: TextStyle(color: t.faint, fontSize: 12),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            'Refresh failed: $_error\nPrevious data may be stale.',
            style: TextStyle(color: t.red),
          ),
        ],
        if (_data == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final history = _panel(
              context,
              'Captured actions',
              Column(
                children: [
                  if (entries.isEmpty)
                    const Text(
                      'No actions yet. Try a like or dislike, or open the library.',
                    ),
                  for (final action in entries)
                    ListTile(
                      selected: action['id'] == entry?['id'],
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        action['status'] == 'error'
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: action['status'] == 'error' ? t.red : t.green,
                      ),
                      title: Text(
                        '${action['id'] == _highlightId ? '● ' : ''}'
                        '${action['action']}${action['tmdbId'] == null ? '' : ' · ${action['title'] ?? '#${action['tmdbId']}'}'}',
                      ),
                      subtitle: Text(
                        '${action['startedAt']}\n${action['durationMs']} ms · HTTP ${action['httpStatus']}',
                      ),
                      onTap: () => setState(
                        () => _selectedId = action['id']?.toString(),
                      ),
                    ),
                ],
              ),
            );
            final details = entry == null
                ? const SizedBox.shrink()
                : _actionDetails(context, entry);
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: history),
                  const SizedBox(width: 16),
                  Expanded(child: details),
                ],
              );
            }
            return Column(
              children: [history, const SizedBox(height: 12), details],
            );
          },
        ),
        const SizedBox(height: 16),
        _pathPanel(context),
        const SizedBox(height: 16),
        _rankingPanel(context),
        const SizedBox(height: 16),
        _panel(
          context,
          'Current library · persistent relationships',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in const [
                    'LIKED',
                    'DISLIKED',
                    'WATCHLISTED',
                    'ALREADY_SEEN',
                    'SELECTED_FAVORITE',
                  ])
                    ChoiceChip(
                      label: Text(
                        '$type (${library.where((row) => row['type'] == type).length})',
                      ),
                      selected: _relation == type,
                      onSelected: (_) => setState(() => _relation = type),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (!library.any((row) => row['type'] == _relation))
                const Text('Lista vuota.'),
              for (final movie in library.where(
                (row) => row['type'] == _relation,
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${movie['title'] ?? 'Film'} · #${movie['tmdbId']}',
                  ),
                  subtitle: Text('createdAt: ${movie['createdAt'] ?? '—'}'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionDetails(BuildContext context, Map<String, dynamic> entry) {
    final transactions = _maps(entry['transactions']);
    return _panel(
      context,
      '${entry['action']} · dettaglio',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText('${entry['endpoint']}\nRichiesta ${entry['id']}'),
          if (entry['error'] != null) Text('${entry['error']}'),
          for (final tx in transactions) ...[
            const SizedBox(height: 12),
            Text(
              '${tx['id']} · ${tx['mode']} · ${tx['status']}'.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (tx['status'] == 'rolled_back')
              const Text(
                'Attempt rolled back: its query counters are not persisted changes.',
              ),
            if (tx['status'] == 'commit_unknown')
              const Text(
                'Commit acknowledgement not received: check the current state in the library.',
              ),
            if (tx['before'] is Map && tx['after'] is! Map)
              ExpansionTile(
                title: const Text('Snapshot before the attempt'),
                children: [SelectableText(_json(tx['before']), style: _code)],
              ),
            if (tx['before'] is Map && tx['after'] is Map)
              _stateDiff(
                context,
                _map(tx['before']),
                _map(tx['after']),
                tx['status']?.toString() ?? 'pending',
              ),
          ],
          if (transactions.isEmpty)
            const Text(
              'Auto-commit queries. Current state is available in the library below.',
            ),
          const SizedBox(height: 12),
          const Text(
            'Cypher actually executed',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final query in _maps(entry['queries']))
            ExpansionTile(
              key: ValueKey('${entry['id']}-${query['order']}'),
              tilePadding: EdgeInsets.zero,
              title: Text('${query['order']}. ${query['name']}'),
              subtitle: Text(
                '${query['transactionId'] ?? 'auto-commit'} · ${query['durationMs']} ms · '
                '${query['records'] ?? '—'} rows · ${query['status']}',
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText('${query['query']}', style: _code),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    'Parameters\n${_json(query['params'])}\nQuery counters\n${_json(query['counters'])}',
                    style: _code,
                  ),
                ),
                if (query['error'] != null)
                  Text(
                    '${query['error']}',
                    style: TextStyle(color: context.tokens.red),
                  ),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: '${query['query']}'),
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Cypher'),
                    ),
                    if (widget.onOpenQuery != null)
                      TextButton.icon(
                        onPressed: () => _openInQuery(query),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open in Query tab'),
                      ),
                  ],
                ),
              ],
            ),
          if (entry['queryLimitReached'] == true)
            const Text('Trace limited to the first 100 queries.'),
        ],
      ),
    );
  }

  Widget _stateDiff(
    BuildContext context,
    Map<String, dynamic> before,
    Map<String, dynamic> after,
    String status,
  ) {
    final t = context.tokens;
    final oldTypes = _types(before);
    final newTypes = _types(after);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${after['title'] ?? before['title'] ?? 'Selected movie'}',
          style: const TextStyle(fontSize: 18),
        ),
        Text(
          status == 'committed'
              ? 'Before → after commit'
              : status == 'rolled_back'
              ? 'Before → attempted state (not persisted)'
              : 'Before → attempted state (outcome to verify)',
        ),
        if (oldTypes.isNotEmpty || newTypes.isNotEmpty)
          _DiffGraph(
            before: oldTypes,
            after: newTypes,
            title: _movieTitle(after, before),
          ),
        for (final type in {...oldTypes, ...newTypes})
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${!oldTypes.contains(type)
                  ? '+'
                  : !newTypes.contains(type)
                  ? '−'
                  : '='} '
              '(Me) ──[$type]──> (Movie)   '
              '${oldTypes.contains(type) ? 'present' : 'absent'} → ${newTypes.contains(type) ? 'present' : 'absent'}',
              style: _code.copyWith(
                color: !oldTypes.contains(type)
                    ? t.green
                    : !newTypes.contains(type)
                    ? t.red
                    : t.sub,
              ),
            ),
          ),
        if (oldTypes.isEmpty && newTypes.isEmpty)
          const Text('No relationships before or after.'),
        Text('Quota UTC: ${before['quotaUsed']} → ${after['quotaUsed']}'),
        if (before['batchAction'] != null || after['batchAction'] != null)
          Text(
            'Batch action: ${before['batchAction'] ?? '—'} → ${after['batchAction'] ?? '—'}',
          ),
        ExpansionTile(
          title: const Text('Properties before / after'),
          children: [
            SelectableText(
              'BEFORE\n${_json(before)}\nAFTER\n${_json(after)}',
              style: _code,
            ),
          ],
        ),
      ],
    );
  }

  static Set<String> _types(Map<String, dynamic> snapshot) => {
    for (final rel in _maps(snapshot['relationships']))
      if ((rel['type']?.toString() ?? '').isNotEmpty) rel['type'].toString(),
  };

  static String _movieTitle(
    Map<String, dynamic> primary,
    Map<String, dynamic> fallback,
  ) =>
      primary['title']?.toString() ??
      fallback['title']?.toString() ??
      'Selected movie';

  Widget _pathPanel(BuildContext context) {
    final t = context.tokens;
    final path = _map(_path?['path']);
    final segments = _maps(_path?['segments']);
    return _panel(
      context,
      'Real recommendation path',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'A path that really exists in the graph: your signals, the TMDB–MovieLens bridge, a collaborative neighbor and a candidate you have not interacted with yet.',
                  style: TextStyle(color: t.sub),
                ),
              ),
              IconButton(
                onPressed: _pathLoading ? null : _loadPath,
                icon: _pathLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Reload the path',
              ),
            ],
          ),
          if (_pathError != null)
            Text(_pathError!, style: TextStyle(color: t.red)),
          if (path.isEmpty && segments.isEmpty && _pathError == null)
            const Text('No path loaded.'),
          if (path.isEmpty && segments.isEmpty && _path?['reason'] != null)
            Text('${_path?['reason']}', style: TextStyle(color: t.sub)),
          if (path.isNotEmpty) ...[
            _PathChain(segments: segments),
            const SizedBox(height: 8),
            Text(
              'Sample traversal path: the full score aggregates multiple neighbors and includes the semantic component.',
              style: TextStyle(color: t.faint, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rankingPanel(BuildContext context) {
    final t = context.tokens;
    final baseline = _rankingBaseline;
    final current = _rankingCurrent;
    return _panel(
      context,
      'Ranking comparison (explicit recompute)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Engine tab is recomputed on demand (cache bypass). The actions observed above do not affect it: the comparison is a deliberate step.',
            style: TextStyle(color: t.sub),
          ),
          if (_rankingError != null)
            Text(_rankingError!, style: TextStyle(color: t.red)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _rankingBusy
                    ? null
                    : () => _captureRanking(baseline: true),
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Capture ranking'),
              ),
              FilledButton.tonalIcon(
                onPressed: _rankingBusy || baseline == null
                    ? null
                    : () => _captureRanking(baseline: false),
                icon: const Icon(Icons.compare_arrows, size: 18),
                label: const Text('Recompute and compare'),
              ),
              if (baseline != null)
                TextButton(
                  onPressed: _rankingBusy ? null : _resetRanking,
                  child: const Text('Reset'),
                ),
              if (_rankingBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (baseline != null && current == null) ...[
            const SizedBox(height: 10),
            Text(
              'Baseline captured at ${_rankingCapturedAt ?? '—'}:',
              style: TextStyle(color: t.faint, fontSize: 12),
            ),
            for (final movie in baseline.take(5))
              Text(
                '${movie.rank}. ${movie.title} · ${_fmt(movie.score)}',
                style: _code,
              ),
          ],
          if (baseline != null && current != null) ...[
            const SizedBox(height: 10),
            _RankingDiff(before: baseline, after: current),
          ],
        ],
      ),
    );
  }
}

class _RankedMovie {
  const _RankedMovie({
    required this.rank,
    required this.tmdbId,
    required this.title,
    required this.score,
    required this.source,
  });

  final int rank;
  final int tmdbId;
  final String title;
  final double score;
  final String source;
}

class _RankingDiff extends StatelessWidget {
  const _RankingDiff({required this.before, required this.after});

  final List<_RankedMovie> before;
  final List<_RankedMovie> after;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final beforeById = {for (final movie in before) movie.tmdbId: movie};
    final afterById = {for (final movie in after) movie.tmdbId: movie};
    final added = after.where((m) => !beforeById.containsKey(m.tmdbId));
    final removed = before.where((m) => !afterById.containsKey(m.tmdbId));
    final moved = after.where(
      (m) =>
          beforeById.containsKey(m.tmdbId) &&
          beforeById[m.tmdbId]!.rank != m.rank,
    );
    final stable = after.where(
      (m) =>
          beforeById.containsKey(m.tmdbId) &&
          beforeById[m.tmdbId]!.rank == m.rank,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New in ranking',
          style: TextStyle(color: t.green, fontWeight: FontWeight.bold),
        ),
        if (added.isEmpty) const Text('—'),
        for (final movie in added)
          Text(
            '+ ${movie.rank}. ${movie.title} · ${_fmt(movie.score)} [${movie.source}]',
            style: _code.copyWith(color: t.green),
          ),
        const SizedBox(height: 6),
        Text(
          'Dropped from ranking',
          style: TextStyle(color: t.red, fontWeight: FontWeight.bold),
        ),
        if (removed.isEmpty) const Text('—'),
        for (final movie in removed)
          Text(
            '− ${movie.rank}. ${movie.title} · ${_fmt(movie.score)}',
            style: _code.copyWith(color: t.red),
          ),
        const SizedBox(height: 6),
        Text(
          'Position changed',
          style: TextStyle(color: t.gold, fontWeight: FontWeight.bold),
        ),
        if (moved.isEmpty) const Text('—'),
        for (final movie in moved)
          Text(
            '${beforeById[movie.tmdbId]!.rank} → ${movie.rank}  ${movie.title} (${_fmt(movie.score)})',
            style: _code,
          ),
        const SizedBox(height: 6),
        Text('Unchanged: ${stable.length}', style: TextStyle(color: t.sub)),
      ],
    );
  }
}

class _DiffGraph extends StatelessWidget {
  const _DiffGraph({
    required this.before,
    required this.after,
    required this.title,
  });

  final Set<String> before;
  final Set<String> after;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final types = <String>[
      ...before,
      ...after.where((type) => !before.contains(type)),
    ];
    final height = 90.0 + types.length * 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _DiffGraphPainter(
              before: before,
              after: after,
              types: types,
              tokens: t,
            ),
          ),
        ),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _LegendLine(color: t.green, label: 'created'),
            _LegendLine(color: t.red, label: 'removed', dashed: true),
            _LegendLine(color: t.sub, label: 'unchanged'),
          ],
        ),
        Text(
          'Shared node: $title',
          style: TextStyle(color: t.faint, fontSize: 12),
        ),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 10,
          child: CustomPaint(
            painter: _LineSamplePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: context.tokens.sub),
        ),
      ],
    );
  }
}

class _LineSamplePainter extends CustomPainter {
  const _LineSamplePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    if (dashed) {
      _drawDashed(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineSamplePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

class _DiffGraphPainter extends CustomPainter {
  _DiffGraphPainter({
    required this.before,
    required this.after,
    required this.types,
    required this.tokens,
  });

  final Set<String> before;
  final Set<String> after;
  final List<String> types;
  final AgreeoTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 200 || types.isEmpty) return;
    const nodeRadius = 24.0;
    final left = Offset(54, size.height / 2);
    final right = Offset(size.width - 54, size.height / 2);
    final nodePaint = Paint()..color = tokens.surface2;
    final nodeBorder = Paint()
      ..color = tokens.line2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var index = 0; index < types.length; index++) {
      final type = types[index];
      final added = !before.contains(type) && after.contains(type);
      final removed = before.contains(type) && !after.contains(type);
      final color = added
          ? tokens.green
          : removed
          ? tokens.red
          : tokens.sub;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final spread = (index - (types.length - 1) / 2) * 30.0;
      final start = Offset(left.dx + nodeRadius, left.dy + spread * 0.25);
      final end = Offset(right.dx - nodeRadius, right.dy + spread * 0.25);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + (end.dx - start.dx) * 0.4,
          start.dy + spread * 0.9,
          start.dx + (end.dx - start.dx) * 0.6,
          end.dy + spread * 0.9,
          end.dx,
          end.dy,
        );
      if (removed) {
        _drawDashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }

      // Arrow head at the movie side.
      final metrics = path.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final metric = metrics.first;
        final tangent = metric.getTangentForOffset(metric.length);
        if (tangent != null) {
          final angle = tangent.angle;
          final tip = tangent.position;
          final arrow = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(
              tip.dx - 8 * math.cos(angle - 0.42),
              tip.dy - 8 * math.sin(angle - 0.42),
            )
            ..lineTo(
              tip.dx - 8 * math.cos(angle + 0.42),
              tip.dy - 8 * math.sin(angle + 0.42),
            )
            ..close();
          canvas.drawPath(arrow, Paint()..color = color);
        }

        // Edge label at the middle of the curve.
        final middle = metric.getTangentForOffset(metric.length / 2);
        if (middle != null) {
          final painter = TextPainter(
            text: TextSpan(
              text: type,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final origin = Offset(
            middle.position.dx - painter.width / 2,
            middle.position.dy - painter.height / 2,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                origin.dx - 3,
                origin.dy - 1,
                painter.width + 6,
                painter.height + 2,
              ),
              const Radius.circular(3),
            ),
            Paint()..color = tokens.surface,
          );
          painter.paint(canvas, origin);
        }
      }
    }

    canvas.drawCircle(left, nodeRadius, nodePaint);
    canvas.drawCircle(left, nodeRadius, nodeBorder);
    canvas.drawCircle(right, nodeRadius, nodePaint);
    canvas.drawCircle(right, nodeRadius, nodeBorder);
    _label(
      canvas,
      'AppUser',
      Offset(left.dx, left.dy + nodeRadius + 4),
      tokens.text,
    );
    _label(
      canvas,
      'Movie',
      Offset(right.dx, right.dy + nodeRadius + 4),
      tokens.text,
    );
  }

  void _label(Canvas canvas, String text, Offset center, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _DiffGraphPainter oldDelegate) =>
      oldDelegate.before != before ||
      oldDelegate.after != after ||
      oldDelegate.tokens != tokens;
}

void _drawDashed(Canvas canvas, Path path, Paint paint) {
  const dash = 6.0;
  const gap = 4.0;
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance = end + gap;
    }
  }
}

class _PathChain extends StatelessWidget {
  const _PathChain({required this.segments});

  final List<Map<String, dynamic>> segments;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final segment in segments)
          if (segment['kind'] == 'rel')
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.south, size: 14, color: t.faint),
                  const SizedBox(width: 6),
                  Text(
                    '[:${segment['label']}]'
                    '${segment['direction'] == 'in' ? ' (traversed backwards)' : ''}'
                    '${segment['value'] != null ? ' · rating ${segment['value']}' : ''}',
                    style: _code.copyWith(color: t.purpleDeep),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  Icon(
                    _pathIcon(segment['kind']?.toString()),
                    size: 16,
                    color: t.gold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${segment['label'] ?? '?'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (segment['sub'] != null)
                          Text(
                            '${segment['sub']}',
                            style: TextStyle(fontSize: 11.5, color: t.faint),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static IconData _pathIcon(String? kind) => switch (kind) {
    'user' => Icons.person_outline,
    'movie' => Icons.movie_outlined,
    'movielens-movie' => Icons.video_library_outlined,
    'movielens-user' => Icons.hub_outlined,
    _ => Icons.circle_outlined,
  };
}

const _code = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5);
String _json(dynamic value) =>
    const JsonEncoder.withIndent('  ').convert(value);
String _fmt(double value) => value.toStringAsFixed(2);
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> _maps(dynamic value) =>
    value is List ? value.whereType<Map>().map(_map).toList() : [];

Widget _panel(BuildContext context, String title, Widget child) => Material(
  color: context.tokens.surface,
  shape: RoundedRectangleBorder(
    side: BorderSide(color: context.tokens.line),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: context.tokens.text,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  ),
);
