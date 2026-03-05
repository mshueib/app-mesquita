import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mesquita_channel',
    'Mesquita Notificações',
    description: 'Canal principal da mesquita',
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      settings: initializationSettings,
    );

    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(channel);
  }

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
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  static Future<void> scheduleAzan({
    required String prayerName,
    required int hour,
    required int minute,
    required int id,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'mesquita_channel',
      'Mesquita Notificações',
      channelDescription: 'Canal principal da mesquita',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: "🕌 Hora do $prayerName",
      body: "Está na hora do Azan",
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    print("🕌 Agendado $prayerName para $hour:$minute");
  }

  // Adicionar dentro da classe NotificationService:
  static Future<void> cancelarAzan() async {
    // IDs 501 a 505 são reservados para o Azan
    for (int id = 501; id <= 505; id++) {
      await _notifications.cancel(id: id);
    }
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
