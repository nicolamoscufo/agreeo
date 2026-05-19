import 'dart:convert';

import 'package:agreeo/config/backend_config.dart';
import 'package:agreeo/services/auth_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:http/http.dart' as http;

class UserLibrary {
  const UserLibrary({
    required this.liked,
    required this.disliked,
    required this.watchlist,
  });

  final List<Movie> liked;
  final List<Movie> disliked;
  final List<Movie> watchlist;
}

class MovieDetails {
  const MovieDetails({
    required this.movie,
    required this.runtime,
    required this.trailerUrl,
    required this.trailers,
    required this.cast,
    required this.images,
  });

  final Movie movie;
  final int runtime;
  final String trailerUrl;
  final List<Map<String, dynamic>> trailers;
  final List<Map<String, dynamic>> cast;
  final Map<String, dynamic> images;
}

class BackendMovieService {
  BackendMovieService({
    BackendConfig? config,
    AuthService? authService,
    http.Client? client,
  }) : _config = config ?? BackendConfig.fromEnv(),
       _authService = authService ?? AuthService(config: config),
       _client = client ?? http.Client();

  final BackendConfig _config;
  final AuthService _authService;
  final http.Client _client;

  Future<List<Movie>> getPopularMovies() async {
    final response = await _client.get(
      Uri.parse('${_config.baseUrl}/movies/popular'),
    );
    _ensureSuccess(response);
    final body = _decodeMap(response.body);
    return _decodeMovieList(body['results']);
  }

  Future<List<Movie>> getRecommendations({int page = 1}) async {
    final uri = Uri.parse(
      '${_config.baseUrl}/movies/recommendations',
    ).replace(queryParameters: {'page': page.toString()});
    final response = await _client.get(uri);
    _ensureSuccess(response);
    final body = _decodeMap(response.body);
    return _decodeMovieList(body['results']);
  }

  Future<List<Movie>> getDailySuggestions({int page = 1}) async {
    final uri = Uri.parse(
      '${_config.baseUrl}/movies/daily-suggestions',
    ).replace(queryParameters: {'page': page.toString()});
    final response = await _client.get(uri);
    _ensureSuccess(response);
    final body = _decodeMap(response.body);
    return _decodeMovieList(body['results']);
  }

