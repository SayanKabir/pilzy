import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pilzy/constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Default values
  TimeOfDay _dailyReportTime = const TimeOfDay(hour: 20, minute: 0);
  int _missedReminderInterval = 15;
  // bool _notificationsEnabled = true; // No longer needed as state since it's fixed
  bool _soundEnabled = true;
  bool _hapticEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ─────────────────────────────────────────────────────────────
  // 💾 PERSISTENCE LOGIC
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // _notificationsEnabled is removed from load logic as it's always true
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _hapticEnabled = prefs.getBool('haptic_enabled') ?? true;
      _missedReminderInterval = prefs.getInt('missed_reminder_interval') ?? 15;

      final hour = prefs.getInt('report_hour') ?? 20;
      final minute = prefs.getInt('report_minute') ?? 0;
      _dailyReportTime = TimeOfDay(hour: hour, minute: minute);

      _isLoading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _saveTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('report_hour', time.hour);
    await prefs.setInt('report_minute', time.minute);
  }

  // ─────────────────────────────────────────────────────────────
  // 🖥️ UI BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: MyConstants.mintColor,
        body: Center(child: CircularProgressIndicator(color: MyConstants.tealColor)),
      );
    }

    return Scaffold(
      backgroundColor: MyConstants.mintColor,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: MyConstants.charcoalColor, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: MyConstants.charcoalColor, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              // 🔔 NOTIFICATIONS
              _buildSectionHeader("NOTIFICATIONS"),
              _buildGlassContainer(
                children: [
                  // ✨ FIXED NOTIFICATION SWITCH
                  // We pass 'true' for value and 'null' for onChanged to disable interaction
                  _buildSwitchTile(
                    "Enable Notifications",
                    "Alerts are always on for safety", // Updated subtitle to explain why
                    true,
                    null, // Passing null makes it non-interactive but visually ON
                  ),
                  const Divider(height: 1, color: Colors.black12),
                  _buildTimePickerTile(
                    "Daily Report Time",
                    "When to receive your daily summary",
                    _dailyReportTime,
                        (time) {
                      setState(() => _dailyReportTime = time);
                      _saveTime(time);
                    },
                  ),
                  const Divider(height: 1, color: Colors.black12),
                  _buildIntervalSelector(
                      "Missed Reminder Check",
                      "Remind again after missed dose",
                      _missedReminderInterval,
                          (val) {
                        setState(() => _missedReminderInterval = val);
                        _saveInt('missed_reminder_interval', val);
                      }
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 🎛️ APP BEHAVIOR
              _buildSectionHeader("APP BEHAVIOR"),
              _buildGlassContainer(
                children: [
                  _buildSwitchTile("Sound Effects", "Play sounds on completion", _soundEnabled, (v) {
                    setState(() => _soundEnabled = v);
                    _saveBool('sound_enabled', v);
                  }),
                  const Divider(height: 1, color: Colors.black12),
                  _buildSwitchTile("Haptic Feedback", "Vibrate on interactions", _hapticEnabled, (v) {
                    setState(() => _hapticEnabled = v);
                    _saveBool('haptic_enabled', v);
                  }),
                ],
              ),

              const SizedBox(height: 24),

              // ℹ️ ABOUT
              _buildSectionHeader("ABOUT"),
              _buildGlassContainer(
                children: [
                  _buildInfoTile("Version", "1.0.0"),
                  const Divider(height: 1, color: Colors.black12),
                  _buildInfoTile("Privacy Policy", "Read our terms"),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🧱 HELPERS
  // ─────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor.withValues(alpha: 0.5), letterSpacing: 1.2)),
      ),
    );
  }

  Widget _buildGlassContainer({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [BoxShadow(color: MyConstants.tealColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  // ✨ Updated to accept nullable onChanged
  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool)? onChanged) {
    // If onChanged is null, we dim the text slightly to indicate it's "system managed" or fixed
    final isFixed = onChanged == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: MyConstants.charcoalColor.withOpacity(isFixed ? 0.7 : 1.0))),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: MyConstants.charcoalColor.withValues(alpha: 0.5))),
            ]),
          ),
          const SizedBox(width: 8),
          // We wrap in IgnorePointer if fixed to prevent interaction touches
          IgnorePointer(
            ignoring: isFixed,
            child: CupertinoSwitch(
              value: value,
              onChanged: onChanged ?? (v){}, // Provide dummy callback if null so switch renders correctly
              activeColor: isFixed ? MyConstants.tealColor.withOpacity(0.6) : MyConstants.tealColor, // Dim color if fixed
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerTile(String title, String subtitle, TimeOfDay time, Function(TimeOfDay) onTimeChanged) {
    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onTimeChanged(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: MyConstants.charcoalColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: MyConstants.charcoalColor.withValues(alpha: 0.5))),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: MyConstants.tealColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: MyConstants.tealColor.withValues(alpha: 0.2))),
              child: Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.w900, color: MyConstants.tealColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalSelector(String title, String subtitle, int currentVal, Function(int) onSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: MyConstants.charcoalColor)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: MyConstants.charcoalColor.withValues(alpha: 0.5))),
          const SizedBox(height: 12),
          Row(
            children: [15, 30, 60].map((val) {
              final isSelected = currentVal == val;
              return Expanded(
                child: GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); onSelected(val); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? MyConstants.tealColor : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? MyConstants.tealColor : Colors.black.withValues(alpha: 0.05)),
                    ),
                    child: Center(child: Text(val == 60 ? "1 hr" : "$val min", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : MyConstants.charcoalColor.withValues(alpha: 0.6)))),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: MyConstants.charcoalColor)),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MyConstants.charcoalColor.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}