import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import '../constants/constants.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../blocs/medication_bloc.dart';
import '../blocs/medication_event.dart';
import '../utils/toast_helper.dart';

// ─────────────────────────────────────────────────────────────
// NOW STATEFUL (for bottle animation)
// ─────────────────────────────────────────────────────────────

class MedicationCard extends StatefulWidget {
  final Medication med;
  final List<DoseLog> logs;

  const MedicationCard({super.key, required this.med, required this.logs});

  @override
  State<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<MedicationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fillAnim = Tween<double>(begin: 1, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

  String formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('h:mm a').format(dt);
    if (diff.inDays == 1) return "yesterday";
    if (diff.inDays < 7) return "${diff.inDays} days ago";
    return DateFormat('MMM d, yyyy h:mm a').format(dt);
  }

  bool _isTakenToday(List<DoseLog> logs) {
    final today = DateTime.now();
    return logs.any((log) =>
    log.takenAt.year == today.year &&
        log.takenAt.month == today.month &&
        log.takenAt.day == today.day);
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.med;
    final logs = widget.logs;
    final bloc = context.read<MedicationBloc>();

    final sortedLogs = [...logs]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final last = sortedLogs.isEmpty ? null : sortedLogs.first;
    final takenToday = _isTakenToday(logs);

    return GestureDetector(
      onTap: () {
        if (takenToday) {
          _showRetakeDialog(context, bloc, med);
        } else {
          _showConfirmDialog(context, bloc, med);
        }
      },
      onLongPress: () => _showOptionsDialog(context, bloc, med),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: takenToday
                      ? MyConstants.tealColor.withValues(alpha: 0.7)
                      : MyConstants.charcoalColor,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Name Row
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        med.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: MyConstants.charcoalColor,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        med.dosage,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: MyConstants.charcoalColor.withValues(alpha: 0.9),
                        ),
                      ),
                      if (takenToday)
                        Icon(Icons.check_circle,
                            color: MyConstants.tealColor.withValues(alpha: 0.7),
                            size: 30),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _buildMedicationFormDisplay(med, logs),

                  const SizedBox(height: 18),

