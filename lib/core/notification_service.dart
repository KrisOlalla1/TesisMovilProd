
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotiService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Guayaquil'));
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    if (Platform.isAndroid) {
      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    }
  }

  static Future<void> schedule(
    int id, {required String title, required String body, required DateTime whenLocal}
  ) async {
    final scheduled = tz.TZDateTime.from(whenLocal, tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'citas_channel', 'Recordatorios de Citas',
        channelDescription: 'Avisos previos a las citas médicas',
        importance: Importance.max, priority: Priority.high,
      ),
    );
    await _plugin.zonedSchedule(
      id, title, body, scheduled, details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }
}
