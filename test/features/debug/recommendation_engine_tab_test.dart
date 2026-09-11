import 'package:agreeo/features/debug/presentation/recommendation_engine_tab.dart';
import 'package:agreeo/shared/theme/agreeo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the live recommendation explanation sections', (
    tester,
  ) async {
    final report = <String, dynamic>{
      'userProfileSignals': <String, dynamic>{
        'likedMoviesCount': 3,
        'dislikedMoviesCount': 1,
        'totalFeedbackActions': 4,
      },
      'recommendationSignals': <String, dynamic>{
        'topPositiveGenres': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Drama', 'score': 4},
        ],
        'topNegativeGenres': <Map<String, dynamic>>[],
        'topPositiveTags': <Map<String, dynamic>>[],
        'topNegativeTags': <Map<String, dynamic>>[],
      },
      'candidatePoolStats': <String, dynamic>{
        'totalCandidatesConsidered': 100,
        'remainingAfterFiltering': 80,
      },
      'forYouFeedStats': <String, dynamic>{'resultCount': 12},
      'dailySuggestionsStats': <String, dynamic>{
        'personalizedCandidateCount': 13,
        'exploratoryCandidateCount': 7,
      },
      'scoringStats': <String, dynamic>{
        'sampleRecommendations': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Arrival',
            'source': 'hybrid',
            'finalScore': 12.3,
            'collaborativeScore': 8.1,
            'semanticScore': 4.2,
            'reason': 'Collaborative and semantic match.',
          },
        ],
      },
      'engineTrace': <String, dynamic>{
        'generatedAt': '2026-08-21T10:00:00.000Z',
        'experimentVariant': 'control-v1',
        'stages': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': '1. Profilo utente',
            'description': 'Signals',
            'outputCount': 4,
          },
        ],
        'formulas': <String, dynamic>{'fusion': 'RRF = weight / (K + rank)'},
        'queries': <Map<String, dynamic>>[
          <String, dynamic>{
            'order': 1,
            'name': 'Collaborative filtering',
            'query': 'MATCH (u:AppUser) RETURN u',
            'params': <String, dynamic>{'uid': '<current-user>'},
            'durationMs': 12,
            'records': 3,
          },
        ],
        'metrics': <Map<String, dynamic>>[],
      },
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAgreeoTheme(Brightness.light),
        home: Scaffold(
          body: RecommendationEngineTab(
            future: Future<Map<String, dynamic>>.value(report),
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Recommendation Engine · Live trace'), findsOneWidget);
    expect(find.text('Pipeline live'), findsOneWidget);
    final reportScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Arrival'),
      400,
      scrollable: reportScroll,
    );
    expect(find.text('Arrival'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Collaborative filtering'),
      400,
      scrollable: reportScroll,
    );
    expect(find.text('Collaborative filtering'), findsOneWidget);
  });
}
