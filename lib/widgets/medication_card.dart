import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../constants/constants.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../blocs/medication_bloc.dart';
import '../blocs/medication_event.dart';
import '../utils/toast_helper.dart';

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

  // State for fully collapsible notes
  bool _isNotesExpanded = false;

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

  // --- Helpers ---

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
        HapticFeedback.selectionClick();
        if (takenToday) {
          _showRetakeDialog(context, bloc, med);
        } else {
          _showConfirmDialog(context, bloc, med);
        }
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        _showOptionsDialog(context, bloc, med);
      },
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
                      : MyConstants.charcoalColor.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      Text(med.name, style: TextStyle(fontWeight: FontWeight.w900, color: MyConstants.charcoalColor, fontSize: 22)),
                      Text(med.dosage, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: MyConstants.charcoalColor.withValues(alpha: 0.9))),
                      if (takenToday) Icon(Icons.check_circle, color: MyConstants.tealColor, size: 30),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildMedicationFormDisplay(med, logs),

                  // ✨ FULLY COLLAPSIBLE NOTES
                  if (med.notes != null && med.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildCollapsibleNotes(med.notes!),
                  ],

                  const SizedBox(height: 18),
                  _buildScheduleFooter(med, last),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 📝 FULLY COLLAPSIBLE NOTES UI
  // ─────────────────────────────────────────────────────────────

  Widget _buildCollapsibleNotes(String notes) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _isNotesExpanded = !_isNotesExpanded);
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: MyConstants.charcoalColor.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Text(
                        "INSTRUCTIONS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: MyConstants.charcoalColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: _isNotesExpanded ? 0.5 : 0,
                    child: Icon(Icons.expand_more_rounded,
                        size: 22, color: MyConstants.charcoalColor.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              if (_isNotesExpanded) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    notes,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MyConstants.charcoalColor.withValues(alpha: 0.9),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FOOTER & VISUALS (Remaining unchanged as requested)
  // ─────────────────────────────────────────────────────────────

  Widget _buildScheduleFooter(Medication med, DoseLog? last) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _footerInfoColumn("Next", formatTime(med.scheduledTime), CrossAxisAlignment.start),
          _footerInfoColumn("Last", last != null ? formatDateTime(last.takenAt) : "Never", CrossAxisAlignment.end),
        ],
      ),
    );
  }

  Widget _footerInfoColumn(String label, String value, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MyConstants.charcoalColor.withValues(alpha: 0.7))),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: MyConstants.charcoalColor)),
      ],
    );
  }

  Widget _buildMedicationFormDisplay(Medication med, List<DoseLog> logs) {
    switch (med.form) {
      case MedicationForm.pill:
        final total = med.pillsPerStrip ?? 10;
        final used = logs.length % total;
        return buildPillStrip(total, used, total - used, (logs.length ~/ total) + 1);
      case MedicationForm.liquid:
        final size = med.bottleSizeMl ?? 100.0;
        final perDose = med.mlPerDose ?? 5.0;
        final used = logs.length * perDose;
        return buildLiquidBottle(size, size - (used % size), (used ~/ size) + 1);
      default: return buildOtherType("Other");
    }
  }

  Widget buildPillStrip(int total, int taken, int remaining, int stripNumber) {
    final pills = List.generate(total, (i) {
      final isTaken = i < taken;
      return Container(
        margin: const EdgeInsets.all(5),
        width: 44, height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(isTaken ? 0.05 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(isTaken ? 0.05 : 0.2)),
        ),
        child: isTaken ? null : Center(
          child: Container(
            width: 32, height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [MyConstants.yellowColor, MyConstants.yellowColor.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3, offset: const Offset(0, 2))],
            ),
            child: Stack(children: [
              Positioned(top: 2, left: 6, child: Container(width: 12, height: 3, decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(10)))),
            ]),
          ),
        ),
      );
    });
    final rows = <Widget>[];
    for (int i = 0; i < pills.length; i += 5) {
      rows.add(Row(mainAxisAlignment: MainAxisAlignment.center, children: pills.skip(i).take(5).toList()));
    }
    return Column(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)), child: Column(children: rows)),
      const SizedBox(height: 12),
      Text("$remaining pills left (Strip #$stripNumber)", style: TextStyle(color: MyConstants.charcoalColor, fontSize: 14, fontWeight: FontWeight.w800)),
    ]);
  }

  Widget buildLiquidBottle(double total, double remaining, int bottleNumber) {
    final targetFill = (remaining / total).clamp(0.05, 0.95);
    _fillAnim = Tween<double>(begin: _fillAnim.value, end: targetFill).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0);
    return AnimatedBuilder(
      animation: _fillAnim,
      builder: (_, __) => Column(children: [
        SizedBox(height: 175, width: 90, child: Stack(alignment: Alignment.bottomCenter, children: [
          Container(width: 75, height: 135, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: MyConstants.charcoalColor.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(4, 4))])),
          Positioned(bottom: 6, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 63, height: 123, child: Align(alignment: Alignment.bottomCenter, child: FractionallySizedBox(heightFactor: _fillAnim.value, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [MyConstants.tealColor.withOpacity(0.6), MyConstants.tealColor]), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.4), width: 3))))))))),
          Positioned(left: 22, top: 50, child: Container(width: 6, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white38, Colors.white.withOpacity(0)])))),
          Positioned(top: 25, child: Container(width: 30, height: 20, decoration: BoxDecoration(color: Colors.white10, border: Border.symmetric(vertical: BorderSide(color: MyConstants.charcoalColor.withOpacity(0.2)))))),
          Positioned(top: 10, child: Container(width: 48, height: 18, decoration: BoxDecoration(color: MyConstants.charcoalColor, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))]))),
        ])),
        const SizedBox(height: 12),
        Text("${remaining.toStringAsFixed(1)} ml left (Bottle #$bottleNumber)", style: TextStyle(color: MyConstants.charcoalColor, fontWeight: FontWeight.w800, fontSize: 14)),
      ]),
    );
  }

  Widget buildOtherType(String label) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // UPDATED BACKGROUND CONTAINER
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Slightly increased background fill opacity for better presence
                color: MyConstants.tealColor.withOpacity(0.08),
                // REPLACED HARD WHITE BORDER WITH SOFT TEAL GLOW/SHADOW
                boxShadow: [
                  BoxShadow(
                    color: MyConstants.tealColor.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 0), // Centered glow
                  ),
                  // Optional: very subtle inner white highlight for glass effect
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 5,
                    spreadRadius: -2,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
            ),
            // The 3D Image
            SizedBox(
              width: 110,
              height: 110,
              child: Image.asset(
                'assets/other2.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Label container (unchanged)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: MyConstants.charcoalColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: MyConstants.charcoalColor.withValues(alpha: 0.8),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  void _showConfirmDialog(BuildContext context, MedicationBloc bloc, Medication med) {
    _showDialogTemplate(context, title: 'Taken ${med.name} ${med.dosage}?', confirmText: 'Confirm Taken', onConfirm: () {
      bloc.add(MarkTakenEvent(med.id, DateTime.now()));
      ToastHelper.showTopRightToast(context, '✅ Marked as taken');
    });
  }

  void _showRetakeDialog(BuildContext context, MedicationBloc bloc, Medication med) {
    _showDialogTemplate(context, title: "Already taken today.\nTake again?", confirmText: 'Confirm', onConfirm: () {
      bloc.add(MarkTakenEvent(med.id, DateTime.now()));
      ToastHelper.showTopRightToast(context, '✅ Marked again');
    });
  }

  void _showDialogTemplate(BuildContext context, {required String title, required String confirmText, required VoidCallback onConfirm}) {
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
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor)),
                  const SizedBox(height: 24),
                  _build3DDialogButton(confirmText, MyConstants.tealColor, () { Navigator.pop(ctx); onConfirm(); }),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); }, child: Text('Cancel', style: TextStyle(fontSize: 16, color: MyConstants.charcoalColor.withOpacity(0.7), fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsDialog(BuildContext context, MedicationBloc bloc, Medication med) {
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
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.1)]),
                borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${med.name} ${med.dosage}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor)),
                  const SizedBox(height: 24),
                  _build3DDialogButton('Edit Medication', MyConstants.tealColor, () { Navigator.pop(ctx); ToastHelper.showTopRightToast(context, '🚧 Edit coming soon'); }),
                  const SizedBox(height: 12),
                  _build3DDialogButton('Delete', Colors.redAccent, () { Navigator.pop(ctx); bloc.add(RemoveMedicationEvent(med.id)); ToastHelper.showTopRightToast(context, '❌ Deleted'); }),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); }, child: Text('Close', style: TextStyle(fontSize: 16, color: MyConstants.charcoalColor.withOpacity(0.7), fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DDialogButton(String text, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); onPressed(); },
      child: Container(
        width: double.infinity, height: 55,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
      ),
    );
  }
}