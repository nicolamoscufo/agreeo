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

      // Android 13+ requires a runtime permission before any banner shows.
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (e) {
      // Ignore local notification init failures during prototype startup.
    }

    _initialized = true;
  }

  /// Stable id for the recurring daily-suggestion reminder, so re-scheduling
  /// replaces the previous one and cancel targets exactly it.
  static const int dailyReminderNotificationId = 1003;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'agreeo_updates',
      'Agreeo Updates',
      channelDescription: 'Group events and recommendation reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> showEventCreated(String title, String body) async {
    await _showNotification(id: 1001, title: title, body: body);
  }

  Future<void> showConsensusReached(String title, String body) async {
    await _showNotification(id: 1002, title: title, body: body);
  }

  /// (Re)schedules the recurring daily-suggestion reminder, repeating every
  /// 24 hours from now. Calling it again resets the window, so the reminder
  /// only fires when the user hasn't opened the app for a full day.
  Future<void> scheduleDailySuggestionReminder({
    required String title,
    required String body,
  }) async {
    try {
      await initialize();
      await _localNotifications.periodicallyShow(
        id: dailyReminderNotificationId,
        title: title,
        body: body,
        repeatInterval: RepeatInterval.daily,
        notificationDetails: _details,
        // Inexact: no SCHEDULE_EXACT_ALARM permission needed, and minute-level
        // precision is irrelevant for a daily nudge.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      // Scheduling is unsupported on some platforms (e.g. Windows): best effort.
    }
  }

  Future<void> cancelDailySuggestionReminder() async {
    try {
      await _localNotifications.cancel(id: dailyReminderNotificationId);
    } catch (e) {
      // Ignore cancel failures during prototype runs.
    }
  }

  Future<void> showGenericNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _showNotification(id: id, title: title, body: body);
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      // Lazy init: nothing else in the app calls initialize() at startup.
      await initialize();

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        payload: null,
        notificationDetails: _details,
      );
    } catch (e) {
      // Ignore local notification failures during prototype runs.
    }
  }
}
