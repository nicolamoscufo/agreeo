import 'package:agreeo/shared/mock_data/mock_movies.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/movie_service.dart';

class MockMovieService implements MovieService {
  @override
  Future<List<Movie>> getCatalog() async {
    return List<Movie>.from(mockMovieCatalog, growable: false);
  }

  @override
  Future<List<Movie>> getDailySuggestions({
    required List<String> favoriteGenres,
    required List<String> favoriteMovieIds,
  }) async {
    final favoriteMovieGenres = mockMovieCatalog
        .where((movie) => favoriteMovieIds.contains(movie.id))
        .expand((movie) => movie.genres)
        .toSet();
    final affinityGenres = <String>{...favoriteGenres, ...favoriteMovieGenres};

    final ranked = List<Movie>.from(mockMovieCatalog)
      ..sort((left, right) {
        final leftAffinity = left.genres
            .where((genre) => affinityGenres.contains(genre))
            .length;
        final rightAffinity = right.genres
            .where((genre) => affinityGenres.contains(genre))
            .length;
        if (leftAffinity != rightAffinity) {
          return rightAffinity.compareTo(leftAffinity);
        }
        return right.rating.compareTo(left.rating);
      });

    return ranked.take(12).toList(growable: false);
  }

  @override
  Future<Movie?> getMovieDetails(String movieId) async {
    for (final movie in mockMovieCatalog) {
      if (movie.id == movieId) {
        return movie;
      }
    }
    return null;
  }

  @override
  Future<List<Movie>> getTrendingMovies() async {
    final ranked = List<Movie>.from(mockMovieCatalog)
      ..sort((left, right) {
        final yearCompare = right.releaseYear.compareTo(left.releaseYear);
        if (yearCompare != 0) {
          return yearCompare;
        }
        return right.rating.compareTo(left.rating);
      });
    return ranked.take(10).toList(growable: false);
  }

  @override
  Future<List<Movie>> getMoviesByGenre(String genre) async {
    return mockMovieCatalog
        .where((movie) => movie.genres.contains(genre))
        .toList(growable: false);
  }

  @override
  Future<List<Movie>> getMockShortMovies() async {
    final shortMovies = mockMovieCatalog
        .where((movie) => movie.runtime <= 110)
        .toList(growable: false);
    return shortMovies;
  }

  @override
  Future<List<Movie>> searchMovies(
    String query,
    MovieSearchFilters filters,
  ) async {
    final normalizedQuery = query.trim().toLowerCase();
    return mockMovieCatalog.where((movie) {
      final matchesQuery = normalizedQuery.isEmpty ||
          movie.title.toLowerCase().contains(normalizedQuery) ||
          movie.originalTitle.toLowerCase().contains(normalizedQuery) ||
          movie.genres.any(
            (genre) => genre.toLowerCase().contains(normalizedQuery),
          );
      return matchesQuery && filters.matches(movie);
    }).toList(growable: false);
  }
}
