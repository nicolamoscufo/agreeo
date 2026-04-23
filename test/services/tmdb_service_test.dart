import 'dart:convert';

import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/services/tmdb_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('discoverCatalog hydrates TMDb responses into app movies', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/discover/movie')) {
        expect(request.url.queryParameters['with_watch_providers'], '8');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 603,
                'title': 'The Matrix',
                'overview': 'A hacker learns the truth.',
                'poster_path': '/matrix.jpg',
                'release_date': '1999-03-31',
                'vote_average': 8.7,
                'genre_ids': <int>[28, 878],
              },
            ],
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/movie/603')) {
        expect(
          request.url.queryParameters['append_to_response'],
          'videos,watch/providers',
        );
        return http.Response(
          jsonEncode(<String, dynamic>{
            'id': 603,
            'title': 'The Matrix',
            'overview': 'A hacker learns the truth.',
            'poster_path': '/matrix.jpg',
            'release_date': '1999-03-31',
            'runtime': 136,
            'vote_average': 8.7,
            'genres': <Map<String, dynamic>>[
              <String, dynamic>{'id': 28, 'name': 'Action'},
              <String, dynamic>{'id': 878, 'name': 'Sci-Fi'},
            ],
            'videos': <String, dynamic>{
              'results': <Map<String, dynamic>>[
                <String, dynamic>{
                  'site': 'YouTube',
                  'type': 'Trailer',
                  'key': 'vKQi3bBA1y8',
                },
              ],
            },
            'watch/providers': <String, dynamic>{
              'results': <String, dynamic>{
                'US': <String, dynamic>{
                  'flatrate': <Map<String, dynamic>>[
                    <String, dynamic>{'provider_name': 'Netflix'},
                  ],
                },
              },
            },
          }),
          200,
        );
      }

      return http.Response('Not found', 404);
    });

    final service = TmdbService(
      client: client,
      apiKey: 'test-key',
      baseUri: Uri.parse('https://api.themoviedb.org/3/'),
    );

    final movies = await service.discoverCatalog(
      mediaType: MediaType.movie,
      includeGenres: <String>['Action'],
      excludeGenres: const <String>[],
      streamingServices: <String>['Netflix'],
      limit: 1,
    );

    expect(movies, hasLength(1));
    final movie = movies.single;
    expect(movie.id, 'tmdb-603');
    expect(movie.title, 'The Matrix');
    expect(movie.posterUrl, startsWith('https://image.tmdb.org/t/p/w780'));
    expect(movie.runtimeMinutes, 136);
    expect(movie.streamingServices, contains('Netflix'));
    expect(movie.trailerUrl, contains('youtube.com/watch?v=vKQi3bBA1y8'));
  });
}
