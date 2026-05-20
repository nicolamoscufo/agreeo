import 'package:agreeo/config/backend_config.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/services/backend_social_service.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineBackendSocialService extends BackendSocialService {
  _OfflineBackendSocialService()
    : super(config: const BackendConfig(baseUrl: 'http://localhost:3000'));

  @override
  Future<SocialBackendSnapshot> loadSnapshot() async {
    throw StateError('offline');
  }
}

void main() {
  test(
    'controller keeps local movie-night fallback when backend is offline',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer(
        overrides: <Override>[
          backendSocialServiceProvider.overrideWithValue(
            _OfflineBackendSocialService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        friendsMovieNightControllerProvider.notifier,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final seeded = container.read(friendsMovieNightControllerProvider);
      expect(seeded.friends, isNotEmpty);

      final event = await controller.createMovieNight(
        name: 'Fallback Night',
        dateTime: null,
        constraints: MovieNightConstraints.empty(),
        invitedFriendIds: <String>[seeded.friends.first.id],
      );

      expect(event.id, isNotEmpty);
      expect(event.shortlist, isNotEmpty);
      expect(
        container.read(friendsMovieNightControllerProvider).eventById(event.id),
        isNotNull,
      );
    },
  );

  test(
    'local friend search handles accents, punctuation, and token order',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer(
        overrides: <Override>[
          backendSocialServiceProvider.overrideWithValue(
            _OfflineBackendSocialService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        friendsMovieNightControllerProvider.notifier,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      controller.searchFriends('mor  giu');
      expect(
        container
            .read(friendsMovieNightControllerProvider)
            .searchResults
            .single
            .name,
        'Giulia Moretti',
      );

      controller.searchFriends('nina!! ah');
      expect(
        container
            .read(friendsMovieNightControllerProvider)
            .searchResults
            .single
            .name,
        'Nina Ahmed',
      );

      controller.searchFriends('léo mar');
      expect(
        container
            .read(friendsMovieNightControllerProvider)
            .searchResults
            .single
            .name,
        'Leo Martin',
      );
    },
  );
}
