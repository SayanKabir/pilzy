import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pilzy/constants/constants.dart';

import '../blocs/medication_bloc.dart';
import '../blocs/medication_state.dart';
import '../blocs/medication_event.dart';
import '../widgets/medication_card.dart';
import 'add_med_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyConstants.mintColor,
      appBar: _buildAppBar(),
      body: BlocBuilder<MedicationBloc, MedicationState>(
        builder: (context, state) {
          if (state is MedicationLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MedicationLoaded) {
            final meds = state.meds;
            if (meds.isEmpty) {
              return _buildEmptyState();
            }

            // --- Unified Calculation Logic ---
            final now = DateTime.now();
            int takenCount = 0;
            List<String> remainingMeds = [];
            List<String> missedMeds = [];

            for (var med in meds) {
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
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 120, top: 0),
              itemCount: meds.length + 1,
              itemBuilder: (context, idx) {
                if (idx == 0) {
                  return _buildSummaryHeader(
                      context,
                      takenCount,
                      remainingMeds,
                      missedMeds
                  );
                }
                final med = meds[idx - 1];
                return MedicationCard(
                  med: med,
                  logs: state.logs[med.id] ?? [],
                );
              },
            );
          }
          if (state is MedicationError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFAB(context),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // APPBAR
  // ─────────────────────────────────────────────────────────────

  PreferredSize _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AppBar(
            toolbarHeight: 60,
            backgroundColor: MyConstants.mintColor.withValues(alpha: 0.9),
            elevation: 0,
            title: Container(
              width: 90,
              height: 40,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/pilzy4.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3D GLASS SUMMARY HEADER
  // ─────────────────────────────────────────────────────────────

  Widget _buildSummaryHeader(BuildContext context, int taken, List<String> left, List<String> missed) {
    final int total = taken + left.length + missed.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.4),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildSegmentedRing(taken, left.length, missed.length, total),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: MyConstants.charcoalColor,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEEE, MMM d').format(DateTime.now()),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: MyConstants.charcoalColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (missed.isNotEmpty || left.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  if (missed.isNotEmpty)
                    _buildSummaryLabel(
                        "Missed: ${missed.join(', ')}",
                        Colors.redAccent.withValues(alpha: 0.1),
                        Colors.redAccent
                    ),
                  if (left.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildSummaryLabel(
                          "Remaining: ${left.join(', ')}",
                          MyConstants.charcoalColor.withValues(alpha: 0.05),
                          MyConstants.charcoalColor.withValues(alpha: 0.7)
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedRing(int taken, int left, int missed, int total) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: MyConstants.tealColor.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
        ),
        SizedBox(
          width: 85,
          height: 85,
          child: CustomPaint(
            painter: MultiSegmentPainter(
              taken: taken,
              left: left,
              missed: missed,
              total: total,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$taken",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: MyConstants.tealColor,
                  shadows: const [
                    Shadow(color: Colors.black12, offset: Offset(1, 2), blurRadius: 4)
                  ]
              ),
            ),
            Text(
              "OF $total",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: MyConstants.charcoalColor.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryLabel(String text, Color bg, Color textCol) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: textCol),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textCol),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FAB & EMPTY STATE
  // ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_liquid_rounded, size: 80, color: MyConstants.charcoalColor.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(
            'No medications yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: MyConstants.charcoalColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: () async {
            // Providing a physical 'click' feel
            HapticFeedback.lightImpact();

            final added = await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddMedScreen()),
            );
            if (added == true) {
              context.read<MedicationBloc>().add(LoadMedications());
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            decoration: BoxDecoration(
              // 3D Gradient for depth
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MyConstants.tealColor,
                  MyConstants.tealColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              // The requested Teal Shadow
              boxShadow: [
                BoxShadow(
                  color: MyConstants.tealColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 8), // Positioned downwards for a 'floating' effect
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                  shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                ),
                SizedBox(width: 10),
                Text(
                  "Add Medication",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 3D SEGMENTED PAINTER CLASS
// ─────────────────────────────────────────────────────────────

class MultiSegmentPainter extends CustomPainter {
  final int taken, left, missed, total;

  MultiSegmentPainter({required this.taken, required this.left, required this.missed, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final double strokeWidth = 10.0;
    final Rect rect = Offset(strokeWidth / 2, strokeWidth / 2) &
    Size(size.width - strokeWidth, size.height - strokeWidth);

    // 1. Draw Background Track (The Indented Channel)
    final Paint trackPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.28318, false, trackPaint);

    double startAngle = -1.5708; // -90 degrees
    const double spacing = 0.15; // Gap between segments

    void drawSegment(int count, Color color, bool is3D) {
      if (count <= 0) return;
      double sweep = (count / total) * 6.28318;

      final Paint segmentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      if (is3D) {
        // Create 3D Gradient for the segment
        segmentPaint.shader = SweepGradient(
          colors: [color.withValues(alpha: 0.7), color, color.withValues(alpha: 0.7)],
          startAngle: startAngle,
          endAngle: startAngle + sweep,
        ).createShader(rect);
      } else {
        segmentPaint.color = color;
      }

      // Draw segment body
      canvas.drawArc(rect, startAngle + (spacing / 2), sweep - spacing, false, segmentPaint);

      // 2. Add a "Specular Highlight" for 3D Shine
      final Paint highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle + (spacing / 2) + 0.1, sweep - spacing - 0.2, false, highlightPaint);

      startAngle += sweep;
    }

    drawSegment(missed, Colors.redAccent, true);
    drawSegment(taken, MyConstants.tealColor, true);
    drawSegment(left, MyConstants.charcoalColor.withValues(alpha: 0.1), false);
  }

  @override
  bool shouldRepaint(covariant MultiSegmentPainter oldDelegate) =>
      oldDelegate.taken != taken || oldDelegate.left != left || oldDelegate.missed != missed;
}