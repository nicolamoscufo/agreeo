import 'package:agreeo/shared/models/agreeo_models.dart';

class UserMovieStateMutation {
  const UserMovieStateMutation({
    required this.movieId,
    required this.previousState,
    required this.nextState,
    required this.states,
    required this.undoStack,
    required this.message,
  });

  final String movieId;
  final UserMovieState previousState;
  final UserMovieState nextState;
  final Map<String, UserMovieState> states;
  final List<UndoEntry> undoStack;
  final String message;
}

abstract class UserMovieStateService {
  UserMovieStateMutation likeMovie(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  );

  UserMovieStateMutation dislikeMovie(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  );

  UserMovieStateMutation addToWatchlist(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  );

  UserMovieStateMutation removeFromWatchlist(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  );

  UserMovieStateMutation markAsWatched(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  );

  UserMovieStateMutation removeFromWatched(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  );

  UserMovieStateMutation clearPreference(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  );

  UserMovieStateMutation undoLastAction(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
  );

  UserMovieStateMutation rateMovie(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
    int rating,
  );

  UserMovieStateMutation reviewMovie(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
    String review,
  );

  UserMovieStateMutation deleteReview(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  );
}

class LocalUserMovieStateService implements UserMovieStateService {
  @override
  UserMovieStateMutation addToWatchlist(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Saved to Watchlist.',
      (state) => state.copyWith(
        preference: state.preference == MoviePreference.disliked
            ? MoviePreference.neutral
            : state.preference,
        inWatchlist: true,
        watched: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  UserMovieStateMutation clearPreference(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Preference cleared.',
      (state) => state.copyWith(
        preference: MoviePreference.neutral,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  UserMovieStateMutation deleteReview(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Review removed.',
      (state) => state.copyWith(clearReview: true, updatedAt: DateTime.now()),
    );
  }

  @override
  UserMovieStateMutation dislikeMovie(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Hidden from your picks.',
      (state) => state.copyWith(
        preference: MoviePreference.disliked,
        inWatchlist: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  UserMovieStateMutation likeMovie(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Liked for future picks.',
      (state) => state.copyWith(
        preference: MoviePreference.liked,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  UserMovieStateMutation markAsWatched(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Marked as watched.',
      (state) => state.copyWith(
        watched: true,
        inWatchlist: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  UserMovieStateMutation rateMovie(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
    int rating,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Rating updated.',
      (state) => state.copyWith(
        watched: true,
        inWatchlist: false,
        rating: rating,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  UserMovieStateMutation removeFromWatchlist(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Removed from Watchlist.',
      (state) => state.copyWith(inWatchlist: false, updatedAt: DateTime.now()),
    );
  }

  @override
  UserMovieStateMutation removeFromWatched(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Removed from watched.',
      (state) => state.copyWith(watched: false, updatedAt: DateTime.now()),
    );
  }

  @override
  UserMovieStateMutation reviewMovie(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
    String review,
  ) {
    return _mutate(
      currentStates,
      currentUndoStack,
      movieId,
      'Review saved.',
      (state) => state.copyWith(
        watched: true,
        inWatchlist: false,
        review: review.trim(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  UserMovieStateMutation undoLastAction(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
  ) {
    if (currentUndoStack.isEmpty) {
      return UserMovieStateMutation(
        movieId: '',
        previousState: UserMovieState.initial(''),
        nextState: UserMovieState.initial(''),
        states: currentStates,
        undoStack: currentUndoStack,
        message: 'Nothing to undo.',
      );
    }

    final updatedStates = Map<String, UserMovieState>.from(currentStates);
    final updatedUndoStack = List<UndoEntry>.from(currentUndoStack);
    final entry = updatedUndoStack.removeLast();
    _storeState(updatedStates, entry.previousState);

    return UserMovieStateMutation(
      movieId: entry.movieId,
      previousState: entry.nextState,
      nextState: entry.previousState,
      states: updatedStates,
      undoStack: updatedUndoStack,
      message: 'Action undone.',
    );
  }

  UserMovieStateMutation _mutate(
    Map<String, UserMovieState> currentStates,
    List<UndoEntry> currentUndoStack,
    String movieId,
    String message,
    UserMovieState Function(UserMovieState currentState) transform,
  ) {
    final previousState =
        currentStates[movieId] ?? UserMovieState.initial(movieId);
    final nextState = transform(previousState);
    final updatedStates = Map<String, UserMovieState>.from(currentStates);
    _storeState(updatedStates, nextState);

    final updatedUndoStack = List<UndoEntry>.from(currentUndoStack)
      ..add(
        UndoEntry(
          movieId: movieId,
          previousState: previousState,
          nextState: nextState,
          message: message,
        ),
      );

    return UserMovieStateMutation(
      movieId: movieId,
      previousState: previousState,
      nextState: nextState,
      states: updatedStates,
      undoStack: updatedUndoStack,
      message: message,
    );
  }

  void _storeState(Map<String, UserMovieState> target, UserMovieState state) {
    if (state.isUntouched) {
      target.remove(state.movieId);
      return;
    }
    target[state.movieId] = state;
  }
}
