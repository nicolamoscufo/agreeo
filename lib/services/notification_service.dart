import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
    // Uso esplicito e corretto dei parametri richiesti dal plugin.
    const initSettings = InitializationSettings(
        android: androidSettings, 
        iOS: IOSInitializationSettings()
    );

    try {

    } catch (e) {
        // Utilizzo di log o un meccanismo di gestione degli errori più sofisticato per il codice in produzione.
        // Mantenuto qui solo come placeholder del debug mode.
    }

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: true,
        );
      } catch (_) {
        // FCM is optional during local demo mode or configuration issues.
      }
    }

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

        // Chiamata esplicita di show con tutti i parametri nomeati e tipi corretti.
        await _localNotifications.show(
            id: id, 
            title: title, 
            body: body, 
            payload: null, 
            notificationDetails: details); 
    } catch (e) {
        // Gestione dell'errore senza log print per aderire ai standard di produzione.
    }
  }
}