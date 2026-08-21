import 'dart:convert';

import 'package:agreeo/config/backend_config.dart';
import 'package:agreeo/services/auth_service.dart';
import 'package:agreeo/services/backend_movie_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/movie_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({this.refreshedToken});

  final String? refreshedToken;

  @override
  Future<String?> readToken() async => 'token-1';

  @override
  Future<String?> refreshAccessToken() async => refreshedToken;
}

Movie _movie() => const Movie(
  id: 'tmdb-10',
  tmdbId: 10,
  title: 'Movie',
  originalTitle: 'Movie',
  overview: '',
  posterUrl: '',
  backdropUrl: '',
  releaseYear: 2026,
  runtime: 100,
  genres: <String>['Drama'],
  director: '',
  cast: <String>[],
  rating: 8,
  mediaType: CatalogMediaType.movie,
  trailerUrl: '',
);

BackendMovieService _service(
  MockClient client, {
  _FakeAuthService? authService,
}) => BackendMovieService(
  config: const BackendConfig(baseUrl: 'http://backend.test'),
  authService: authService ?? _FakeAuthService(),
  client: client,
);

void main() {
  test('decodes daily batch metadata', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/me/recommendations/daily-suggestions');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'batchId': 'batch-1',
          'batchExpiresAt': '2026-08-22T00:00:00.000Z',
          'results': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{
            'swipeLimitEnabled': true,
            'swipeLimit': 20,
            'usedToday': 3,
            'remainingToday': 17,
            'resetAt': '2026-08-22T00:00:00.000Z',
          },
        }),
        200,
      );
    });

    final batch = await _service(
      client,
    ).getPersonalizedDailySuggestions(limit: 5);

    expect(batch.batchId, 'batch-1');
    expect(batch.swipeLimit, 20);
    expect(batch.usedToday, 3);
    expect(batch.remainingToday, 17);
    expect(batch.batchExpiresAt, DateTime.utc(2026, 8, 22));
  });

  test('sends recommendation context and decodes usage', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['recommendationBatchId'], 'batch-1');
      expect(body['source'], 'daily-suggestion');
      expect(body['position'], 2);
      return http.Response(
        jsonEncode(<String, dynamic>{
          'ok': true,
          'dailyUsage': <String, dynamic>{
            'usedToday': 4,
            'remainingToday': 16,
            'limit': 20,
            'resetAt': '2026-08-22T00:00:00.000Z',
          },
        }),
        200,
      );
    });

    final usage = await _service(client).likeMovie(
      _movie(),
      recommendationContext: const RecommendationActionContext(
        batchId: 'batch-1',
        position: 2,
      ),
    );

    expect(usage?.remainingToday, 16);
  });

  test('401 refresh retries with the same request body', () async {
    var calls = 0;
    final bodies = <String>[];
    final client = MockClient((request) async {
      calls += 1;
      bodies.add(request.body);
      if (calls == 1) return http.Response('{}', 401);
      expect(request.headers['authorization'], 'Bearer token-2');
      return http.Response('{"ok":true}', 200);
    });

    await _service(
      client,
      authService: _FakeAuthService(refreshedToken: 'token-2'),
    ).likeMovie(
      _movie(),
      recommendationContext: const RecommendationActionContext(
        batchId: 'batch-1',
        position: 0,
      ),
    );

    expect(calls, 2);
    expect(bodies[1], bodies[0]);
  });

  test('429 exposes authoritative daily usage', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(<String, dynamic>{
          'error': 'Daily swipe limit reached.',
          'dailyUsage': <String, dynamic>{
            'usedToday': 20,
            'remainingToday': 0,
            'limit': 20,
            'resetAt': '2026-08-22T00:00:00.000Z',
          },
        }),
        429,
      ),
    );

    await expectLater(
      _service(client).likeMovie(_movie()),
      throwsA(
        isA<MovieBackendRequestException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having(
              (error) => error.dailyUsage?.remainingToday,
              'remainingToday',
              0,
            ),
      ),
    );
  });

  test(
    'malformed successful mutation does not undo a committed action',
    () async {
      final client = MockClient(
        (_) async => http.Response('<html>ok</html>', 200),
      );

      final usage = await _service(client).likeMovie(_movie());

      expect(usage, isNull);
    },
  );
}
