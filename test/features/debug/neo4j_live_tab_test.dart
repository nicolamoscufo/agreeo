import 'package:agreeo/features/debug/presentation/neo4j_live_tab.dart';
import 'package:agreeo/services/neo4j_debug_service.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LiveService extends Neo4jDebugService {
  int calls = 0;
  int pathCalls = 0;
  int engineCalls = 0;

  @override
  Future<Map<String, dynamic>> getLiveTrace() async {
    calls++;
    return {
      'displayName': 'Alice',
      'observedAt': '2026-09-18T12:00:00Z',
      'library': [
        {'tmdbId': 550, 'title': 'Fight Club', 'type': 'DISLIKED'},
      ],
      'entries': [
        {
          'id': 'request-1',
          'action': 'Dislike',
          'tmdbId': '550',
          'title': 'Fight Club',
          'status': 'completed',
          'httpStatus': 200,
          'durationMs': 15,
          'startedAt': '12:00:00',
          'endpoint': 'POST /me/movies/550/dislike',
          'transactions': [
            {
              'id': 'tx-1',
              'mode': 'write',
              'status': 'committed',
              'before': {
                'title': 'Fight Club',
                'quotaUsed': 0,
                'relationships': [
                  {'type': 'LIKED'},
                ],
              },
              'after': {
                'title': 'Fight Club',
                'quotaUsed': 0,
                'relationships': [
                  {'type': 'DISLIKED'},
                ],
              },
            },
          ],
          'queries': [
            {
              'order': 1,
              'name': 'M09',
              'query': 'MERGE (u)-[:DISLIKED]->(m)',
              'transactionId': 'tx-1',
              'durationMs': 2,
              'records': 1,
              'status': 'completed',
              'params': {
                'uid': '<current-user>',
                'tmdbId': 550,
                'vector': '<array:384>',
              },
              'counters': {'relationshipsCreated': 1},
            },
          ],
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getRecommendationPath() async {
    pathCalls++;
    return {
      'path': {'user': 'Alice'},
      'segments': [
        {'kind': 'user', 'label': 'Alice', 'sub': 'AppUser'},
        {'kind': 'rel', 'label': 'LIKED', 'direction': 'out'},
        {'kind': 'movie', 'label': 'Arrival', 'sub': 'Movie #329865'},
        {'kind': 'rel', 'label': 'MATCHES_TMDB', 'direction': 'in'},
        {
          'kind': 'movielens-movie',
          'label': 'Arrival (2016)',
          'sub': 'MovieLens #1',
        },
        {'kind': 'rel', 'label': 'RATED', 'direction': 'in', 'value': 4.5},
        {
          'kind': 'movielens-user',
          'label': 'MovieLensUser #42',
          'sub': 'vicino collaborativo',
        },
        {'kind': 'rel', 'label': 'RATED', 'direction': 'out', 'value': 5.0},
        {
          'kind': 'movielens-movie',
          'label': 'Dune (2021)',
          'sub': 'MovieLens #2',
        },
        {'kind': 'rel', 'label': 'MATCHES_TMDB', 'direction': 'out'},
        {'kind': 'movie', 'label': 'Dune', 'sub': 'Movie #438631'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getRecommendationEngine() async {
    engineCalls++;
    final first = engineCalls == 1;
    return {
      'scoringStats': {
        'sampleRecommendations': first
            ? [
                {
                  'tmdbId': 1,
                  'title': 'Movie X',
                  'finalScore': 9.0,
                  'source': 'personalized',
                },
                {
                  'tmdbId': 2,
                  'title': 'Movie Y',
                  'finalScore': 8.0,
                  'source': 'hybrid',
                },
              ]
            : [
                {
                  'tmdbId': 2,
                  'title': 'Movie Y',
                  'finalScore': 9.5,
                  'source': 'hybrid',
                },
                {
                  'tmdbId': 3,
                  'title': 'Movie Z',
                  'finalScore': 7.0,
                  'source': 'semantic-tag',
                },
              ],
      },
    };
  }
}

Widget _app(
  _LiveService service, {
  bool active = true,
  OpenInQuery? onOpenQuery,
}) => MaterialApp(
  theme: ThemeData(extensions: const [AgreeoTokens.light]),
  home: Scaffold(
    body: Neo4jLiveTab(
      service: service,
      active: active,
      onOpenQuery: onOpenQuery,
    ),
  ),
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows diff, graph, path and transfers sanitized query params', (
    tester,
  ) async {
    final service = _LiveService();
    String? transferredQuery;
    Map<String, dynamic>? transferredParams;
    String? transferredNote;
    await tester.pumpWidget(
      _app(
        service,
        onOpenQuery: (query, params, note) {
          transferredQuery = query;
          transferredParams = params;
          transferredNote = note;
        },
      ),
    );
    await tester.pump();
    expect(find.text('Live · Alice'), findsOneWidget);
    expect(service.pathCalls, 1);
    await tester.tap(find.text('Pause updates'));
    await tester.pump();
    final calls = service.calls;
    await tester.pump(const Duration(seconds: 5));
    expect(service.calls, calls);
    await _reveal(tester, find.text('TX-1 · WRITE · COMMITTED'));
    expect(
      find.textContaining('LIKED]──> (Movie)   present → absent'),
      findsOneWidget,
    );
    expect(
      find.textContaining('DISLIKED]──> (Movie)   absent → present'),
      findsOneWidget,
    );
    final m09 = find.text('1. M09');
    await _reveal(tester, m09);
    await tester.tap(m09);
    await tester.pumpAndSettle();
    expect(find.text('MERGE (u)-[:DISLIKED]->(m)'), findsOneWidget);
    await _reveal(tester, find.text('Open in Query tab'));
    await tester.tap(find.text('Open in Query tab'));
    expect(transferredQuery, 'MERGE (u)-[:DISLIKED]->(m)');
    expect(transferredParams, {'tmdbId': 550});
    expect(transferredNote, contains('2 sanitized parameters'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders the real recommendation path chain', (tester) async {
    final service = _LiveService();
    await tester.pumpWidget(_app(service, active: false));
    await tester.pumpWidget(_app(service));
    await tester.pump();
    await _reveal(tester, find.text('Real recommendation path'));
    expect(find.text('MovieLensUser #42'), findsOneWidget);
    expect(find.textContaining('rating 4.5'), findsOneWidget);
    expect(find.textContaining('traversed backwards'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ranking comparison marks added, removed and moved movies', (
    tester,
  ) async {
    final service = _LiveService();
    await tester.pumpWidget(_app(service));
    await tester.pump();
    await _reveal(tester, find.text('Capture ranking'));
    await tester.tap(find.text('Capture ranking'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Baseline captured'), findsOneWidget);
    expect(find.textContaining('Movie X'), findsOneWidget);
    await _reveal(tester, find.text('Recompute and compare'));
    await tester.tap(find.text('Recompute and compare'));
    await tester.pumpAndSettle();
    expect(service.engineCalls, 2);
    expect(find.textContaining('+ 2. Movie Z'), findsOneWidget);
    expect(find.textContaining('− 1. Movie X'), findsOneWidget);
    expect(find.textContaining('2 → 1  Movie Y'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('inactive tab makes no requests and activation starts polling', (
    tester,
  ) async {
    final service = _LiveService();
    await tester.pumpWidget(_app(service, active: false));
    await tester.pump(const Duration(seconds: 3));
    expect(service.calls, 0);
    await tester.pumpWidget(_app(service));
    await tester.pump();
    expect(service.calls, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(service.calls, 2);
    await tester.pumpWidget(_app(service, active: false));
    await tester.pump(const Duration(seconds: 3));
    expect(service.calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
