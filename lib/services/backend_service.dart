import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/utils/recommendation_engine.dart';
import 'package:agreeo/utils/sample_catalog.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agreeo/services/tmdb_service.dart';

class BackendService {
  BackendService({
    RecommendationEngine? recommendationEngine,
    TmdbService? tmdbService,
  }) : _recommendationEngine =
           recommendationEngine ?? const RecommendationEngine(),
       _tmdbService = tmdbService ?? TmdbService();

  final RecommendationEngine _recommendationEngine;
  final TmdbService _tmdbService;

  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  Future<List<Movie>> generateDailyQueue({
    required AppSession session,
    required UserPreferences preferences,
    required Iterable<MovieFeedbackRecord> feedback,
  }) async {
    if (isFirebaseReady) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'generateDailyQueue',
        );
        final response = await callable.call(<String, dynamic>{
          'uid': session.uid,
          'genres': preferences.favoriteGenres,
          'services': preferences.streamingServices,
        });
        final rawMovies = response.data is Map ? response.data['movies'] : null;
        if (rawMovies is List) {
          return rawMovies
              .whereType<Map>()
              .map((entry) => Movie.fromJson(entry.cast<String, dynamic>()))
              .toList(growable: false);
        }
      } catch (_) {
        // Fall through to the local recommendation engine.
      }
    }

    final remoteCatalog = await _tmdbService.discoverCatalog(
      mediaType: null,
      includeGenres: preferences.favoriteGenres,
      excludeGenres: const <String>[],
      streamingServices: preferences.streamingServices,
      limit: 20,
    );
    final catalog = remoteCatalog.isNotEmpty ? remoteCatalog : demoMovieCatalog;

    return _recommendationEngine.buildDailyQueue(
      catalog: catalog,
      preferences: preferences,
      feedback: feedback,
      limit: 7,
    );
  }

  Future<List<Movie>> generateShortlist({
    required AppSession session,
    required MovieEvent event,
    required List<MovieFeedbackRecord> feedback,
    required List<EventVote> votes,
    required MovieGroup group,
  }) async {
    if (isFirebaseReady) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'generateShortlist',
        );
        final response = await callable.call(<String, dynamic>{
          'uid': session.uid,
          'eventId': event.id,
          'groupId': group.id,
          'format': event.constraints.format.name,
          'includeGenres': event.constraints.includeGenres,
          'excludeGenres': event.constraints.excludeGenres,
          'maxDurationMinutes': event.constraints.maxDurationMinutes,
        });
        final rawMovies = response.data is Map ? response.data['movies'] : null;
        if (rawMovies is List) {
          return rawMovies
              .whereType<Map>()
              .map((entry) => Movie.fromJson(entry.cast<String, dynamic>()))
              .toList(growable: false);
        }
      } catch (_) {
        // Fall back to local shortlist generation.
      }
    }

    final sharedServices = _sharedServices(
      group.memberServices.values.toList(),
    );
    final remoteCatalog = await _tmdbService.discoverCatalog(
      mediaType: event.constraints.format,
      includeGenres: event.constraints.includeGenres,
      excludeGenres: event.constraints.excludeGenres,
      streamingServices: sharedServices,
      limit: 20,
    );
    final catalog = remoteCatalog.isNotEmpty ? remoteCatalog : demoMovieCatalog;

    return _recommendationEngine.buildShortlist(
      catalog: catalog,
      feedback: feedback,
      votes: votes,
      memberIds: group.memberIds,
      memberServices: group.memberServices,
      constraints: event.constraints,
      limit: 6,
    );
  }

  List<String> _sharedServices(List<List<String>> servicesByMember) {
    if (servicesByMember.isEmpty) {
      return const <String>[];
    }

    final nonEmpty = servicesByMember
        .where((services) => services.isNotEmpty)
        .toList(growable: false);
    if (nonEmpty.isEmpty) {
      return const <String>[];
    }

    final shared = nonEmpty.first.toSet();
    for (final services in nonEmpty.skip(1)) {
      shared.retainAll(services);
    }

    if (shared.isNotEmpty) {
      return shared.toList(growable: false);
    }

    return nonEmpty
        .expand((services) => services)
        .toSet()
        .toList(growable: false);
  }

  Future<void> persistPreferences(
    String uid,
    UserPreferences preferences,
  ) async {
    if (!isFirebaseReady) {
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      <String, dynamic>{'preferences': preferences.toJson()},
      SetOptions(merge: true),
    );
  }

  Future<void> persistFeedback(String uid, MovieFeedbackRecord feedback) async {
    if (!isFirebaseReady) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('feedback')
        .doc(feedback.movieId)
        .set(feedback.toJson());
  }

  Future<void> persistDailyQueue(String uid, List<Movie> queue) async {
    if (!isFirebaseReady) {
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      <String, dynamic>{
        'dailyQueue': queue.map((movie) => movie.toJson()).toList(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> persistGroup(MovieGroup group) async {
    if (!isFirebaseReady) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .set(group.toJson());
  }

  Future<void> persistEvent(MovieEvent event) async {
    if (!isFirebaseReady) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('events')
        .doc(event.id)
        .set(event.toJson());
  }

  Future<void> persistVote(EventVote vote) async {
    if (!isFirebaseReady) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('events')
        .doc(vote.eventId)
        .collection('votes')
        .doc(vote.id)
        .set(vote.toJson());
  }
}
