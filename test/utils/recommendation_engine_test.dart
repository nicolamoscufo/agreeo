import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/utils/recommendation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

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
  const engine = RecommendationEngine();

  test('buildDailyQueue excludes seen and disliked titles', () {
    final preferences = UserPreferences.initial().copyWith(
      favoriteGenres: <String>['Drama'],
      onboardingComplete: true,
    );

    final catalog = <Movie>[
      _movie(
        id: 'match',
        title: 'Match',
        genres: <String>['Drama'],
        score: 8.0,
      ),
      _movie(
        id: 'seen',
        title: 'Seen',
        genres: <String>['Drama'],
        score: 10.0,
      ),
      _movie(
        id: 'disliked',
        title: 'Disliked',
        genres: <String>['Drama'],
        score: 9.0,
      ),
    ];

    final queue = engine.buildDailyQueue(
      catalog: catalog,
      preferences: preferences,
      feedback: <MovieFeedbackRecord>[
        MovieFeedbackRecord(
          userId: 'user-1',
          movieId: 'seen',
          action: FeedbackAction.seen,
          createdAt: DateTime(2026, 4, 10),
        ),
        MovieFeedbackRecord(
          userId: 'user-1',
          movieId: 'disliked',
          action: FeedbackAction.dislike,
          createdAt: DateTime(2026, 4, 10),
        ),
      ],
      today: DateTime(2026, 4, 11),
      limit: 5,
    );

    expect(queue, hasLength(1));
    expect(queue.single.id, 'match');
  });

  test(
    'buildShortlist prioritizes matching titles that fit the constraints',
    () {
      final shortlist = engine.buildShortlist(
        catalog: <Movie>[
          _movie(
            id: 'first',
            title: 'First',
            genres: <String>['Drama'],
            score: 7.0,
          ),
          _movie(
            id: 'second',
            title: 'Second',
            genres: <String>['Drama'],
            score: 9.0,
          ),
          _movie(
            id: 'excluded',
            title: 'Excluded',
            genres: <String>['Horror'],
            score: 10.0,
          ),
        ],
        feedback: <MovieFeedbackRecord>[
          MovieFeedbackRecord(
            userId: 'user-1',
            movieId: 'first',
            action: FeedbackAction.like,
            createdAt: DateTime(2026, 4, 10),
          ),
          MovieFeedbackRecord(
            userId: 'user-2',
            movieId: 'second',
            action: FeedbackAction.dislike,
            createdAt: DateTime(2026, 4, 10),
          ),
        ],
        votes: const <EventVote>[],
        memberIds: const <String>['user-1', 'user-2'],
        constraints: EventConstraints(
          groupId: 'group-1',
          format: MediaType.movie,
          includeGenres: <String>['Drama'],
          excludeGenres: <String>['Horror'],
          maxDurationMinutes: 140,
        ),
        today: DateTime(2026, 4, 11),
        limit: 6,
      );

      expect(shortlist.map((movie) => movie.id), isNot(contains('excluded')));
      expect(shortlist.first.id, 'first');
    },
  );
}