  Future<List<Movie>> getPersonalizedDailySuggestions({int? limit}) async {
    final queryParameters = <String, String>{};
    if (limit != null && limit > 0) {
      queryParameters['limit'] = limit.toString();
    }

    final path = Uri(
      path: '/me/recommendations/daily-suggestions',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
    final response = await _authorizedRequest('GET', path);
    final body = _decodeMap(response.body);
    return _decodeMovieList(body['results']);
  }

  Future<List<Movie>> searchMovies(
    String query, {
    MovieSearchFilters filters = const MovieSearchFilters(),
  }) async {
    final queryParameters = <String, String>{};
    final trimmedQuery = query.trim();

    if (trimmedQuery.isNotEmpty) {
      queryParameters['query'] = trimmedQuery;
    }
    if (filters.genre != null && filters.genre!.trim().isNotEmpty) {
      queryParameters['genre'] = filters.genre!.trim();
    }
    if (filters.maxRuntimeMinutes != null) {
      queryParameters['maxRuntimeMinutes'] = filters.maxRuntimeMinutes
          .toString();
    }
    if (filters.minReleaseYear != null) {
      queryParameters['minReleaseYear'] = filters.minReleaseYear.toString();
    }
    if (filters.minRating != null) {
      queryParameters['minRating'] = filters.minRating!.toStringAsFixed(1);
    }

    final response = await _client.get(
      Uri.parse(
        '${_config.baseUrl}/movies/search',
      ).replace(queryParameters: queryParameters),
    );
    _ensureSuccess(response);
    final body = _decodeMap(response.body);
    return _decodeMovieList(body['results']);
  }

  Future<MovieDetails> getMovieDetails(int tmdbId) async {
    final response = await _client.get(
      Uri.parse('${_config.baseUrl}/movies/$tmdbId'),
    );
    _ensureSuccess(response);
    final body = _decodeMap(response.body);
    final movieMap = _castMap(body['movie']);

    return MovieDetails(
      movie: _decodeMovie(movieMap),
      runtime: (movieMap['runtime'] as num?)?.toInt() ?? 0,
      trailerUrl: movieMap['trailerUrl']?.toString() ?? '',
      trailers: _decodeObjectList(movieMap['trailers']),
      cast: _decodeObjectList(movieMap['cast']),
      images: _castMap(movieMap['images']),
    );
  }

  Future<void> likeMovie(Movie movie) async {
    await _authorizedRequest(
      'POST',
      '/me/movies/${_resolveTmdbId(movie)}/like',
    );
  }

  Future<void> dislikeMovie(Movie movie) async {
    await _authorizedRequest(
      'POST',
      '/me/movies/${_resolveTmdbId(movie)}/dislike',
    );
  }

  Future<void> addToWatchlist(Movie movie) async {
    await _authorizedRequest(
      'POST',
      '/me/movies/${_resolveTmdbId(movie)}/watchlist',
    );
  }

  Future<void> markAsSeen(Movie movie) async {
    await _authorizedRequest(
      'POST',
      '/me/movies/${_resolveTmdbId(movie)}/seen',
    );
  }

  Future<void> removeFromWatchlist(int tmdbId) async {
    await _authorizedRequest('DELETE', '/me/movies/$tmdbId/watchlist');
  }

  Future<void> removeLike(int tmdbId) async {
    await _authorizedRequest('DELETE', '/me/movies/$tmdbId/like');
  }

  Future<void> removeDislike(int tmdbId) async {
    await _authorizedRequest('DELETE', '/me/movies/$tmdbId/dislike');
  }

  Future<void> removeSeen(int tmdbId) async {
    await _authorizedRequest('DELETE', '/me/movies/$tmdbId/seen');
  }

  Future<UserLibrary> getLibrary() async {
    final response = await _authorizedRequest('GET', '/me/library');
    final body = _decodeMap(response.body);

    return UserLibrary(
      liked: _decodeMovieList(body['liked']),
      disliked: _decodeMovieList(body['disliked']),
      watchlist: _decodeMovieList(body['watchlist']),
    );
  }

  Future<List<Movie>> getRecommendedForYou() async {
    final response = await _authorizedRequest(
      'GET',
      '/me/recommendations/for-you',
    );
    final body = _decodeMap(response.body);
    return _decodeMovieList(body['results']);
  }

  Future<Map<String, dynamic>> getRecommendationDebugStats() async {
    final response = await _authorizedRequest(
      'GET',
      '/me/recommendations/debug-stats',
    );
    final body = _decodeMap(response.body);
    return body;
  }

  Future<http.Response> _authorizedRequest(String method, String path) async {
    final token = await _authService.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token for authenticated movie request.');
    }

    final uri = Uri.parse('${_config.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    late final http.Response response;
    switch (method) {
      case 'POST':
        response = await _client.post(uri, headers: headers);
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
        break;
      case 'GET':
        response = await _client.get(uri, headers: headers);
        break;
      default:
        throw UnsupportedError('Unsupported method $method');
    }

    _ensureSuccess(response);

    return response;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Movie backend request failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  List<Movie> _decodeMovieList(Object? value) {
    if (value is! List) {
      return const <Movie>[];
    }

    return value
        .whereType<Map>()
        .map((entry) => _decodeMovie(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Movie _decodeMovie(Map<String, dynamic> json) {
    final tmdbId = (json['tmdbId'] as num?)?.toInt();
    final releaseDate = json['releaseDate']?.toString() ?? '';
    final year = DateTime.tryParse(releaseDate)?.year ?? 0;
    final genres = _decodeStringList(json['genres']);
    final rating =
        (json['voteAverage'] as num?)?.toDouble() ??
        (((_castMap(json['movieLens'])['avgRating'] as num?)?.toDouble() ?? 0) *
            2);
    final trailerUrl = json['trailerUrl']?.toString() ?? '';
    final castEntries = _decodeObjectList(json['cast']);
    final director = json['director']?.toString() ?? '';

    return Movie(
      id: tmdbId == null ? '' : 'tmdb-$tmdbId',
      tmdbId: tmdbId,
      title: json['title']?.toString() ?? '',
      originalTitle:
          json['originalTitle']?.toString() ?? json['title']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      posterUrl: json['posterUrl']?.toString() ?? '',
      backdropUrl: json['backdropUrl']?.toString() ?? '',
      releaseYear: year,
      runtime: (json['runtime'] as num?)?.toInt() ?? 0,
      genres: genres,
      director: director,
      cast: castEntries
          .map((entry) => entry['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
      rating: rating,
      mediaType: CatalogMediaType.movie,
      trailerUrl: trailerUrl,
    );
  }

  int _resolveTmdbId(Movie movie) {
    if (movie.tmdbId != null) {
      return movie.tmdbId!;
    }

    final raw = movie.id.startsWith('tmdb-') ? movie.id.substring(5) : movie.id;
    final tmdbId = int.tryParse(raw);
    if (tmdbId == null) {
      throw StateError('Movie does not contain a TMDB id: ${movie.id}');
    }

    return tmdbId;
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    return _castMap(decoded);
  }

  Map<String, dynamic> _castMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  List<String> _decodeStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return value.map((item) => item.toString()).toList(growable: false);
  }

  List<Map<String, dynamic>> _decodeObjectList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList(growable: false);
  }
}
