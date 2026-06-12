import 'package:agreeo/services/neo4j_debug_service.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Settings › Developer › Neo4j Console. Read-only window on the graph database
/// backing Agreeo: server info, schema, indexes/constraints and a live Cypher
/// console with EXPLAIN/PROFILE. Data comes from the backend `/debug/neo4j/*`
/// endpoints (enabled with ENABLE_NEO4J_DEBUG=true).
class Neo4jConsoleScreen extends StatefulWidget {
  const Neo4jConsoleScreen({super.key});

  @override
  State<Neo4jConsoleScreen> createState() => _Neo4jConsoleScreenState();
}

class _Neo4jConsoleScreenState extends State<Neo4jConsoleScreen> {
  final Neo4jDebugService _service = Neo4jDebugService();
  int _tab = 0;

  late Future<Neo4jOverview> _overviewFuture;
  late Future<List<Neo4jSchemaPattern>> _schemaFuture;
  late Future<Neo4jIndexReport> _indexesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _overviewFuture = _service.getOverview();
      _schemaFuture = _service.getSchema();
      _indexesFuture = _service.getIndexes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Row(
                children: [
                  _CircleButton(icon: AgIcons.chevronLeft, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Neo4j Console',
                      style: TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        fontWeight: FontWeight.w800,
                        fontSize: 23,
                        letterSpacing: -0.5,
                        color: t.text,
                      ),
                    ),
                  ),
                  _CircleButton(icon: AgIcons.refresh, onTap: _reload),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TabSelector(
                tabs: const ['Info', 'Schema', 'Indici', 'Query'],
                selected: _tab,
                onChanged: (index) => setState(() => _tab = index),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _OverviewTab(future: _overviewFuture, onRetry: _reload),
                  _SchemaTab(future: _schemaFuture, onRetry: _reload),
                  _IndexesTab(future: _indexesFuture, onRetry: _reload),
                  _QueryTab(service: _service),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

const _monoStyle = TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.45);

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.line),
        ),
        child: Icon(icon, size: 20, color: t.text),
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.tabs, required this.selected, required this.onChanged});
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected == i ? t.grad : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected == i ? Colors.white : t.sub,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 18, color: t.gold),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Bricolage Grotesque',
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            letterSpacing: -0.3,
            color: t.text,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.borderColor});
  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? t.line),
      ),
      child: child,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _Card(
        borderColor: t.red.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AgIcons.wifiOff, size: 18, color: t.red),
                const SizedBox(width: 8),
                Text(
                  'Console non disponibile',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: t.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: _monoStyle.copyWith(color: t.sub)),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  'Riprova',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: t.purple,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.text, this.gold = false});
  final String text;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: gold ? t.gold.withValues(alpha: 0.14) : t.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold ? t.gold.withValues(alpha: 0.5) : t.line2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          color: gold ? t.gold : t.sub,
        ),
      ),
    );
  }
}

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 10000) return '${(count / 1000).toStringAsFixed(1)}k';
  return count.toString();
}

