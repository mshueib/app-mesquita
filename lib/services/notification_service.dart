import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final Int64List vibrationPatternAzan =
      Int64List.fromList([0, 5000, 500, 4500]);

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(
      settings: settings,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final isAzan = notification.title?.toLowerCase().contains('azan') ?? false;

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isAzan ? 'azan_channel' : 'avisos_geral',
          isAzan ? 'Hora do Azan' : 'Avisos Gerais',
          vibrationPattern: isAzan ? vibrationPatternAzan : null,
          enableVibration: true,
          playSound: !isAzan,
          importance: isAzan ? Importance.max : Importance.defaultImportance,
          priority: isAzan ? Priority.high : Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
