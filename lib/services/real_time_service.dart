import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:agreeo/config/backend_config.dart';
import 'package:agreeo/services/auth_service.dart';
import 'package:agreeo/services/notification_service.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/providers/notifications_provider.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';

class RealTimeService {
  RealTimeService(this._ref);

  final Ref _ref;
  final AuthService _authService = AuthService();
  io.Socket? _socket;
  String? _currentUserId;
  bool _retriedWithRefreshedToken = false;

  void connect(String userId) {
    if (_socket != null && _currentUserId == userId) {
      return;
    }

    if (_socket != null) {
      disconnect();
    }

    _currentUserId = userId;
    _retriedWithRefreshedToken = false;
    _ref.read(realTimeConnectionProvider.notifier).state = false;
    _openSocket(userId);
  }

  Future<void> _openSocket(String userId, {String? token}) async {
    final authToken = token ?? await _authService.readToken();
    if (authToken == null || authToken.isEmpty) {
      debugPrint(
        '[RealTimeService] No access token available, skipping connection',
      );
      return;
    }

    // The target user changed (or we disconnected) while reading the token.
    if (_currentUserId != userId) {
      return;
    }

    final baseUrl = BackendConfig.fromEnv().baseUrl;

    debugPrint('[RealTimeService] Connecting to Socket.io at $baseUrl');

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': authToken})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[RealTimeService] Connected as user: $userId');
      _retriedWithRefreshedToken = false;
      _ref.read(realTimeConnectionProvider.notifier).state = true;
    });

    _socket!.onDisconnect((_) {
      debugPrint('[RealTimeService] Disconnected');
      _ref.read(realTimeConnectionProvider.notifier).state = false;
    });

    _socket!.onConnectError((data) {
      debugPrint('[RealTimeService] Connection error: $data');
      _ref.read(realTimeConnectionProvider.notifier).state = false;
      _retryWithRefreshedToken(userId);
    });

    // Listen to friend request events
    _socket!.on('friend_request_received', (data) {
      debugPrint('[RealTimeService] friend_request_received: $data');
      _handleFriendRequestReceived(data);
    });

    _socket!.on('friend_request_accepted', (data) {
      debugPrint('[RealTimeService] friend_request_accepted: $data');
      _handleFriendRequestAccepted(data);
    });

    _socket!.on('friend_request_declined', (data) {
      debugPrint('[RealTimeService] friend_request_declined: $data');
      _handleFriendRequestDeclined(data);
    });

    _socket!.on('friend_request_cancelled', (data) {
      debugPrint('[RealTimeService] friend_request_cancelled: $data');
      // The sender withdrew their request: drop it from incoming lists.
      _refreshSocial();
    });

    // Listen to movie night events
    _socket!.on('movie_night_invite', (data) {
      debugPrint('[RealTimeService] movie_night_invite: $data');
      _handleMovieNightInvite(data);
    });

    _socket!.on('movie_night_voting_started', (data) {
      debugPrint('[RealTimeService] movie_night_voting_started: $data');
      _handleMovieNightVotingStarted(data);
    });

    _socket!.on('movie_night_completed', (data) {
      debugPrint('[RealTimeService] movie_night_completed: $data');
      _handleMovieNightCompleted(data);
    });

    _socket!.on('movie_night_updated', (data) {
      debugPrint('[RealTimeService] movie_night_updated: $data');
      _handleMovieNightUpdated(data);
    });

    _socket!.on('movie_night_tie_breaker', (data) {
      debugPrint('[RealTimeService] movie_night_tie_breaker: $data');
      _handleMovieNightUpdated(data);
    });

    _socket!.on('movie_state_changed', (data) {
      debugPrint('[RealTimeService] movie_state_changed: $data');
      _handleMovieStateChanged(data);
    });

    _socket!.connect();
  }

  void disconnect() {
    if (_socket != null) {
      debugPrint('[RealTimeService] Disconnecting socket');
      _socket!.disconnect();
      _socket!.destroy();
      _socket = null;
    }
    _currentUserId = null;
    _ref.read(realTimeConnectionProvider.notifier).state = false;
  }

  /// Retries the connection once with a freshly refreshed access token, to
  /// recover from handshakes rejected because the stored token expired.
  Future<void> _retryWithRefreshedToken(String userId) async {
    if (_retriedWithRefreshedToken || _currentUserId != userId) {
      return;
    }
    _retriedWithRefreshedToken = true;

    final refreshedToken = await _authService.refreshAccessToken();
    if (refreshedToken == null ||
        refreshedToken.isEmpty ||
        _currentUserId != userId) {
      return;
    }

    debugPrint('[RealTimeService] Retrying connection with refreshed token');
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
    await _openSocket(userId, token: refreshedToken);
  }

  void _handleFriendRequestReceived(dynamic data) {
    String fromName = 'Someone';
    try {
      if (data is Map && data['fromUser'] is Map) {
        fromName = data['fromUser']['name'] ?? 'Someone';
      }
    } catch (_) {}

    NotificationService.instance.showGenericNotification(
      id: 2001,
      title: 'New Friend Request',
      body: '$fromName sent you a friend request.',
    );
    _refreshAll();
  }

  void _handleFriendRequestAccepted(dynamic data) {
    String friendName = 'Someone';
    try {
      if (data is Map) {
        friendName = data['friendName'] ?? 'Someone';
      }
    } catch (_) {}

    NotificationService.instance.showGenericNotification(
      id: 2002,
      title: 'Friend Request Accepted',
      body: '$friendName accepted your friend request.',
    );
    _refreshAll();
  }

  void _handleFriendRequestDeclined(dynamic data) {
    _refreshSocial();
  }

  /// Notification toggles from Settings: gate the system banners (the in-app
  /// notifications list still records everything for history).
  bool _notificationEnabled(bool Function(ProfilePreferences prefs) select) {
    try {
      return select(_ref.read(agreeoAppControllerProvider).profilePreferences);
    } catch (_) {
      return true;
    }
  }

  void _handleMovieNightInvite(dynamic data) {
    String hostName = 'Someone';
    String eventName = 'Movie Night';
    try {
      if (data is Map) {
        hostName = data['hostName'] ?? 'Someone';
        if (data['event'] is Map) {
          eventName = data['event']['name'] ?? 'Movie Night';
        }
      }
    } catch (_) {}

    if (_notificationEnabled((prefs) => prefs.movieNightInvites)) {
      NotificationService.instance.showGenericNotification(
        id: 3001,
        title: 'Movie Night Invite',
        body: '$hostName invited you to "$eventName".',
      );
    }
    _refreshAll();
  }

  void _handleMovieNightVotingStarted(dynamic data) {
    String eventName = 'Movie Night';
    String? eventId;
    MovieNightEvent? decodedEvent;
    try {
      if (data is Map && data['event'] is Map) {
        final eventMap = Map<String, dynamic>.from(data['event'] as Map);
        decodedEvent = _ref
            .read(backendSocialServiceProvider)
            .decodeMovieNightEvent(eventMap);
        eventName = decodedEvent.name;
        eventId = decodedEvent.id;
      }
    } catch (_) {}

    if (_notificationEnabled((prefs) => prefs.votingStarted)) {
      NotificationService.instance.showGenericNotification(
        id: 3002,
        title: 'Voting Started',
        body: 'Voting has started for "$eventName"!',
      );
    }
    if (decodedEvent != null) {
      _ref
          .read(friendsMovieNightControllerProvider.notifier)
          .handleSocketMovieNightUpdated(decodedEvent);
    } else if (eventId != null) {
      _ref
          .read(friendsMovieNightControllerProvider.notifier)
          .refreshMovieNight(eventId);
    } else {
      _refreshAll();
    }
  }

  void _handleMovieNightCompleted(dynamic data) {
    String eventName = 'Movie Night';
    String winnerTitle = '';
    String? eventId;
    MovieNightEvent? decodedEvent;
    try {
      if (data is Map) {
        winnerTitle = data['winnerTitle'] ?? '';
        if (data['event'] is Map) {
          final eventMap = Map<String, dynamic>.from(data['event'] as Map);
          decodedEvent = _ref
              .read(backendSocialServiceProvider)
              .decodeMovieNightEvent(eventMap);
          eventName = decodedEvent.name;
          eventId = decodedEvent.id;
        }
      }
    } catch (_) {}

    if (_notificationEnabled((prefs) => prefs.finalDecisionReached)) {
      NotificationService.instance.showGenericNotification(
        id: 3003,
        title: 'Movie Night Completed',
        body: 'Decision reached for "$eventName"! Winner: $winnerTitle.',
      );
    }
    if (decodedEvent != null) {
      _ref
          .read(friendsMovieNightControllerProvider.notifier)
          .handleSocketMovieNightUpdated(decodedEvent);
    } else if (eventId != null) {
      _ref
          .read(friendsMovieNightControllerProvider.notifier)
          .refreshMovieNight(eventId);
    } else {
      _refreshAll();
    }
  }

  void _handleMovieNightUpdated(dynamic data) {
    try {
      if (data is Map && data['event'] is Map) {
        final eventMap = Map<String, dynamic>.from(data['event'] as Map);
        final decodedEvent = _ref
            .read(backendSocialServiceProvider)
            .decodeMovieNightEvent(eventMap);
        _ref
            .read(friendsMovieNightControllerProvider.notifier)
            .handleSocketMovieNightUpdated(decodedEvent);
        return;
      }
    } catch (e) {
      debugPrint('[RealTimeService] Error parsing movie_night_updated: $e');
    }
    _refreshSocial();
  }

  void _handleMovieStateChanged(dynamic data) {
    try {
      if (data is Map) {
        final tmdbId = data['tmdbId']?.toString();
        final stateName = data['stateName']?.toString();
        final value = data['value'] == true;
        if (tmdbId != null && stateName != null) {
          _ref
              .read(agreeoAppControllerProvider.notifier)
              .handleSocketMovieStateChanged(
                tmdbId: tmdbId,
                stateName: stateName,
                value: value,
              );
        }
      }
    } catch (e) {
      debugPrint('[RealTimeService] Error handling movie_state_changed: $e');
    }
  }

  void _refreshAll() {
    _refreshSocial();
    _refreshNotifications();
  }

  void _refreshSocial() {
    try {
      _ref
          .read(friendsMovieNightControllerProvider.notifier)
          .refreshSocialLayer();
    } catch (e) {
      debugPrint('[RealTimeService] Error refreshing social provider: $e');
    }
  }

  void _refreshNotifications() {
    try {
      _ref.read(notificationsProvider.notifier).refreshNotifications();
    } catch (e) {
      debugPrint(
        '[RealTimeService] Error refreshing notifications provider: $e',
      );
    }
  }
}

final realTimeServiceProvider = Provider<RealTimeService>((ref) {
  return RealTimeService(ref);
});

final realTimeConnectionProvider = StateProvider<bool>((ref) => false);
