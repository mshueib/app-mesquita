import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ✅ CANAL ANDROID
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mesquita_channel',
    'Mesquita Notificações',
    description: 'Canal principal da mesquita',
    importance: Importance.max,
  );

  // ✅ INICIALIZAÇÃO CORRETA PARA V17+
  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // ação ao tocar na notificação (opcional)
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(channel);
  }

  // ✅ MOSTRAR NOTIFICAÇÃO (V17+)
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'mesquita_channel',
      'Mesquita Notificações',
      channelDescription: 'Canal principal da mesquita',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}

// 🔥 Necessário para background (obrigatório v17+)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Pode deixar vazio
}
