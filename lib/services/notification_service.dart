import 'dart:async';

//
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: IOSInitializationSettings(),
    );

    try {
      await _localNotifications.initialize(settings: initSettings);
    } catch (e) {
      // Ignore local notification init failures during prototype startup.
    }

    // Local notifications only; skip push permissions

    _initialized = true;
  }

  Future<void> showEventCreated(String title, String body) async {
    await _showNotification(id: 1001, title: title, body: body);
  }

  Future<void> showConsensusReached(String title, String body) async {
    await _showNotification(id: 1002, title: title, body: body);
  }

  Future<void> showDailyReminder(String title, String body) async {
    await _showNotification(id: 1003, title: title, body: body);
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'agreeo_updates',
          'Agreeo Updates',
          channelDescription: 'Group events and recommendation reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        payload: null,
        notificationDetails: details,
      );
    } catch (e) {
      // Ignore local notification failures during prototype runs.
    }
  }
}
