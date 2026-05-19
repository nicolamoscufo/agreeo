import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/services/shortlist_service.dart';
import 'package:flutter_test/flutter_test.dart';

Movie _movie({
  required String id,
  required String title,
  List<String> genres = const <String>['Drama'],
  int runtime = 110,
  double rating = 7,
  int year = 2024,
}) {
  return Movie(
    id: id,
    tmdbId: null,
    title: title,
    originalTitle: title,
    overview: 'Overview',
    posterUrl: '',
    backdropUrl: '',
    releaseYear: year,
    runtime: runtime,
    genres: genres,
    director: '',
    cast: const <String>[],
    rating: rating,
    mediaType: CatalogMediaType.movie,
    trailerUrl: '',
  );
}

UserMovieState _movieState(
  String movieId, {
  MoviePreference preference = MoviePreference.neutral,
  bool inWatchlist = false,
  bool watched = false,
  int? rating,
}) {
  return UserMovieState.initial(movieId).copyWith(
    preference: preference,
    inWatchlist: inWatchlist,
    watched: watched,
    rating: rating,
    updatedAt: DateTime(2026, 5, 19),
  );
}

List<MovieNightParticipant> _participants([List<String>? ids]) {
  return (ids ?? const <String>['u1', 'u2'])
      .map(
        (id) => MovieNightParticipant(
          userId: id,
          name: id,
          avatarUrl: '',
          status: MovieNightParticipantStatus.joined,
          isHost: id == 'u1',
        ),
      )
      .toList(growable: false);
}

MovieNightConstraints _constraints({
  List<String> includedGenres = const <String>[],
  List<String> excludedGenres = const <String>[],
  int? maxDurationMinutes = 180,
  double? minimumRating,
}) {
  return MovieNightConstraints(
    includedGenres: includedGenres,
    excludedGenres: excludedGenres,
    maxDurationMinutes: maxDurationMinutes,
    minimumRating: minimumRating,
    language: null,
  );
}

ShortlistCandidate _candidate(Movie movie, double score) {
  return ShortlistCandidate(
    movie: movie,
    compatibilityScore: score,
    explanationTags: const <String>[],
    scoreBreakdown: ScoreBreakdown(
      watchlistSaves: 0,
      likes: 0,
      dislikes: 0,
      watched: 0,
      positiveRatings: 0,
      includedGenreMatches: 0,
      groupBonus: 0,
      groupPenalty: 0,
      total: score,
    ),
  );
}

