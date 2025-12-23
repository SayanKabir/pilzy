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

  // ─────────────────────────────────────────────────────────────
  // 🔔 PAIRED REMINDERS (Main + 1hr Missed)
  // ─────────────────────────────────────────────────────────────

  /// Schedules the primary reminder and a "Missed" reminder 1 hour later
  Future<void> scheduleMedicationReminders({
    required int medId,
    required String name,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    // 1. Schedule Primary Notification
    await scheduleNotification(
      id: medId,
      title: '💊 Time for $name',
      body: 'Take your $dosage now to stay on track.',
      scheduledDateTime: scheduledTime,
    );

    // 2. Schedule Missed Reminder (1 Hour Offset)
    // We use a specific ID offset (e.g., medId + 1000) for missed reminders
    final missedTime = scheduledTime.add(const Duration(hours: 1));
    await scheduleNotification(
      id: medId + 1000,
      title: '⚠️ Missed Reminder: $name',
      body: 'It has been an hour since your scheduled dose. Did you take it?',
      scheduledDateTime: missedTime,
      importance: Importance.max, // High importance for missed doses
    );
  }

  /// Cancels the missed reminder specifically (call this when "Taken" is pressed)
  Future<void> cancelMissedReminder(int medId) async {
    await flutterLocalNotificationsPlugin.cancel(medId + 1000);
    debugPrint('🔕 Cancelled missed reminder for ID: ${medId + 1000}');
  }

  // ─────────────────────────────────────────────────────────────
  // 🌙 DAILY SUMMARY NOTIFICATION
  // ─────────────────────────────────────────────────────────────

  /// Schedules a summary notification for the end of the day (e.g., 9:00 PM)
  Future<void> scheduleDailySummary({
    required int takenCount,
    required int totalCount,
  }) async {
    final now = DateTime.now();
    // Set summary for 9:00 PM
    var summaryTime = DateTime(now.year, now.month, now.day, 21, 0);

    // If it's already past 9 PM today, schedule for tomorrow
    if (now.isAfter(summaryTime)) {
      summaryTime = summaryTime.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      'summary_channel',
      'Daily Summary',
      channelDescription: 'End of day medication report',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails()
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      8888, // Static unique ID for summary
      '🌙 Daily Adherence Report',
      'Today you took $takenCount out of $totalCount doses. Keep it up!',
      tz.TZDateTime.from(summaryTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🛠️ CORE SCHEDULING LOGIC
  // ─────────────────────────────────────────────────────────────

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
    bool exact = true,
    Importance importance = Importance.max,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'med_channel',
      'Medications',
      channelDescription: 'Medication reminders',
      importance: importance,
      priority: Priority.high,
    );
    final iosDetails = const DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final tzScheduled = tz.TZDateTime.from(
      scheduledDateTime,
      tz.local,
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
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🔓 PERMISSIONS
  // ─────────────────────────────────────────────────────────────

  Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    return await Permission.scheduleExactAlarm.isGranted;
  }

  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    if (await hasExactAlarmPermission()) return;

    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
  }
}