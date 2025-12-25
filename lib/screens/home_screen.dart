import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pilzy/constants/constants.dart';
import 'package:pilzy/screens/settings_screen.dart';

import '../blocs/medication_bloc.dart';
import '../blocs/medication_state.dart';
import '../blocs/medication_event.dart';
import '../widgets/medication_bundle.dart';
import '../widgets/medication_card.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import 'add_med_screen.dart';

// ─────────────────────────────────────────────────────────────
// ADHERENCE UTILITY
// ─────────────────────────────────────────────────────────────

class AdherenceUtils {
  static double calculateAdherenceForDay(
      DateTime date, List<Medication> meds, Map<int, List<DoseLog>> logs) {
    int totalScheduled = 0;
    int totalTaken = 0;

    for (var med in meds) {
      if (_isScheduled(med, date)) {
        totalScheduled++;
        final medLogs = logs[med.id] ?? [];
        if (medLogs.any((l) =>
        l.takenAt.year == date.year &&
            l.takenAt.month == date.month &&
            l.takenAt.day == date.day)) {
          totalTaken++;
        }
      }
    }
    return totalScheduled == 0 ? -1.0 : (totalTaken / totalScheduled);
  }

  static bool _isScheduled(Medication med, DateTime date) {
    final start = DateTime(med.scheduledTime.year, med.scheduledTime.month, med.scheduledTime.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target.isBefore(start)) return false;

    final diff = target.difference(start).inDays;
    switch (med.frequencyType) {
      case FrequencyType.daily:
        return true;
      case FrequencyType.everyXDays:
        return diff % med.frequencyInterval == 0;
      case FrequencyType.weekly:
        return diff % (7 * med.frequencyInterval) == 0;
      default:
        return false;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  int _calculateCurrentStreak(List<Medication> meds, Map<int, List<DoseLog>> logs) {
    if (meds.isEmpty) return 0;

    int streak = 0;
    DateTime dateToCheck = DateTime.now();
    // Limit the search to the last 90 days to prevent infinite loops
    int safetyBreak = 0;

    while (safetyBreak < 90) {
      double score = AdherenceUtils.calculateAdherenceForDay(dateToCheck, meds, logs);

      if (score >= 1.0 || score == -1.0) {
        if (score >= 1.0) streak++;
        dateToCheck = dateToCheck.subtract(const Duration(days: 1));
        safetyBreak++;
      } else {
        break; // Streak broken
      }
    }
    return streak;
  }

  // ─────────────────────────────────────────────────────────────
  // ACHIEVEMENT OVERLAY
  // ─────────────────────────────────────────────────────────────

  void _showAchievement(int days) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.orangeAccent, size: 80),
              const SizedBox(height: 16),
              Text("$days DAY STREAK!",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor)),
              const SizedBox(height: 8),
              const Text("Achievement Unlocked: Consistency King", textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyConstants.mintColor,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            BlocBuilder<MedicationBloc, MedicationState>(
              builder: (context, state) {
                if (state is MedicationLoading) return const Center(child: CircularProgressIndicator(color: MyConstants.tealColor,));
                if (state is MedicationLoaded) {
                  if (state.meds.isEmpty) return _buildEmptyState();
                  return IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildTodayTab(state),
                      _buildHistoryTab(state),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Positioned(
              left: 20, right: 20, bottom: 30,
              child: _buildUnifiedFloatingBar(context),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: TODAY VIEW (Fixed Floating Timeline)
  // ─────────────────────────────────────────────────────────────

  Widget _buildTodayTab(MedicationLoaded state) {
    final now = DateTime.now();

    // 1. Group medications by time (HH:mm) while calculating summary stats
    int takenCount = 0;
    List<String> remainingMeds = [];
    List<String> missedMeds = [];
    final Map<String, List<Medication>> groupedMeds = {};

    for (var med in state.meds) {
      // Only process if the medication is within its active course duration
      if (!med.isActiveOn(now)) continue;

      final logs = state.logs[med.id] ?? [];
      final takenToday = logs.any((log) =>
      log.takenAt.year == now.year &&
          log.takenAt.month == now.month &&
          log.takenAt.day == now.day);

      if (takenToday) {
        takenCount++;
      } else {
        final scheduleToday = DateTime(now.year, now.month, now.day,
            med.scheduledTime.hour, med.scheduledTime.minute);
        if (scheduleToday.isBefore(now)) {
          missedMeds.add(med.name);
        } else {
          remainingMeds.add(med.name);
        }
      }

      // Add to grouping map
      final timeKey = DateFormat('HH:mm').format(med.scheduledTime);
      groupedMeds.putIfAbsent(timeKey, () => []).add(med);
    }

    // 2. Sort the time slots (keys) chronologically
    final sortedTimeKeys = groupedMeds.keys.toList()..sort();
    final streak = _calculateCurrentStreak(state.meds, state.logs);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 140, top: 0),
      itemCount: sortedTimeKeys.length + 1,
      itemBuilder: (context, idx) {
        // 3. Header with recalculated stats
        if (idx == 0) {
          return _buildSummaryHeader(
              context,
              takenCount,
              remainingMeds,
              missedMeds,
              streak
          );
        }

        final timeKey = sortedTimeKeys[idx - 1];
        final medsInGroup = groupedMeds[timeKey]!;
        final bool isLast = idx == sortedTimeKeys.length;
        final displayTime = medsInGroup.first.scheduledTime;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: IntrinsicHeight(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Timeline vertical line
                Positioned(
                  top: 0, bottom: 0, left: 0,
                  child: _buildFloatingTimelineIndicator(displayTime, isLast),
                ),

                // The Content: Stacked Bundle or Single Card
                Padding(
                  padding: const EdgeInsets.only(left: 55),
                  child: medsInGroup.length > 1
                      ? MedicationBundle(
                    meds: medsInGroup,
                    allLogs: state.logs,
                  )
                      : MedicationCard(
                    med: medsInGroup.first,
                    logs: state.logs[medsInGroup.first.id] ?? [],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingTimelineIndicator(DateTime time, bool isLast) {
    return SizedBox(
      width: 65, // Covers the time text and the overlapping line
      child: Column(
        children: [
          const SizedBox(height: 24), // Center the hub with the card header
          Text(
            DateFormat('HH:mm').format(time),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: MyConstants.charcoalColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 6),
          // The Floating Hub (Circle)
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MyConstants.tealColor,
              border: Border.all(color: Colors.white, width: 3), // Creates the floating "cutout" look
              boxShadow: [
                BoxShadow(
                  color: MyConstants.tealColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
          ),
          // The Connecting Line
          if (!isLast)
            Expanded(
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: MyConstants.tealColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: HISTORY VIEW
  // ─────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────
  // TAB 2: UNIFIED HISTORY HUB
  // ─────────────────────────────────────────────────────────────

  Widget _buildHistoryTab(MedicationLoaded state) {
    // Filter for finished medications only
    final finishedMeds = state.meds.where((m) =>
    m.endDate != null && DateTime.now().isAfter(m.endDate!)
    ).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER SECTION
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("History Hub",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor, letterSpacing: -0.5)),
                Text("Your past consistency and completed courses",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MyConstants.charcoalColor.withValues(alpha: 0.5))),
              ],
            ),
          ),

          // 2. ADHERENCE HEATMAP
          _buildAdherenceHeatmap(state),

          const SizedBox(height: 24),

          // 3. ARCHIVED COURSES SECTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.auto_stories_rounded, size: 18, color: MyConstants.charcoalColor.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text("COMPLETED COURSES",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor.withValues(alpha: 0.6), letterSpacing: 1.2)),
                const SizedBox(width: 8),
                Expanded(child: Divider(color: MyConstants.charcoalColor.withValues(alpha: 0.1))),
              ],
            ),
          ),

          if (finishedMeds.isEmpty)
            _buildEmptyArchiveState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: finishedMeds.length,
              itemBuilder: (context, index) => _buildHistoryCard(finishedMeds[index]),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 📜 ARCHIVED COURSE CARD
  // ─────────────────────────────────────────────────────────────

  Widget _buildHistoryCard(Medication med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(med.name,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor)),
                          Text(med.dosage,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MyConstants.charcoalColor.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    _buildHistoryStatusBadge(),
                  ],
                ),
                const SizedBox(height: 16),
                _buildHistoryInfoRow(Icons.calendar_month_rounded, "Course",
                    "${DateFormat('MMM d').format(med.startDate)} — ${DateFormat('MMM d, yyyy').format(med.endDate!)}"),
                const SizedBox(height: 6),
                _buildHistoryInfoRow(Icons.check_circle_outline_rounded, "Adherence", "100% Correct"), // Placeholder
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: MyConstants.charcoalColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "ARCHIVED",
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor.withValues(alpha: 0.6), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildHistoryInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: MyConstants.tealColor),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MyConstants.charcoalColor.withValues(alpha: 0.5))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MyConstants.charcoalColor)),
      ],
    );
  }

