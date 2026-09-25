import 'package:azan_player/azan_player.dart';
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

  // ID novo de propósito: canais Android são imutáveis depois de
  // criados no aparelho — se o telemóvel já tinha "azan_channel"
  // registado com uma configuração antiga, o código nunca consegue
  // corrigir esse canal, só criando um ID novo é que força o Android
  // a aplicar as definições actuais (som, importância, etc.).
  static const AndroidNotificationChannel azanChannel =
      AndroidNotificationChannel(
    'azan_channel_v2',
    'Alarme de Azan',
    description: 'Alarme diário para os horários de oração (só notificação)',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // Canais antigos que já não são usados — removidos para não ficarem
  // duplicados nas definições de notificações do telemóvel.
  // azan_channel_som_v3: o som do Azan como som de notificação era
  // cortado pelo Android ao abrir a barra de notificações — agora é
  // tocado pelo plugin azan_player (ver [scheduleAzan]).
  static const List<String> _canaisObsoletos = [
    'azan_channel',
    'azan_channel_som',
    'azan_channel_som_v2',
    'azan_channel_som_v3',
  ];

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

    for (final id in _canaisObsoletos) {
      try {
        await androidImplementation?.deleteNotificationChannel(channelId: id);
      } catch (_) {}
    }
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

  /// Agenda o alarme diário de uma oração.
  ///
  /// Com [tocarSom], o Azan é tocado pelo plugin azan_player (serviço
  /// Android em primeiro plano): assim não é cortado ao abrir a barra de
  /// notificações, só pára com "Parar Azan" ou uma tecla de volume.
  /// Sem som, fica uma notificação normal agendada.
  static Future<void> scheduleAzan({
    required String prayerName,
    required int hour,
    required int minute,
    required int id,
    bool tocarSom = false,
  }) async {
    if (tocarSom) {
      await AzanPlayer.agendar(
          id: id, nome: prayerName, hora: hour, minuto: minute);
      return;
    }

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
      azanChannel.id,
      azanChannel.name,
      channelDescription: azanChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: "🕌 Hora do $prayerName",
      body: "Está na hora do Azan",
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancela os alarmes de Azan agendados (os dois tipos: notificação
  /// simples e Azan com som). Não pára um Azan que esteja a tocar.
  ///
  /// `cancel(id)` também remove a notificação se estiver visível. Como a
  /// app reagenda os alarmes sempre que abre ou recebe dados novos, uma
  /// notificação de Azan que esteja a ser mostrada não é cancelada: o
  /// novo zonedSchedule com o mesmo id substitui o agendamento pendente.
  static Future<void> cancelarAzan() async {
    try {
      await AzanPlayer.cancelarTodos();
    } catch (_) {}

    final visiveis = <int>{};
    try {
      final activas = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.getActiveNotifications();
      for (final n in activas ?? const <ActiveNotification>[]) {
        if (n.id != null) visiveis.add(n.id!);
      }
    } catch (_) {}

    for (var id in azanIds.values) {
      if (visiveis.contains(id)) continue;
      await _notifications.cancel(id: id);
    }
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