                  // Last + Next Row (unchanged)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoLabel("Next"),
                            Text(formatTime(med.scheduledTime),
                                style: _infoValueStyle()),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _infoLabel("Last"),
                            Text(
                              last != null ? formatDateTime(last.takenAt) : "Never",
                              style: _infoValueStyle(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _infoValueStyle() => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: MyConstants.charcoalColor,
  );

  Text _infoLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: MyConstants.charcoalColor.withValues(alpha: 0.7),
    ),
  );

  // ─────────────────────────────────────────────────────────────
  // MEDICATION FORM VISUAL SELECTOR
  // ─────────────────────────────────────────────────────────────
  Widget _buildMedicationFormDisplay(Medication med, List<DoseLog> logs) {
    switch (med.form) {
      case MedicationForm.pill:
        final total = med.pillsPerStrip ?? 10;
        final used = logs.length % total;
        final remaining = total - used;
        final stripNumber = (logs.length ~/ total) + 1;
        return buildPillStrip(total, used, remaining, stripNumber);

      case MedicationForm.liquid:
        final size = med.bottleSizeMl ?? 100.0;
        final perDose = med.mlPerDose ?? 5.0;
        final used = logs.length * perDose;
        final remaining = size - (used % size);
        final bottleNumber = (used ~/ size) + 1;
        return buildLiquidBottle(size, remaining, bottleNumber);

      default:
        return buildOtherType("Other");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PILL STRIP VISUAL (unchanged)
  // ─────────────────────────────────────────────────────────────

  Widget buildPillStrip(int total, int taken, int remaining, int stripNumber) {
    final pills = List.generate(total, (i) {
      final isEmpty = i < taken;
      return Container(
        margin: const EdgeInsets.all(3),
        width: 32,
        height: 20,
        decoration: BoxDecoration(
          color: isEmpty ? Colors.transparent : MyConstants.yellowColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEmpty
                ? Colors.grey.withOpacity(0.4)
                : Colors.black.withOpacity(0.6),
            width: 1.5,
          ),
        ),
      );
    });

    // Break into rows of 5
    final rows = <Widget>[];
    for (int i = 0; i < pills.length; i += 5) {
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: pills.skip(i).take(5).toList(),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...rows,
        const SizedBox(height: 8),
        Text(
          "$remaining remaining (Strip #$stripNumber)",
          style: TextStyle(
            color: MyConstants.charcoalColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ✨ MINIMAL & ANIMATED BOTTLE
  // ─────────────────────────────────────────────────────────────

  Widget buildLiquidBottle(double total, double remaining, int bottleNumber) {
    final targetFill = (remaining / total).clamp(0.0, 0.93);

    _fillAnim = Tween<double>(
      begin: _fillAnim.value,
      end: targetFill,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward(from: 0);

    return AnimatedBuilder(
      animation: _fillAnim,
      builder: (_, __) {
        return Column(
          children: [
            SizedBox(
              height: 150,
              width: 70,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Bottle Body
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 70,
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: MyConstants.charcoalColor.withOpacity(0.55),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24), // softer top curve
                          bottom: Radius.circular(18),
                        ),
                      ),
                    ),
                  ),

                  // **Neck** (narrower section)
                  Positioned(
                    top: 4,
                    child: Container(
                      width: 42,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: MyConstants.charcoalColor.withOpacity(0.55),
                            width: 2,
                          ),
                          left: BorderSide(
                            color: MyConstants.charcoalColor.withOpacity(0.55),
                            width: 2,
                          ),
                          right: BorderSide(
                            color: MyConstants.charcoalColor.withOpacity(0.55),
                            width: 2,
                          ),
                          // ❗ NO bottom border → smooth merge into bottle
                        ),
                      ),
                    ),
                  ),


                  // Liquid fill
                  Positioned.fill(
                    bottom: 0,
                    child: FractionallySizedBox(
                      heightFactor: _fillAnim.value,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MyConstants.tealColor.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(14),
                            top: Radius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Cap
                  Positioned(
                    top: -10,
                    child: Container(
                      width: 46,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: MyConstants.charcoalColor.withOpacity(.45),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "${remaining.toStringAsFixed(1)} ml remaining (Bottle #$bottleNumber)",
              style: TextStyle(
                color: MyConstants.charcoalColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildOtherType(String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          height: 70,
          child: SvgPicture.asset(
            'assets/other.svg',
            width: 90,
            height: 70,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              MyConstants.charcoalColor.withValues(alpha: 0.72), // softer than before
              BlendMode.srcIn,
            ),
          ),

        ),

        const SizedBox(height: 8),

        Text(
          label,
          style: TextStyle(
            color: MyConstants.charcoalColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }


  // dialogs stay exactly like your original
  void _showConfirmDialog(BuildContext context, MedicationBloc bloc, Medication med) {
    _showDialogTemplate(
      context,
      title: 'Taken ${med.name} ${med.dosage}?',
      confirmText: 'Confirm Taken',
      onConfirm: () {
        bloc.add(MarkTakenEvent(med.id, DateTime.now()));
        ToastHelper.showTopRightToast(context, '✅ ${med.name} marked as taken');
      },
    );
  }

  void _showRetakeDialog(BuildContext context, MedicationBloc bloc, Medication med) {
    _showDialogTemplate(
      context,
      title: "You've already taken this today.\nTake again?",
      confirmText: 'Confirm Taken',
      onConfirm: () {
        bloc.add(MarkTakenEvent(med.id, DateTime.now()));
        ToastHelper.showTopRightToast(context, '✅ ${med.name} marked again');
      },
    );
  }

  void _showDialogTemplate(
      BuildContext context, {
        required String title,
        required String confirmText,
        required VoidCallback onConfirm,
      }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MyConstants.tealColor.withValues(alpha: 0.9),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onConfirm();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20),
                        child: Text(
                          confirmText,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOptionsDialog(BuildContext context, MedicationBloc bloc, Medication med) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${med.name} ${med.dosage}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MyConstants.tealColor.withValues(alpha: 0.8),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              ToastHelper.showTopRightToast(context, '🚧 Edit coming soon');
                            },
                            child: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              bloc.add(RemoveMedicationEvent(med.id));
                              ToastHelper.showTopRightToast(context, '❌ Deleted');
                            },
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