// ---------------------------------------------------------------------------
// Tab 1 — Overview
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.future, required this.onRetry});
  final Future<Neo4jOverview> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FutureBuilder<Neo4jOverview>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorCard(message: snapshot.error.toString(), onRetry: onRetry);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: t.green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${data.server.name} ${data.server.version}',
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: t.text,
                        ),
                      ),
                      const Spacer(),
                      _CountPill(text: data.server.edition, gold: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('bolt  ${data.server.uri}', style: _monoStyle.copyWith(color: t.sub)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(label: 'Nodi', value: _formatCount(data.nodeCount)),
                const SizedBox(width: 10),
                _StatCard(label: 'Relazioni', value: _formatCount(data.relationshipCount)),
                const SizedBox(width: 10),
                _StatCard(label: 'Property key', value: _formatCount(data.propertyKeyCount)),
              ],
            ),
            const SizedBox(height: 18),
            _SectionTitle(icon: AgIcons.library, title: 'Nodi per label'),
            const SizedBox(height: 9),
            _Card(
              child: Column(
                children: [
                  for (final entry in data.labels)
                    _KeyCountRow(name: '(:${entry.label})', count: entry.count),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(icon: AgIcons.share, title: 'Relazioni per tipo'),
            const SizedBox(height: 9),
            _Card(
              child: Column(
                children: [
                  for (final entry in data.relationshipTypes)
                    _KeyCountRow(name: '[:${entry.type}]', count: entry.count),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Bricolage Grotesque',
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: t.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontFamily: 'Manrope', fontSize: 11.5, color: t.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyCountRow extends StatelessWidget {
  const _KeyCountRow({required this.name, required this.count});
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(name, style: _monoStyle.copyWith(color: t.text))),
          _CountPill(text: _formatCount(count)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — Schema (graph patterns with counts)
// ---------------------------------------------------------------------------

class _SchemaTab extends StatelessWidget {
  const _SchemaTab({required this.future, required this.onRetry});
  final Future<List<Neo4jSchemaPattern>> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FutureBuilder<List<Neo4jSchemaPattern>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorCard(message: snapshot.error.toString(), onRetry: onRetry);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final patterns = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            Text(
              'Pattern reali del grafo, con il numero di relazioni per ciascuno.',
              style: TextStyle(fontFamily: 'Manrope', fontSize: 12.5, color: t.faint),
            ),
            const SizedBox(height: 10),
            for (final pattern in patterns) ...[
              _Card(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '(:${pattern.from.join(':')})-[:${pattern.relType}]->(:${pattern.to.join(':')})',
                        style: _monoStyle.copyWith(color: t.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CountPill(text: _formatCount(pattern.count), gold: true),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3 — Indexes & constraints
// ---------------------------------------------------------------------------

class _IndexesTab extends StatelessWidget {
  const _IndexesTab({required this.future, required this.onRetry});
  final Future<Neo4jIndexReport> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FutureBuilder<Neo4jIndexReport>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorCard(message: snapshot.error.toString(), onRetry: onRetry);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final report = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            _SectionTitle(icon: AgIcons.sparkle, title: 'Indici (${report.indexes.length})'),
            const SizedBox(height: 9),
            for (final index in report.indexes) ...[
              _IndexCard(index: index),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            _SectionTitle(icon: AgIcons.shield, title: 'Constraint (${report.constraints.length})'),
            const SizedBox(height: 9),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < report.constraints.length; i++) ...[
                    if (i > 0) Divider(height: 14, thickness: 1, color: t.line),
                    Text(
                      '${report.constraints[i].name}\n'
                      '${report.constraints[i].type} · '
                      '(:${report.constraints[i].labelsOrTypes.join(':')}) '
                      'ON ${report.constraints[i].properties.join(', ')}',
                      style: _monoStyle.copyWith(color: t.sub),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IndexCard extends StatelessWidget {
  const _IndexCard({required this.index});
  final Neo4jIndexInfo index;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isVector = index.type.toUpperCase() == 'VECTOR';
    final indexConfig = index.options['indexConfig'];
    final vectorConfig = indexConfig is Map<String, dynamic>
        ? indexConfig
        : const <String, dynamic>{};

    return _Card(
      borderColor: isVector ? t.gold.withValues(alpha: 0.55) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  index.name,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: t.text,
                  ),
                ),
              ),
              _CountPill(text: index.type, gold: isVector),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${index.entityType == 'RELATIONSHIP' ? '[' : '(:'}'
            '${index.labelsOrTypes.join(':')}'
            '${index.entityType == 'RELATIONSHIP' ? ']' : ')'}'
            ' ON ${index.properties.join(', ')}',
            style: _monoStyle.copyWith(color: t.sub),
          ),
          if (isVector) ...[
            const SizedBox(height: 6),
            Text(
              'dimensions: ${vectorConfig['vector.dimensions'] ?? '?'} · '
              'similarity: ${vectorConfig['vector.similarity_function'] ?? '?'}',
              style: _monoStyle.copyWith(color: t.gold),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: index.state.toUpperCase() == 'ONLINE' ? t.green : t.gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${index.state} · ${index.populationPercent.toStringAsFixed(0)}% · ${index.provider}',
                style: TextStyle(fontFamily: 'Manrope', fontSize: 11.5, color: t.faint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 4 — Cypher console
// ---------------------------------------------------------------------------

const List<(String, String)> _presetQueries = [
  (
    'Top film',
    'MATCH (m:Movie)\n'
        'WHERE m.movieLensRatingCount IS NOT NULL\n'
        'RETURN m.title AS titolo, m.movieLensAvgRating AS rating,\n'
        '       m.movieLensRatingCount AS voti\n'
        'ORDER BY voti DESC LIMIT 10',
  ),
  (
    'Like utenti',
    'MATCH (u:AppUser)-[:LIKED]->(m:Movie)\n'
        'RETURN u.displayName AS utente, count(m) AS like,\n'
        '       collect(m.title)[..5] AS esempi\n'
        'ORDER BY like DESC LIMIT 10',
  ),
  (
    'Collaborative filtering',
    'MATCH (me:AppUser)-[:LIKED]->(:Movie)<-[:MATCHES_TMDB]-(seed:MovieLensMovie)\n'
        'MATCH (seed)<-[r1:RATED]-(sim:MovieLensUser)-[r2:RATED]->\n'
        '      (rec:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)\n'
        'WHERE r1.rating >= 4 AND r2.rating >= 4\n'
        '  AND NOT (me)-[:LIKED|ALREADY_SEEN]->(m)\n'
        'RETURN m.title AS consiglio, count(DISTINCT sim) AS utentiSimili,\n'
        '       round(avg(r2.rating), 2) AS ratingMedio\n'
        'ORDER BY utentiSimili DESC, ratingMedio DESC LIMIT 10',
  ),
  (
    'Vector search',
    "MATCH (t:Tag {name: 'funny'})\n"
        "CALL db.index.vector.queryNodes('tag_embeddings', 8, t.embedding)\n"
        'YIELD node, score\n'
        'RETURN node.name AS tag, round(score, 3) AS similarita\n'
        'ORDER BY score DESC',
  ),
  (
    'Bridge TMDB-MovieLens',
    'MATCH (ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)\n'
        'RETURN m.title AS titolo, m.tmdbId AS tmdbId,\n'
        '       ml.movieLensId AS movieLensId\n'
        'LIMIT 10',
  ),
  (
    'Tag frequenti',
    'MATCH (ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)\n'
        'RETURN t.name AS tag, sum(h.frequency) AS frequenza\n'
        'ORDER BY frequenza DESC LIMIT 15',
  ),
];

class _QueryTab extends StatefulWidget {
  const _QueryTab({required this.service});
  final Neo4jDebugService service;

  @override
  State<_QueryTab> createState() => _QueryTabState();
}

class _QueryTabState extends State<_QueryTab> {
  final TextEditingController _controller =
      TextEditingController(text: _presetQueries.first.$2);
  String? _mode; // null | 'explain' | 'profile'
  bool _running = false;
  Neo4jQueryResult? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _running) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final result = await widget.service.runQuery(query, mode: _mode);
      setState(() => _result = result);
    } catch (error) {
      setState(() {
        _result = null;
        _error = error.toString();
      });
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      children: [
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _presetQueries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = _presetQueries[index];
              return GestureDetector(
                onTap: () => setState(() => _controller.text = preset.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.line),
                  ),
                  child: Text(
                    preset.$1,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: t.sub,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.line),
          ),
          child: TextField(
            controller: _controller,
            maxLines: 8,
            minLines: 4,
            style: _monoStyle.copyWith(color: t.text),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(13),
              hintText: 'MATCH (n) RETURN n LIMIT 10',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ModeChip(
              label: 'EXPLAIN',
              active: _mode == 'explain',
              onTap: () => setState(() => _mode = _mode == 'explain' ? null : 'explain'),
            ),
            const SizedBox(width: 8),
            _ModeChip(
              label: 'PROFILE',
              active: _mode == 'profile',
              onTap: () => setState(() => _mode = _mode == 'profile' ? null : 'profile'),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _run,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 19),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: t.grad,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _running
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        children: [
                          const Icon(AgIcons.play, size: 19, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            'Esegui',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null)
          _Card(
            borderColor: t.red.withValues(alpha: 0.4),
            child: Text(_error!, style: _monoStyle.copyWith(color: t.red)),
          ),
        if (_result != null) _QueryResultView(result: _result!),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? t.purple.withValues(alpha: 0.14) : t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? t.purple : t.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            color: active ? t.purple : t.sub,
          ),
        ),
      ),
    );
  }
}

class _QueryResultView extends StatelessWidget {
  const _QueryResultView({required this.result});
  final Neo4jQueryResult result;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final timing = [
      '${result.totalRows} righe${result.truncated ? ' (troncate)' : ''}',
      '${result.wallTimeMs} ms totali',
      if (result.resultAvailableAfterMs != null)
        '${result.resultAvailableAfterMs} ms disponibile',
      if (result.resultConsumedAfterMs != null) '${result.resultConsumedAfterMs} ms consumo',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          timing,
          style: TextStyle(fontFamily: 'Manrope', fontSize: 11.5, color: t.faint),
        ),
        const SizedBox(height: 8),
        if (result.plan != null) ...[
          _SectionTitle(icon: AgIcons.sliders, title: 'Piano di esecuzione'),
          const SizedBox(height: 8),
          _Card(child: _PlanNode(plan: result.plan!, depth: 0)),
          const SizedBox(height: 12),
        ],
        if (result.rows.isNotEmpty) ...[
          for (var i = 0; i < result.rows.length; i++) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < result.columns.length; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 105,
                            child: Text(
                              result.columns[c],
                              style: _monoStyle.copyWith(
                                color: t.purple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _formatCell(result.rows[i].length > c ? result.rows[i][c] : null),
                              style: _monoStyle.copyWith(color: t.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ] else if (result.plan == null)
          _Card(
            child: Text('Nessuna riga restituita.', style: _monoStyle.copyWith(color: t.sub)),
          ),
      ],
    );
  }

  static String _formatCell(dynamic value) {
    if (value == null) return 'null';
    if (value is Map<String, dynamic>) {
      switch (value['_type']) {
        case 'node':
          final labels = (value['labels'] as List? ?? const []).join(':');
          return '(:$labels ${_shortMap(value['properties'])})';
        case 'relationship':
          return '[:${value['relType']} ${_shortMap(value['properties'])}]';
        case 'path':
          return 'path(${(value['segments'] as List? ?? const []).length} segmenti)';
        default:
          return _shortMap(value);
      }
    }
    if (value is List) {
      return '[${value.map(_formatCell).join(', ')}]';
    }
    return value.toString();
  }

  static String _shortMap(dynamic properties) {
    if (properties is! Map<String, dynamic> || properties.isEmpty) return '{}';
    final entries = properties.entries
        .take(4)
        .map((entry) => '${entry.key}: ${_shortValue(entry.value)}')
        .join(', ');
    final suffix = properties.length > 4 ? ', …' : '';
    return '{$entries$suffix}';
  }

  static String _shortValue(dynamic value) {
    if (value is String) {
      return value.length > 28 ? "'${value.substring(0, 25)}…'" : "'$value'";
    }
    if (value is List && value.length > 4) {
      return '[${value.length} elementi]';
    }
    return value.toString();
  }
}

class _PlanNode extends StatelessWidget {
  const _PlanNode({required this.plan, required this.depth});
  final Neo4jQueryPlan plan;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final metrics = [
      if (plan.estimatedRows != null) 'est ${plan.estimatedRows}',
      if (plan.rows != null) 'rows ${plan.rows}',
      if (plan.dbHits != null) 'db hits ${plan.dbHits}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 14.0, top: depth == 0 ? 0 : 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${depth == 0 ? '' : '└ '}${plan.operatorType.split('@').first}',
                style: _monoStyle.copyWith(color: t.text, fontWeight: FontWeight.w700),
              ),
              if (plan.details != null && plan.details!.isNotEmpty)
                Text(plan.details!, style: _monoStyle.copyWith(color: t.sub, fontSize: 11.5)),
              if (metrics.isNotEmpty)
                Text(metrics, style: _monoStyle.copyWith(color: t.gold, fontSize: 11.5)),
            ],
          ),
        ),
        for (final child in plan.children) _PlanNode(plan: child, depth: depth + 1),
      ],
    );
  }
}
