import 'dart:convert';

import 'package:agreeo/models/app_models.dart';
import 'package:http/http.dart' as http;

class TmdbService {
  TmdbService({
    http.Client? client,
    String? apiKey,
    Uri? baseUri,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _apiKey =
            apiKey ??
            const String.fromEnvironment('TMDB_API_KEY', defaultValue: ''),
        _baseUri = baseUri ?? Uri.parse('https://api.themoviedb.org/3/');

  final http.Client _client;
  final bool _ownsClient;
  final String _apiKey;
  final Uri _baseUri;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<List<Movie>> discoverCatalog({
    MediaType? mediaType,
    required List<String> includeGenres,
    required List<String> excludeGenres,
    int limit = 20,
  }) async {
    if (!isConfigured || limit <= 0) {
      return const <Movie>[];
    }

    final targetTypes = mediaType == null
        ? MediaType.values
        : <MediaType>[mediaType];
    final discovered = <Movie>[];
    final seenIds = <String>{};

    for (final type in targetTypes) {
      final entries = await _discoverType(
        mediaType: type,
        includeGenres: includeGenres,
        excludeGenres: excludeGenres,
        limit: limit - discovered.length,
      );
      for (final movie in entries) {
        if (seenIds.add(movie.id)) {
          discovered.add(movie);
        }
        if (discovered.length >= limit) {
          return discovered.toList(growable: false);
        }
      }
    }

    return discovered.toList(growable: false);
  }

  Future<List<Movie>> _discoverType({
    required MediaType mediaType,
    required List<String> includeGenres,
    required List<String> excludeGenres,
    required int limit,
  }) async {
    if (limit <= 0) {
      return const <Movie>[];
    }

    final response = await _client.get(
      _buildDiscoverUri(
        mediaType: mediaType,
        includeGenres: includeGenres,
        excludeGenres: excludeGenres,
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <Movie>[];
    }

    final decoded = jsonDecode(response.body);
    final results = _asMap(decoded)?['results'];
    if (results is! List) {
      return const <Movie>[];
    }

    final movies = <Movie>[];
    for (final rawResult in results.whereType<Map>().take(limit * 2)) {
      final result = rawResult.cast<String, dynamic>();
      final movie = await _hydrateMovie(
        mediaType: mediaType,
        result: result,
      );
      if (movie != null) {
        movies.add(movie);
      }
      if (movies.length >= limit) {
        break;
      }
    }

    return movies.toList(growable: false);
  }

  Future<Movie?> _hydrateMovie({
    required MediaType mediaType,
    required Map<String, dynamic> result,
  }) async {
    final tmdbId = result['id']?.toString();
    if (tmdbId == null || tmdbId.isEmpty) {
      return null;
    }

    final detailJson = await _fetchDetails(mediaType, tmdbId) ?? result;
    final title = _titleFor(detailJson);
    final releaseYear = _releaseYearFor(detailJson);
    final runtimeMinutes = _runtimeMinutesFor(detailJson, mediaType);
    final genres = _genresFor(detailJson);
    final trailerUrl = _trailerUrlFor(detailJson, title);

    return Movie(
      id: 'tmdb-$tmdbId',
      title: title,
      overview: _overviewFor(detailJson),
      posterUrl: _posterUrlFor(detailJson, title),
      releaseYear: releaseYear,
      runtimeMinutes: runtimeMinutes,
      genres: genres,
      mediaType: mediaType,
      trailerUrl: trailerUrl,
      score: _voteScoreFor(detailJson),
    );
  }

  Future<Map<String, dynamic>?> _fetchDetails(
    MediaType mediaType,
    String tmdbId,
  ) async {
    final response = await _client.get(
      _buildDetailsUri(mediaType: mediaType, tmdbId: tmdbId),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    return _asMap(decoded);
  }

  Uri _buildDiscoverUri({
    required MediaType mediaType,
    required List<String> includeGenres,
    required List<String> excludeGenres,
  }) {
    final params = <String, String>{
      'api_key': _apiKey,
      'language': 'en-US',
      'sort_by': 'popularity.desc',
      'include_adult': 'false',
      'page': '1',
    };

    final includeGenreIds = _genreIds(includeGenres);
    if (includeGenreIds.isNotEmpty) {
      params['with_genres'] = includeGenreIds.join(',');
    }

    final excludeGenreIds = _genreIds(excludeGenres);
    if (excludeGenreIds.isNotEmpty) {
      params['without_genres'] = excludeGenreIds.join(',');
    }

    final path = mediaType == MediaType.movie
        ? 'discover/movie'
        : 'discover/tv';
    return _buildUri(path, params);
  }

  Uri _buildDetailsUri({required MediaType mediaType, required String tmdbId}) {
    final path = mediaType == MediaType.movie ? 'movie/$tmdbId' : 'tv/$tmdbId';
    return _buildUri(path, <String, String>{
      'api_key': _apiKey,
      'language': 'en-US',
      'append_to_response': 'videos',
    });
  }

  Uri _buildUri(String path, Map<String, String> queryParameters) {
    return _baseUri.resolve(path).replace(queryParameters: queryParameters);
  }

  String _titleFor(Map<String, dynamic> json) {
    final title = json['title']?.toString();
    if (title != null && title.trim().isNotEmpty) {
      return title;
    }

    final name = json['name']?.toString();
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }

    return 'Untitled';
  }

  String _overviewFor(Map<String, dynamic> json) {
    final overview = json['overview']?.toString();
    return overview == null || overview.isEmpty
        ? 'No overview available.'
        : overview.trim();
  }

  String _posterUrlFor(Map<String, dynamic> json, String title) {
    final posterPath = json['poster_path']?.toString();
    if (posterPath != null && posterPath.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w780$posterPath';
    }

    return 'https://picsum.photos/seed/${Uri.encodeComponent(title)}/600/900';
  }

  int _releaseYearFor(Map<String, dynamic> json) {
    final releaseDate = _releaseDateFor(json);
    if (releaseDate == null || releaseDate.isEmpty) {
      return DateTime.now().year;
    }

    return DateTime.tryParse(releaseDate)?.year ?? DateTime.now().year;
  }

  int _runtimeMinutesFor(Map<String, dynamic> json, MediaType mediaType) {
    final runtime = json['runtime'];
    if (runtime is num && runtime.toInt() > 0) {
      return runtime.toInt();
    }

    final episodeRuntime = json['episode_run_time'];
    if (episodeRuntime is List) {
      for (final value in episodeRuntime) {
        if (value is num && value.toInt() > 0) {
          return value.toInt();
        }
      }
    }

    return mediaType == MediaType.series ? 45 : 120;
  }

  List<String> _genresFor(Map<String, dynamic> json) {
    final rawGenres = json['genres'];
    if (rawGenres is List) {
      final genres = rawGenres
          .whereType<Map>()
          .map((entry) => entry['name']?.toString().trim())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (genres.isNotEmpty) {
        return genres;
      }
    }

    final rawGenreIds = json['genre_ids'];
    if (rawGenreIds is List) {
      final genres = rawGenreIds
          .map((value) => _genreNamesById[value is num ? value.toInt() : -1])
          .whereType<String>()
          .toList(growable: false);
      if (genres.isNotEmpty) {
        return genres;
      }
    }

    return const <String>[];
  }

  String _trailerUrlFor(Map<String, dynamic> json, String title) {
    final videosObject = _asMap(json['videos']);
    final results = videosObject?['results'];
    if (results is List) {
      for (final rawVideo in results.whereType<Map>()) {
        final video = rawVideo.cast<String, dynamic>();
        final site = video['site']?.toString();
        final type = video['type']?.toString();
        final key = video['key']?.toString();
        if (site == 'YouTube' &&
            type == 'Trailer' &&
            key != null &&
            key.isNotEmpty) {
          return 'https://www.youtube.com/watch?v=$key';
        }
      }
    }

    return 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$title trailer')}';
  }

  double _voteScoreFor(Map<String, dynamic> json) {
    final score = json['vote_average'];
    if (score is num) {
      return score.toDouble();
    }
    return 0;
  }

  List<int> _genreIds(List<String> genres) {
    return genres
        .map((genre) => _genreIdsByName[genre.trim().toLowerCase()])
        .whereType<int>()
        .toSet()
        .toList(growable: false);
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  static const Map<String, int> _genreIdsByName = <String, int>{
    'action': 28,
    'adventure': 12,
    'animation': 16,
    'comedy': 35,
    'crime': 80,
    'documentary': 99,
    'drama': 18,
    'family': 10751,
    'fantasy': 14,
    'history': 36,
    'horror': 27,
    'music': 10402,
    'mystery': 9648,
    'romance': 10749,
    'science fiction': 878,
    'sci-fi': 878,
    'tv movie': 10770,
    'thriller': 53,
    'war': 10752,
    'western': 37,
    'slice of life': 18,
  };

  static const Map<int, String> _genreNamesById = <int, String>{
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Sci-Fi',
    10770: 'TV Movie',
    53: 'Thriller',
    52: 'War',
    37: 'Western',
  };

  String? _releaseDateFor(Map<String, dynamic> json) {
    final releaseDate = json['release_date']?.toString();
    if (releaseDate != null && releaseDate.trim().isNotEmpty) {
      return releaseDate.trim();
    }

    final firstAirDate = json['first_air_date']?.toString();
    if (firstAirDate != null && firstAirDate.trim().isNotEmpty) {
      return firstAirDate.trim();
    }

    return null;
  }
}
