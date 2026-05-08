import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/services/backend_service.dart';
import 'package:agreeo/services/tmdb_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeTmdbService extends TmdbService {
  _FakeTmdbService(this.catalog)
    : super(
        apiKey: 'test-key',
        client: MockClient((_) async => http.Response('{}', 200)),
      );

  final List<Movie> catalog;

  @override
  Future<List<Movie>> discoverCatalog({
    MediaType? mediaType,
    required List<String> includeGenres,
    required List<String> excludeGenres,
    int limit = 20,
  }) async {
    return catalog;
  }
}

Movie _movie({
  required String id,
  required String title,
  required List<String> genres,
  double score = 7.0,
}) {
  return Movie(
    id: id,
    title: title,
    overview: 'Overview for $title',
    posterUrl: 'https://picsum.photos/seed/$id/600/900',
    releaseYear: 2026,
    runtimeMinutes: 120,
    genres: genres,
    mediaType: MediaType.movie,
    trailerUrl: 'https://www.youtube.com/watch?v=$id',
    score: score,
  );
}

void main() {
  test('generateDailyQueue uses the TMDb catalog when available', () async {
    final backend = BackendService(
      tmdbService: _FakeTmdbService([
        _movie(
          id: 'tmdb-match',
          title: 'TMDb Match',
          genres: <String>['Drama'],
          score: 8.9,
        ),
      ]),
    );

    final queue = await backend.generateDailyQueue(
      session: AppSession(
        uid: 'user-1',
        displayName: 'User',
        email: 'user@example.com',
        isGuest: false,
        createdAt: DateTime(2026, 4, 11),
      ),
      preferences: UserPreferences.initial().copyWith(
        favoriteGenres: <String>['Drama'],
        onboardingComplete: true,
      ),
      feedback: const <MovieFeedbackRecord>[],
    );

    expect(queue, hasLength(1));
    expect(queue.single.title, 'TMDb Match');
  });
}
