import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../constants/constants.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../blocs/medication_bloc.dart';
import '../blocs/medication_event.dart';
import '../utils/toast_helper.dart';

class MedicationCard extends StatelessWidget {
  final Medication med;
  final List<DoseLog> logs;

  const MedicationCard({Key? key, required this.med, required this.logs})
      : super(key: key);

  String formatTime(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  String formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      // Same day → show only time
      return DateFormat('h:mm a').format(dt);
    } else if (difference.inDays == 1) {
      return "yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    } else {
      // Older than 7 days → show full date
      return DateFormat('MMM d, yyyy h:mm a').format(dt);
    }
  }

  bool _isTakenToday(List<DoseLog> logs) {
    final today = DateTime.now();
    return logs.any(
          (log) =>
      log.takenAt.year == today.year &&
          log.takenAt.month == today.month &&
          log.takenAt.day == today.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MedicationBloc>();
    final sortedLogs = [...logs]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final last = sortedLogs.isEmpty ? null : sortedLogs.first;

    final taken = logs.isEmpty ? 0 : logs.length % med.stripSize;
    final takenToday = _isTakenToday(logs);

    return GestureDetector(
      onTap: () {
        if (takenToday) {
          _showRetakeDialog(context, bloc, med);
        } else {
          _showConfirmDialog(context, bloc, med);
        }
      },
      onLongPress: () {
        _showOptionsDialog(context, bloc, med);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: double.infinity,
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
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Name + Dose
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
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
                          med.dose,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: MyConstants.charcoalColor.withValues(alpha: 0.9),
                          ),
                        ),
                        if (takenToday)
                          Icon(
                            Icons.check_circle,
                            color: MyConstants.tealColor.withValues(alpha: 0.7),
                            size: 30,
                          ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Pill strip
                    buildPillStrip(med.stripSize, taken),

                    const SizedBox(height: 18),

                    // Glassmorphic Info Row
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
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
                          // Next Column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Next",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: MyConstants.charcoalColor.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatTime(med.time),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: MyConstants.charcoalColor,
                                ),
                              ),
                            ],
                          ),

                          // Last Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Last",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: MyConstants.charcoalColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: Text(
                                    last != null
                                        ? formatDateTime(last.takenAt)
                                        : "Never",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: MyConstants.charcoalColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget buildPillStrip(int total, int taken) {
    final displayTaken = taken % total;

    final pills = List.generate(total, (i) {
      final isTaken = i < displayTaken;
      return Container(
        margin: const EdgeInsets.all(4),
        width: 28,
        height: 16,
        decoration: BoxDecoration(
          color: isTaken ? Colors.white.withValues(alpha: 0.2) : MyConstants.yellowColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.6), width: 1.2),
        ),
      );
    });

    final rows = <Widget>[];
    for (int i = 0; i < pills.length; i += 5) {
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: pills.skip(i).take(5).toList(),
        ),
      );
    }

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: rows);
  }

  /// Confirm Taken dialog
  void _showConfirmDialog(
      BuildContext context,
      MedicationBloc bloc,
      Medication med,
      ) {
    _showDialogTemplate(
      context,
      title: 'Taken ${med.name} ${med.dose} ?',
      confirmText: 'Confirm Taken',
      onConfirm: () {
        bloc.add(MarkTakenEvent(med.id, DateTime.now()));
        ToastHelper.showTopRightToast(context, '✅ ${med.name} marked as taken');
      },
    );
  }

  /// Retake confirmation dialog
  void _showRetakeDialog(
      BuildContext context,
      MedicationBloc bloc,
      Medication med,
      ) {
    _showDialogTemplate(
      context,
      title:
      "You've already taken this medication today.\nAre you sure you want to re-take it?",
      confirmText: 'Confirm Taken',
      onConfirm: () {
        bloc.add(MarkTakenEvent(med.id, DateTime.now()));
        ToastHelper.showTopRightToast(context, '✅ ${med.name} marked as taken');
      },
    );
  }

  /// Common dialog builder
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MyConstants.tealColor.withValues(alpha: 0.9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onConfirm();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 20,
                        ),
                        child: Text(
                          confirmText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  /// Edit/Delete dialog
  void _showOptionsDialog(
      BuildContext context,
      MedicationBloc bloc,
      Medication med,
      ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${med.name} ${med.dose}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              MyConstants.tealColor.withValues(alpha: 0.8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              ToastHelper.showTopRightToast(
                                context,
                                '🚧 Edit functionality coming soon!',
                              );
                            },
                            child: const Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              bloc.add(RemoveMedicationEvent(med.id));
                              ToastHelper.showTopRightToast(
                                context,
                                '❌ ${med.name} deleted',
                              );
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
