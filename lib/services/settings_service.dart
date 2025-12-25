import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // Singleton pattern
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  // In-memory cache for instant access
  bool hapticEnabled = true;
  bool soundEnabled = true;
  bool notificationsEnabled = true;
  TimeOfDay dailyReportTime = const TimeOfDay(hour: 20, minute: 0);
  int missedReminderInterval = 15;

  // 🚀 Initialize at app startup
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    hapticEnabled = _prefs.getBool('haptic_enabled') ?? true;
    soundEnabled = _prefs.getBool('sound_enabled') ?? true;
    notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
    missedReminderInterval = _prefs.getInt('missed_reminder_interval') ?? 15;

    final hour = _prefs.getInt('report_hour') ?? 20;
    final minute = _prefs.getInt('report_minute') ?? 0;
    dailyReportTime = TimeOfDay(hour: hour, minute: minute);
  }

  // ⚡️ Smart Haptic Helper
  void vibrate(HapticFeedbackType type) {
    if (!hapticEnabled) return; // Respect the user's choice

    switch (type) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  // 💾 Getters for Notification Logic
  int get reminderInterval => missedReminderInterval;
  TimeOfDay get reportTime => dailyReportTime;
}

enum HapticFeedbackType { light, medium, heavy, selection }