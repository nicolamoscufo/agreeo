import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/user_movie_state_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = LocalUserMovieStateService();

  test('dislike removes watchlist and overrides like', () {
    final likedAndSaved = <String, UserMovieState>{
      'movie-1': UserMovieState.initial('movie-1').copyWith(
        preference: MoviePreference.liked,
        inWatchlist: true,
        updatedAt: DateTime(2026, 5, 8),
      ),
    };

    final result = service.dislikeMovie(likedAndSaved, const <UndoEntry>[], 'movie-1');
    final state = result.states['movie-1']!;

    expect(state.preference, MoviePreference.disliked);
    expect(state.inWatchlist, isFalse);
  });

  test('adding to watchlist clears hidden state and watched flag', () {
    final hiddenAndWatched = <String, UserMovieState>{
      'movie-2': UserMovieState.initial('movie-2').copyWith(
        preference: MoviePreference.disliked,
        watched: true,
        updatedAt: DateTime(2026, 5, 8),
      ),
    };

    final result = service.addToWatchlist(
      hiddenAndWatched,
      const <UndoEntry>[],
      'movie-2',
    );
    final state = result.states['movie-2']!;

    expect(state.preference, MoviePreference.neutral);
    expect(state.inWatchlist, isTrue);
    expect(state.watched, isFalse);
  });

  test('undo restores the previous state snapshot', () {
    final firstMutation = service.addToWatchlist(
      <String, UserMovieState>{},
      const <UndoEntry>[],
      'movie-3',
    );

    final watchedMutation = service.markAsWatched(
      firstMutation.states,
      firstMutation.undoStack,
      'movie-3',
    );
    expect(watchedMutation.states['movie-3']!.watched, isTrue);
    expect(watchedMutation.states['movie-3']!.inWatchlist, isFalse);

    final undone = service.undoLastAction(
      watchedMutation.states,
      watchedMutation.undoStack,
    );
    final state = undone.states['movie-3']!;

    expect(state.inWatchlist, isTrue);
    expect(state.watched, isFalse);
  });
}
