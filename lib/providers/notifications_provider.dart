import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart'; // contains backendSocialServiceProvider

class NotificationsState {
  const NotificationsState({
    required this.notifications,
    required this.isLoading,
  });

  final List<InAppNotification> notifications;
  final bool isLoading;

  int get unreadCount => notifications.where((n) => !n.read).length;

  NotificationsState copyWith({
    List<InAppNotification>? notifications,
    bool? isLoading,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._ref)
      : super(const NotificationsState(notifications: [], isLoading: false)) {
    // Initial load
    refreshNotifications();
  }

  final Ref _ref;

  /// IDs we have locally marked as read. Survives backend re-fetches so a
  /// slow backend write does not "un-read" a notification the user already saw.
  final Set<String> _locallyReadIds = {};

  Future<void> refreshNotifications() async {
    state = state.copyWith(isLoading: true);
    final socialService = _ref.read(backendSocialServiceProvider);
    final list = await socialService.loadNotifications();

    // Merge: if we locally marked something as read but the backend has not
    // yet committed, preserve the local read status.
    final merged = list.map((n) {
      if (!n.read && _locallyReadIds.contains(n.id)) {
        return InAppNotification(
          id: n.id,
          type: n.type,
          title: n.title,
          message: n.message,
          entityId: n.entityId,
          extraData: n.extraData,
          read: true,
          createdAt: n.createdAt,
        );
      }
      return n;
    }).toList();

    // Clean up: remove ids that are already read on the backend
    for (final n in list) {
      if (n.read) _locallyReadIds.remove(n.id);
    }

    state = state.copyWith(notifications: merged, isLoading: false);
  }

  Future<void> markAsRead(String id) async {
    // 1. Optimistic local update (instant UI feedback)
    _locallyReadIds.add(id);
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.id == id
              ? InAppNotification(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  message: n.message,
                  entityId: n.entityId,
                  extraData: n.extraData,
                  read: true,
                  createdAt: n.createdAt,
                )
              : n)
          .toList(),
    );

    // 2. Fire and forget the backend call
    final socialService = _ref.read(backendSocialServiceProvider);
    await socialService.markNotificationAsRead(id);
  }

  Future<void> markLessImportantAsRead() async {
    final targetIds = state.notifications
        .where((n) =>
            !n.read &&
            n.type != 'friend_request' &&
            n.type != 'movie_night_voting' &&
            n.type != 'movie_night_invite')
        .map((n) => n.id)
        .toList();

    if (targetIds.isEmpty) return;

    _locallyReadIds.addAll(targetIds);
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => targetIds.contains(n.id)
              ? InAppNotification(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  message: n.message,
                  entityId: n.entityId,
                  extraData: n.extraData,
                  read: true,
                  createdAt: n.createdAt,
                )
              : n)
          .toList(),
    );

    final socialService = _ref.read(backendSocialServiceProvider);
    for (final id in targetIds) {
      socialService.markNotificationAsRead(id).catchError((_) => false);
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  return NotificationsController(ref);
});
