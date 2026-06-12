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

class _RemoteSocialService extends BackendSocialService {
  _RemoteSocialService()
    : super(config: const BackendConfig(baseUrl: 'http://localhost:3000'));

  Friend get _friend => Friend(
    id: 'friend-remote',
    name: 'Remote Friend',
    avatarUrl: '',
    watchedCount: 3,
    reviewsCount: 1,
    privacySettings: PrivacySettings.open(),
  );

  FriendRequest get _request => FriendRequest(
    id: 'request-remote',
    fromUser: _friend,
    toUserId: 'local-host',
    status: FriendRequestStatus.pending,
    createdAt: DateTime(2026),
  );

  @override
  Future<SocialBackendSnapshot> loadSnapshot() async {
    return SocialBackendSnapshot(
      friends: const <Friend>[],
      incomingRequests: <FriendRequest>[_request],
      movieNights: const <MovieNightEvent>[],
    );
  }

  @override
  Future<FriendSearchResponse> searchFriends(String query) async {
    return FriendSearchResponse(
      results: <Friend>[_friend],
      pendingIds: const <String>{},
      incomingRequestIdsByUserId: const <String, String>{
        'friend-remote': 'request-remote',
      },
    );
  }

  @override
  Future<SocialBackendSnapshot> acceptFriendRequest(String requestId) async {
    return SocialBackendSnapshot(
      friends: <Friend>[_friend],
      incomingRequests: const <FriendRequest>[],
      movieNights: const <MovieNightEvent>[],
    );
  }

  @override
  Future<SocialBackendSnapshot> removeFriend(String friendId) async {
    return const SocialBackendSnapshot(
      friends: <Friend>[],
      incomingRequests: <FriendRequest>[],
      movieNights: <MovieNightEvent>[],
    );
  }
}

class _AcceptFailingBackendSocialService extends _RemoteSocialService {
  _AcceptFailingBackendSocialService();

  @override
  Future<SocialBackendSnapshot> acceptFriendRequest(String requestId) async {
    throw StateError('accept failed');
  }
}

class _PendingRequestSocialService extends BackendSocialService {
  _PendingRequestSocialService()
    : super(config: const BackendConfig(baseUrl: 'http://localhost:3000'));

  String? cancelledUserId;

  @override
  Future<SocialBackendSnapshot> loadSnapshot() async {
    return const SocialBackendSnapshot(
      friends: <Friend>[],
      incomingRequests: <FriendRequest>[],
      movieNights: <MovieNightEvent>[],
    );
  }

  @override
  Future<FriendSearchResponse> searchFriends(String query) async {
    return FriendSearchResponse(
      results: <Friend>[
        Friend(
          id: 'friend-pending',
          name: 'Pending Friend',
          avatarUrl: '',
          watchedCount: 0,
          reviewsCount: 0,
          privacySettings: PrivacySettings.open(),
        ),
      ],
      pendingIds: const <String>{'friend-pending'},
      incomingRequestIdsByUserId: const <String, String>{},
    );
  }

  @override
  Future<SocialBackendSnapshot> cancelFriendRequest(String userId) async {
    cancelledUserId = userId;
    return const SocialBackendSnapshot(
      friends: <Friend>[],
      incomingRequests: <FriendRequest>[],
      movieNights: <MovieNightEvent>[],
    );
  }
}

class _CancelFailingSocialService extends _PendingRequestSocialService {
  @override
  Future<SocialBackendSnapshot> cancelFriendRequest(String userId) async {
    throw StateError('cancel failed');
  }
}

void main() {
  test(
    'controller does not seed local fallback when backend is offline',
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
      expect(seeded.friends, isEmpty);
      expect(seeded.incomingRequests, isEmpty);
      expect(seeded.movieNights, isEmpty);

      await expectLater(
        controller.createMovieNight(
          name: 'Fallback Night',
          dateTime: null,
          constraints: MovieNightConstraints.empty(),
          invitedFriendIds: const <String>[],
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('offline friend search does not use local mock users', () async {
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
      container.read(friendsMovieNightControllerProvider).searchResults,
      isEmpty,
    );
  });

  test('accepting friend request moves requester into friends', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer(
      overrides: <Override>[
        backendSocialServiceProvider.overrideWithValue(_RemoteSocialService()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      friendsMovieNightControllerProvider.notifier,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final request = container
        .read(friendsMovieNightControllerProvider)
        .incomingRequests
        .single;
    controller.acceptFriendRequest(request.id);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(friendsMovieNightControllerProvider);
    expect(state.incomingRequests, isEmpty);
    expect(
      state.friends.any((friend) => friend.id == request.fromUser.id),
      true,
    );
  });

  test('accept failure rolls back optimistic friend request state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer(
      overrides: <Override>[
        backendSocialServiceProvider.overrideWithValue(
          _AcceptFailingBackendSocialService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      friendsMovieNightControllerProvider.notifier,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    controller.acceptFriendRequest('request-remote');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(friendsMovieNightControllerProvider);
    expect(state.incomingRequests.single.id, 'request-remote');
    expect(state.friends, isEmpty);
    expect(state.incomingRequestIdFor('friend-remote'), 'request-remote');
  });

  test('remove friend clears local friend and search state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer(
      overrides: <Override>[
        backendSocialServiceProvider.overrideWithValue(_RemoteSocialService()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      friendsMovieNightControllerProvider.notifier,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final friendId = container
        .read(friendsMovieNightControllerProvider)
        .searchResults
        .first
        .id;
    controller.removeFriend(friendId);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(friendsMovieNightControllerProvider);
    expect(state.friends.any((friend) => friend.id == friendId), false);
    expect(state.searchResults.any((friend) => friend.id == friendId), false);
  });

  test('cancel friend request clears the pending flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = _PendingRequestSocialService();
    final container = ProviderContainer(
      overrides: <Override>[
        backendSocialServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      friendsMovieNightControllerProvider.notifier,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    controller.searchFriends('pending');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(friendsMovieNightControllerProvider).isPending('friend-pending'),
      isTrue,
    );

    controller.cancelFriendRequest('friend-pending');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(service.cancelledUserId, 'friend-pending');
    expect(
      container.read(friendsMovieNightControllerProvider).isPending('friend-pending'),
      isFalse,
    );
  });

  test('cancel failure restores the pending flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer(
      overrides: <Override>[
        backendSocialServiceProvider.overrideWithValue(
          _CancelFailingSocialService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      friendsMovieNightControllerProvider.notifier,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    controller.searchFriends('pending');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    controller.cancelFriendRequest('friend-pending');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(friendsMovieNightControllerProvider).isPending('friend-pending'),
      isTrue,
    );
  });
}
