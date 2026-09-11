import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  /// Notificações (horários, avisos) só chegam a mesquitas marcadas
  /// como favoritas — cada mesquita tem o seu próprio tópico FCM.
  static Future<void> subscreverMesquita(String mesquitaId) {
    return FirebaseMessaging.instance.subscribeToTopic('mesquita_$mesquitaId');
  }

  static Future<void> dessubscreverMesquita(String mesquitaId) {
    return FirebaseMessaging.instance
        .unsubscribeFromTopic('mesquita_$mesquitaId');
  }

  static const Map<String, int> azanIds = {
    "Fajr": 501,
    "Dhuhr": 502,
    "Asr": 503,
    "Maghrib": 504,
    "Isha": 505,
  };

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mesquita_channel',
    'Mesquita Notificações',
    description: 'Canal principal da mesquita',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel azanChannel =
      AndroidNotificationChannel(
    'azan_channel',
    'Alarme de Azan',
    description: 'Alarme diário para os horários de oração (só notificação)',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // Canal separado porque o som de um canal Android não pode ser
  // alterado depois de criado — precisa de um canal próprio para tocar
  // o áudio do Azan em vez do som de notificação padrão.
  static const AndroidNotificationChannel azanChannelComSom =
      AndroidNotificationChannel(
    'azan_channel_som',
    'Alarme de Azan (com som do Azan)',
    description: 'Alarme diário para os horários de oração, a tocar o Azan',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('azan'),
    enableVibration: true,
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
    await androidImplementation?.createNotificationChannel(azanChannel);
    await androidImplementation?.createNotificationChannel(azanChannelComSom);
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
    bool tocarSom = false,
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

    final androidDetails = AndroidNotificationDetails(
      tocarSom ? azanChannelComSom.id : azanChannel.id,
      tocarSom ? azanChannelComSom.name : azanChannel.name,
      channelDescription: tocarSom
          ? azanChannelComSom.description
          : azanChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: tocarSom
          ? const RawResourceAndroidNotificationSound('azan')
          : null,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    final notificationDetails = NotificationDetails(
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

    print("🕌 Agendado $prayerName para "
        "${scheduledDate.hour}:${scheduledDate.minute} "
        "(agora=${now.hour}:${now.minute}) "
        "→ daqui a ${scheduledDate.difference(now).inMinutes} min");
  }

  static Future<void> cancelarAzan() async {
    for (var id in azanIds.values) {
      await _notifications.cancel(id: id);
    }
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
