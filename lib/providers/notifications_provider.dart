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

  Future<void> refreshNotifications() async {
    state = state.copyWith(isLoading: true);
    final socialService = _ref.read(backendSocialServiceProvider);
    final list = await socialService.loadNotifications();
    state = state.copyWith(notifications: list, isLoading: false);
  }

  Future<void> markAsRead(String id) async {
    final socialService = _ref.read(backendSocialServiceProvider);
    final ok = await socialService.markNotificationAsRead(id);
    if (ok) {
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
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  return NotificationsController(ref);
});
