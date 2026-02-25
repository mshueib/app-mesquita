import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // 🔔 Instância do plugin
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 🔧 Inicialização (VERSÃO 17+)
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Pode deixar vazio
      },
    );
  }

  // 🔔 Mostrar notificação
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'mesquita_channel',
      'Mesquita Notifications',
      channelDescription: 'Notificações da Mesquita Central de Quelimane',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
