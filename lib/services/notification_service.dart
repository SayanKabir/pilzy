import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Initialize notifications
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    debugPrint('✅ Notifications initialized');
  }

  /// Check if exact alarm permission is granted (Android 12+)
  Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.scheduleExactAlarm.status;
    return status.isGranted;
  }

  /// Request Android exact alarm permission (API 31+)
  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;

    // Only ask if not granted
    if (await hasExactAlarmPermission()) {
      debugPrint("🔔 Exact alarm permission already granted");
      return;
    }

    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();

    debugPrint("📅 Requested exact alarm permission");
  }

  /// Schedule a notification at a specific DateTime (Asia/Kolkata)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
    bool exact = true, // Use exact alarm if possible
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'med_channel',
      'Medications',
      channelDescription: 'Medication reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    final iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Convert to timezone-aware TZDateTime (Asia/Kolkata)
    final tzScheduled = tz.TZDateTime.from(
      scheduledDateTime,
      tz.getLocation('Asia/Kolkata'),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );

    debugPrint(
        '📅 Notification scheduled for $scheduledDateTime (exact=$exact) in Asia/Kolkata timezone');
  }
}
