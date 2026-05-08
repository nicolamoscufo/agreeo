import 'package:agreeo/shared/models/agreeo_models.dart';

abstract class MovieService {
  Future<List<Movie>> getCatalog();

  Future<List<Movie>> getDailySuggestions({
    required List<String> favoriteGenres,
    required List<String> favoriteMovieIds,
  });

  Future<List<Movie>> searchMovies(String query, MovieSearchFilters filters);

  Future<Movie?> getMovieDetails(String movieId);

  Future<List<Movie>> getTrendingMovies();

  Future<List<Movie>> getMoviesByGenre(String genre);

  Future<List<Movie>> getMoviesByProvider(String provider);

  Future<List<Movie>> getMockShortMovies();
}