  Widget _buildEmptyArchiveState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.auto_stories_outlined, size: 50, color: MyConstants.charcoalColor.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text("No completed courses yet",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MyConstants.charcoalColor.withValues(alpha: 0.3))),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATION & SUMMARY
  // ─────────────────────────────────────────────────────────────

  Widget _buildUnifiedFloatingBar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 80, padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.35), Colors.white.withOpacity(0.1)]),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildUnifiedNavItem(Icons.today_rounded, "Today", 0),
              _buildIntegratedAddButton(context),
              _buildUnifiedNavItem(Icons.bar_chart_rounded, "History", 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedNavItem(IconData icon, String label, int index) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: isSelected ? MyConstants.tealColor : MyConstants.charcoalColor.withOpacity(0.4), size: 26),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isSelected ? MyConstants.tealColor : MyConstants.charcoalColor.withOpacity(0.4))),
        ]),
      ),
    );
  }

  Widget _buildIntegratedAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final added = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMedScreen()));
        if (added == true) context.read<MedicationBloc>().add(LoadMedications());
      },
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [MyConstants.tealColor, MyConstants.tealColor.withOpacity(0.8)]),
          shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          boxShadow: [BoxShadow(color: MyConstants.tealColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, int taken, List<String> left, List<String> missed, int streak) {
    final int total = taken + left.length + missed.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildSegmentedRing(taken, left.length, missed.length, total),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                              Text(_getGreeting(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor)),
                              Text(DateFormat('EEEE, MMM d').format(DateTime.now()), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MyConstants.charcoalColor.withOpacity(0.5))),
                              if (streak > 0) GestureDetector(onTap: () => _showAchievement(streak), child: _buildStreakBadge(streak)),
                            ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (missed.isNotEmpty) _buildSummaryLabel("Remaining: ${missed.join(', ')}", Colors.redAccent.withOpacity(0.1), Colors.redAccent),
                if (left.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: _buildSummaryLabel("Remaining: ${left.join(', ')}", MyConstants.charcoalColor.withOpacity(0.05), MyConstants.charcoalColor.withOpacity(0.7))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakBadge(int streak) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orangeAccent.withOpacity(0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 20),
        const SizedBox(width: 4),
        Text("$streak DAYS", style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _buildAdherenceHeatmap(MedicationLoaded state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ADHERENCE: LAST 4 WEEKS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor.withOpacity(0.5), letterSpacing: 1.5)),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 28,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
                  itemBuilder: (context, index) {
                    final date = DateTime.now().subtract(Duration(days: 27 - index));
                    final score = AdherenceUtils.calculateAdherenceForDay(date, state.meds, state.logs);
                    return _buildHeatmapSquare(score);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapSquare(double score) {
    Color color;
    if (score < 0) color = Colors.white.withOpacity(0.1);
    else if (score == 0) color = Colors.redAccent.withOpacity(0.3);
    else if (score < 1.0) color = MyConstants.tealColor.withOpacity(0.4);
    else color = MyConstants.tealColor;
    return Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)));
  }

  Widget _buildSegmentedRing(int taken, int left, int missed, int total) {
    return Stack(alignment: Alignment.center, children: [
      SizedBox(width: 85, height: 85, child: CustomPaint(painter: MultiSegmentPainter(taken: taken, left: left, missed: missed, total: total))),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text("$taken", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: MyConstants.tealColor)),
        Text("OF $total", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: MyConstants.charcoalColor.withOpacity(0.4))),
      ]),
    ]);
  }

  Widget _buildSummaryLabel(String text, Color bg, Color textCol) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.4))),
      child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: textCol)), const SizedBox(width: 12), Expanded(child: Text(text, maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textCol)))]),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.medication_liquid_rounded, size: 80, color: MyConstants.charcoalColor.withOpacity(0.15)), const SizedBox(height: 16), Text('No medications yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: MyConstants.charcoalColor.withOpacity(0.7)))]));
  }

  PreferredSize _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: AppBar(toolbarHeight: 60, backgroundColor: MyConstants.mintColor.withOpacity(0.9), elevation: 0, title: GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), child: Container(width: 90, height: 40, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/pilzy4.png'), fit: BoxFit.contain))))))),
    );
  }
}

class MultiSegmentPainter extends CustomPainter {
  final int taken, left, missed, total;
  MultiSegmentPainter({required this.taken, required this.left, required this.missed, required this.total});
  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final double strokeWidth = 10.0;
    final Rect rect = Offset(strokeWidth / 2, strokeWidth / 2) & Size(size.width - strokeWidth, size.height - strokeWidth);
    final Paint trackPaint = Paint()..color = Colors.black.withOpacity(0.05)..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.28318, false, trackPaint);
    double startAngle = -1.5708;
    void drawSegment(int count, Color color) {
      if (count <= 0) return;
      double sweep = (count / total) * 6.28318;
      canvas.drawArc(rect, startAngle + 0.07, sweep - 0.14, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
      startAngle += sweep;
    }
    drawSegment(missed, Colors.redAccent);
    drawSegment(taken, MyConstants.tealColor);
    drawSegment(left, MyConstants.charcoalColor.withOpacity(0.1));
  }
  @override
  bool shouldRepaint(covariant MultiSegmentPainter oldDelegate) => true;
}