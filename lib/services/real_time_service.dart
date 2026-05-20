import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:agreeo/config/backend_config.dart';
import 'package:agreeo/services/notification_service.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/providers/notifications_provider.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';

class RealTimeService {
  RealTimeService(this._ref);

  final Ref _ref;
  IO.Socket? _socket;
  String? _currentUserId;

  void connect(String userId) {
    if (_socket != null && _currentUserId == userId) {
      return;
    }
    
    if (_socket != null) {
      disconnect();
    }

    _currentUserId = userId;
    final baseUrl = BackendConfig.fromEnv().baseUrl;
    
    debugPrint('[RealTimeService] Connecting to Socket.io at $baseUrl');
    
    _socket = IO.io(baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );

    _socket!.onConnect((_) {
      debugPrint('[RealTimeService] Connected! Authenticating user: $userId');
      _socket!.emit('authenticate', {'userId': userId});
    });

    _socket!.onDisconnect((_) {
      debugPrint('[RealTimeService] Disconnected');
    });

    _socket!.onConnectError((data) {
      debugPrint('[RealTimeService] Connection error: $data');
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

    NotificationService.instance.showGenericNotification(
      id: 3001,
      title: 'Movie Night Invite',
      body: '$hostName invited you to "$eventName".',
    );
    _refreshAll();
  }

  void _handleMovieNightVotingStarted(dynamic data) {
    String eventName = 'Movie Night';
    String? eventId;
    MovieNightEvent? decodedEvent;
    try {
      if (data is Map && data['event'] is Map) {
        final eventMap = Map<String, dynamic>.from(data['event'] as Map);
        decodedEvent = _ref.read(backendSocialServiceProvider).decodeMovieNightEvent(eventMap);
        eventName = decodedEvent.name;
        eventId = decodedEvent.id;
      }
    } catch (_) {}

    NotificationService.instance.showGenericNotification(
      id: 3002,
      title: 'Voting Started',
      body: 'Voting has started for "$eventName"!',
    );
    if (decodedEvent != null) {
      _ref.read(friendsMovieNightControllerProvider.notifier).handleSocketMovieNightUpdated(decodedEvent);
    } else if (eventId != null) {
      _ref.read(friendsMovieNightControllerProvider.notifier).refreshMovieNight(eventId);
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
          decodedEvent = _ref.read(backendSocialServiceProvider).decodeMovieNightEvent(eventMap);
          eventName = decodedEvent.name;
          eventId = decodedEvent.id;
        }
      }
    } catch (_) {}

    NotificationService.instance.showGenericNotification(
      id: 3003,
      title: 'Movie Night Completed',
      body: 'Decision reached for "$eventName"! Winner: $winnerTitle.',
    );
    if (decodedEvent != null) {
      _ref.read(friendsMovieNightControllerProvider.notifier).handleSocketMovieNightUpdated(decodedEvent);
    } else if (eventId != null) {
      _ref.read(friendsMovieNightControllerProvider.notifier).refreshMovieNight(eventId);
    } else {
      _refreshAll();
    }
  }

  void _handleMovieNightUpdated(dynamic data) {
    try {
      if (data is Map && data['event'] is Map) {
        final eventMap = Map<String, dynamic>.from(data['event'] as Map);
        final decodedEvent = _ref.read(backendSocialServiceProvider).decodeMovieNightEvent(eventMap);
        _ref.read(friendsMovieNightControllerProvider.notifier).handleSocketMovieNightUpdated(decodedEvent);
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
          _ref.read(agreeoAppControllerProvider.notifier).handleSocketMovieStateChanged(
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
      _ref.read(friendsMovieNightControllerProvider.notifier).refreshSocialLayer();
    } catch (e) {
      debugPrint('[RealTimeService] Error refreshing social provider: $e');
    }
  }

  void _refreshNotifications() {
    try {
      _ref.read(notificationsProvider.notifier).refreshNotifications();
    } catch (e) {
      debugPrint('[RealTimeService] Error refreshing notifications provider: $e');
    }
  }
}

final realTimeServiceProvider = Provider<RealTimeService>((ref) {
  return RealTimeService(ref);
});