void main() {
  const service = ShortlistService();

  test('movie in multiple watchlists ranks higher', () {
    final movies = <Movie>[
      _movie(id: 'saved', title: 'Saved'),
      _movie(id: 'plain', title: 'Plain', rating: 8),
    ];
    final shortlist = service.generateShortlist(
      eventConstraints: _constraints(),
      participants: _participants(),
      movies: movies,
      userMovieStates: <String, Map<String, UserMovieState>>{
        'u1': <String, UserMovieState>{
          'saved': _movieState('saved', inWatchlist: true),
        },
        'u2': <String, UserMovieState>{
          'saved': _movieState('saved', inWatchlist: true),
        },
      },
    );

    expect(shortlist.first.movie.id, 'saved');
  });

  test('movie liked by multiple users ranks higher', () {
    final shortlist = service.generateShortlist(
      eventConstraints: _constraints(),
      participants: _participants(),
      movies: <Movie>[
        _movie(id: 'liked', title: 'Liked'),
        _movie(id: 'other', title: 'Other', rating: 8),
      ],
      userMovieStates: <String, Map<String, UserMovieState>>{
        'u1': <String, UserMovieState>{
          'liked': _movieState('liked', preference: MoviePreference.liked),
        },
        'u2': <String, UserMovieState>{
          'liked': _movieState('liked', preference: MoviePreference.liked),
        },
      },
    );

    expect(shortlist.first.movie.id, 'liked');
  });

  test('movie disliked by half the group is strongly penalized', () {
    final shortlist = service.generateShortlist(
      eventConstraints: _constraints(),
      participants: _participants(),
      movies: <Movie>[
        _movie(id: 'disliked', title: 'Disliked', rating: 9),
        _movie(id: 'neutral', title: 'Neutral', rating: 7),
      ],
      userMovieStates: <String, Map<String, UserMovieState>>{
        'u1': <String, UserMovieState>{
          'disliked': _movieState(
            'disliked',
            preference: MoviePreference.disliked,
          ),
        },
      },
    );

    expect(shortlist.first.movie.id, 'neutral');
  });

  test('excluded genres remove movies', () {
    final shortlist = service.generateShortlist(
      eventConstraints: _constraints(excludedGenres: const <String>['Horror']),
      participants: _participants(),
      movies: <Movie>[
        _movie(id: 'horror', title: 'Horror', genres: const <String>['Horror']),
        _movie(id: 'drama', title: 'Drama'),
      ],
      userMovieStates: const <String, Map<String, UserMovieState>>{},
    );

    expect(
      shortlist.map((candidate) => candidate.movie.id),
      isNot(contains('horror')),
    );
  });

  test('maximum duration filters movies', () {
    final shortlist = service.generateShortlist(
      eventConstraints: _constraints(maxDurationMinutes: 120),
      participants: _participants(),
      movies: <Movie>[
        _movie(id: 'long', title: 'Long', runtime: 160),
        _movie(id: 'short', title: 'Short', runtime: 100),
      ],
      userMovieStates: const <String, Map<String, UserMovieState>>{},
    );

    expect(shortlist.single.movie.id, 'short');
  });

  test('already watched movies are penalized', () {
    final shortlist = service.generateShortlist(
      eventConstraints: _constraints(),
      participants: _participants(),
      movies: <Movie>[
        _movie(id: 'watched', title: 'Watched', rating: 8),
        _movie(id: 'fresh', title: 'Fresh', rating: 7),
      ],
      userMovieStates: <String, Map<String, UserMovieState>>{
        'u1': <String, UserMovieState>{
          'watched': _movieState('watched', watched: true),
        },
        'u2': <String, UserMovieState>{
          'watched': _movieState('watched', watched: true),
        },
      },
    );

    expect(shortlist.first.movie.id, 'fresh');
  });

  test('tie-breaking is deterministic by title after equal signals', () {
    final shortlist = service.generateShortlist(
      eventConstraints: _constraints(),
      participants: _participants(),
      movies: <Movie>[
        _movie(id: 'beta', title: 'Beta', rating: 7, year: 2020),
        _movie(id: 'alpha', title: 'Alpha', rating: 7, year: 2020),
      ],
      userMovieStates: const <String, Map<String, UserMovieState>>{},
    );

    expect(shortlist.map((candidate) => candidate.movie.title), <String>[
      'Alpha',
      'Beta',
    ]);
  });

  test('winner selection uses vote scores plus shortlist score', () {
    final movieA = _movie(id: 'a', title: 'A');
    final movieB = _movie(id: 'b', title: 'B');
    final winner = service.selectWinner(
      shortlist: <ShortlistCandidate>[
        _candidate(movieA, 10),
        _candidate(movieB, 8),
      ],
      votes: <MovieNightVote>[
        MovieNightVote(
          eventId: 'event',
          userId: 'u1',
          movieId: 'a',
          vote: MovieNightVoteValue.neutral,
          createdAt: DateTime(2026, 5, 19),
        ),
        MovieNightVote(
          eventId: 'event',
          userId: 'u2',
          movieId: 'a',
          vote: MovieNightVoteValue.neutral,
          createdAt: DateTime(2026, 5, 19),
        ),
        MovieNightVote(
          eventId: 'event',
          userId: 'u1',
          movieId: 'b',
          vote: MovieNightVoteValue.like,
          createdAt: DateTime(2026, 5, 19),
        ),
        MovieNightVote(
          eventId: 'event',
          userId: 'u2',
          movieId: 'b',
          vote: MovieNightVoteValue.like,
          createdAt: DateTime(2026, 5, 19),
        ),
      ],
    );

    expect(winner?.movie.id, 'b');
  });

  test(
    'voting completes when all joined participants voted for all candidates',
    () {
      final candidateA = _candidate(_movie(id: 'a', title: 'A'), 1);
      final candidateB = _candidate(_movie(id: 'b', title: 'B'), 1);
      final event = MovieNightEvent(
        id: 'event',
        name: 'Night',
        hostUserId: 'u1',
        dateTime: null,
        constraints: _constraints(),
        participants: _participants(),
        inviteLink: 'agreeo://invite/event',
        status: MovieNightStatus.voting,
        shortlist: <ShortlistCandidate>[candidateA, candidateB],
        winnerMovieId: null,
        votes: <MovieNightVote>[
          for (final movieId in const <String>['a', 'b'])
            for (final userId in const <String>['u1', 'u2'])
              MovieNightVote(
                eventId: 'event',
                userId: userId,
                movieId: movieId,
                vote: MovieNightVoteValue.neutral,
                createdAt: DateTime(2026, 5, 19),
              ),
        ],
        createdAt: DateTime(2026, 5, 19),
        updatedAt: DateTime(2026, 5, 19),
      );

      expect(service.hasEveryoneVoted(event), isTrue);
      expect(
        service.hasEveryoneVoted(
          event.copyWith(votes: event.votes.take(3).toList(growable: false)),
        ),
        isFalse,
      );
    },
  );
}
