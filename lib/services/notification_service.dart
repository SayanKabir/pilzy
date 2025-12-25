import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_service.dart';
import '../models/medication.dart'; // ✨ Added this import for rescheduleAll

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
  // 🔄 SYNC & RESCHEDULE (The Safety Net)
  // ─────────────────────────────────────────────────────────────

  /// Cancels all existing notifications and re-schedules them based on the current Hive database.
  /// Call this in main.dart after initializing services.
  Future<void> rescheduleAll(List<Medication> allMeds) async {
    debugPrint('🔄 Rescheduling all notifications...');

    // 1. Clear everything to prevent duplicates
    await flutterLocalNotificationsPlugin.cancelAll();

    // 2. Loop through every medication
    for (var med in allMeds) {
      // Skip if the course is over
      if (med.endDate != null && med.endDate!.isBefore(DateTime.now())) {
        continue;
      }

      // 3. Re-schedule using the core logic
      await scheduleMedicationReminders(
        medId: med.id,
        name: med.name,
        dosage: med.dosage,
        scheduledTime: med.scheduledTime,
      );
    }
    debugPrint('✅ All active medications rescheduled.');
  }

  // ─────────────────────────────────────────────────────────────
  // 🔔 PAIRED REMINDERS (Main + Smart Interval Missed)
  // ─────────────────────────────────────────────────────────────

  Future<void> scheduleMedicationReminders({
    required int medId,
    required String name,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    // 🛑 Check Global Switch
    if (!SettingsService().notificationsEnabled) return;

    // 1. Schedule Primary Notification
    await scheduleNotification(
      id: medId,
      title: '💊 Time for $name',
      body: 'Take your $dosage now to stay on track.',
      scheduledDateTime: scheduledTime,
    );

    // 2. Schedule Missed Reminder (Using Dynamic Interval)
    final int intervalMinutes = SettingsService().missedReminderInterval;
    final missedTime = scheduledTime.add(Duration(minutes: intervalMinutes));

    await scheduleNotification(
      id: medId + 1000,
      title: '⚠️ Missed Reminder: $name',
      body: 'It has been $intervalMinutes minutes since your scheduled dose. Did you take it?',
      scheduledDateTime: missedTime,
      importance: Importance.max,
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

  Future<void> scheduleDailySummary({
    required int takenCount,
    required int totalCount,
    String? customMessage,
  }) async {
    // 🛑 Check Global Switch
    if (!SettingsService().notificationsEnabled) return;

    final now = DateTime.now();
    final reportTime = SettingsService().dailyReportTime;

    var summaryTime = DateTime(
        now.year,
        now.month,
        now.day,
        reportTime.hour,
        reportTime.minute
    );

    if (now.isAfter(summaryTime)) {
      summaryTime = summaryTime.add(const Duration(days: 1));
    }

    final String body = customMessage ?? "You took $takenCount out of $totalCount doses today.";

    const androidDetails = AndroidNotificationDetails(
      'summary_channel',
      'Daily Summary',
      channelDescription: 'End of day medication report',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      8888,
      '🌙 Pilzy Daily Report',
      body,
      tz.TZDateTime.from(summaryTime, tz.local),
      const NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails()),
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
    if (!SettingsService().notificationsEnabled) {
      debugPrint("🚫 Notification blocked by user settings");
      return;
    }

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