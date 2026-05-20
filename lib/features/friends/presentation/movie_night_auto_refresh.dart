import 'dart:async';

import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

mixin MovieNightAutoRefresh<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Timer? _movieNightPollTimer;

  void startMovieNightPolling(
    String eventId, {
    Duration interval = const Duration(seconds: 4),
  }) {
    _movieNightPollTimer?.cancel();
    _refreshMovieNight(eventId);
    _movieNightPollTimer = Timer.periodic(
      interval,
      (_) => _refreshMovieNight(eventId),
    );
  }

  Future<void> _refreshMovieNight(String eventId) async {
    await ref
        .read(friendsMovieNightControllerProvider.notifier)
        .refreshMovieNight(eventId);
  }

  @override
  void dispose() {
    _movieNightPollTimer?.cancel();
    super.dispose();
  }
}
