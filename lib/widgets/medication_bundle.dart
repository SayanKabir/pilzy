import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pilzy/constants/constants.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../blocs/medication_bloc.dart';
import '../blocs/medication_event.dart';
import '../services/settings_service.dart';
import '../utils/toast_helper.dart';
import 'medication_card.dart';

class MedicationBundle extends StatefulWidget {
  final List<Medication> meds;
  final Map<int, List<DoseLog>> allLogs;

  const MedicationBundle({super.key, required this.meds, required this.allLogs});

  @override
  State<MedicationBundle> createState() => _MedicationBundleState();
}

class _MedicationBundleState extends State<MedicationBundle> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  // ─────────────────────────────────────────────────────────────
  // 🧠 BUNDLE LOGIC
  // ─────────────────────────────────────────────────────────────

  String _getBundleName() {
    if (widget.meds.isEmpty) return "Stack";
    final hour = widget.meds.first.scheduledTime.hour;
    if (hour >= 5 && hour < 12) return "Morning Stack";
    if (hour >= 12 && hour < 17) return "Afternoon Stack";
    if (hour >= 17 && hour < 21) return "Evening Stack";
    return "Night Stack";
  }

  void _showTakeAllDialog() {
    SettingsService().vibrate(HapticFeedbackType.heavy);
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0.1)]
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Confirm Bundle",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor)),
                  const SizedBox(height: 8),
                  Text("Mark all ${widget.meds.length} medications as taken?",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MyConstants.charcoalColor.withValues(alpha: 0.6))),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _executeTakeAll();
                    },
                    child: Container(
                      width: double.infinity, height: 55,
                      decoration: BoxDecoration(
                          color: MyConstants.tealColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: MyConstants.tealColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))]
                      ),
                      child: const Center(child: Text("Yes, Take All", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: TextStyle(fontSize: 16, color: MyConstants.charcoalColor.withValues(alpha: 0.7), fontWeight: FontWeight.w700))
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _executeTakeAll() {
    final bloc = context.read<MedicationBloc>();
    final now = DateTime.now();
    final List<int> idsToMark = [];

    for (var med in widget.meds) {
      final logs = widget.allLogs[med.id] ?? [];
      final takenToday = logs.any((l) =>
      l.takenAt.year == now.year && l.takenAt.month == now.month && l.takenAt.day == now.day);

      if (!takenToday) {
        idsToMark.add(med.id);
      }
    }

    if (idsToMark.isNotEmpty) {
      bloc.add(MarkMultipleTakenEvent(idsToMark, now));
      ToastHelper.showTopRightToast(context, '✅ Success: ${idsToMark.length} doses logged');
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    int takenCount = widget.meds.where((m) {
      final logs = widget.allLogs[m.id] ?? [];
      return logs.any((l) => DateUtils.isSameDay(l.takenAt, DateTime.now()));
    }).length;

    bool allDone = takenCount == widget.meds.length;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child),
        );
      },
      child: _isExpanded
          ? _buildExpandedList(allDone, takenCount)
          : _buildStackedUI(allDone, takenCount),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 📚 STACKED UI (The Deck Effect)
  // ─────────────────────────────────────────────────────────────

  Widget _buildStackedUI(bool allDone, int takenCount) {
    return GestureDetector(
      onTap: () {
        SettingsService().vibrate(HapticFeedbackType.medium);
        setState(() => _isExpanded = true);
      },
      onLongPress: () => _showTakeAllDialog(),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Background Card 2
          if (widget.meds.length > 2)
            _buildStackLayer(top: 16, horizontal: 24, opacity: allDone ? 0.15 : 0.1, isDone: allDone),
          // Background Card 1
          if (widget.meds.length > 1)
            _buildStackLayer(top: 8, horizontal: 12, opacity: allDone ? 0.25 : 0.2, isDone: allDone),

          _buildFrontCard(allDone, takenCount),
        ],
      ),
    );
  }

  Widget _buildStackLayer({required double top, required double horizontal, required double opacity, required bool isDone}) {
    return Positioned(
      top: -top, left: horizontal, right: horizontal,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          // ✨ Updated to tealAccent tint
          color: isDone ? Colors.tealAccent.withValues(alpha: opacity) : Colors.white.withValues(alpha: opacity),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: isDone ? Colors.tealAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }

  Widget _buildFrontCard(bool allDone, int takenCount) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: allDone
                  ? [Colors.tealAccent.withValues(alpha: 0.10), Colors.tealAccent.withValues(alpha: 0.05)]
                  : [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.05)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: allDone ? MyConstants.tealColor : Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.layers_rounded, size: 20, color: allDone ? MyConstants.tealColor : MyConstants.charcoalColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 10),
                  Text(_getBundleName().toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor.withValues(alpha: 0.6), letterSpacing: 1.2)),
                  const Spacer(),
                  if (allDone) Icon(Icons.check_circle_rounded, color: MyConstants.tealColor, size: 24),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.meds.map((m) => m.name).join(", "),
                maxLines: 5, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildProgressBadge(takenCount, allDone),
                  _buildSubtleExpandButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 📖 EXPANDED VIEW
  // ─────────────────────────────────────────────────────────────

  Widget _buildExpandedList(bool allDone, int takenCount) {
    return Column(
      key: const ValueKey("expanded_bundle"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            SettingsService().vibrate(HapticFeedbackType.heavy);
            setState(() => _isExpanded = false);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Text("${_getBundleName().toUpperCase()} (EXPANDED)",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor.withValues(alpha: 0.5), letterSpacing: 1)),
                const Spacer(),
                Icon(Icons.unfold_less_rounded, size: 16, color: MyConstants.tealColor),
              ],
            ),
          ),
        ),
        ...widget.meds.map((med) => MedicationCard(
            med: med,
            logs: widget.allLogs[med.id] ?? []
        )),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🔘 UI HELPERS
  // ─────────────────────────────────────────────────────────────

  Widget _buildProgressBadge(int takenCount, bool allDone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$takenCount of ${widget.meds.length} doses taken",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MyConstants.charcoalColor.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(widget.meds.length, (index) {
            bool isTaken = index < takenCount;
            return Container(
              width: 6, height: 6, margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTaken ? MyConstants.tealColor : Colors.white.withValues(alpha: 0.2),
              ),
            );
          }),
        )
      ],
    );
  }

  Widget _buildSubtleExpandButton() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Icon(
          Icons.expand_more_rounded,
          color: MyConstants.charcoalColor.withValues(alpha: 0.4),
          size: 20
      ),
    );
  }
}