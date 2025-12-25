import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/medication_state.dart';
import '../constants/constants.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../blocs/medication_bloc.dart';
import '../blocs/medication_event.dart';
import '../utils/toast_helper.dart';
import '../utils/adherence_utils.dart';

Widget _buildAdherenceHeatmap(MedicationLoaded state) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.05)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: Colors.white.withOpacity(0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("LAST 4 WEEKS ADHERENCE",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                color: MyConstants.charcoalColor.withOpacity(0.5), letterSpacing: 1.5)),
        const SizedBox(height: 15),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 28, // 4 weeks
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemBuilder: (context, index) {
            final date = DateTime.now().subtract(Duration(days: 27 - index));
            final score = AdherenceUtils.calculateAdherenceForDay(date, state.meds, state.logs);
            return _buildHeatmapSquare(score);
          },
        ),
      ],
    ),
  );
}

Widget _buildHeatmapSquare(double score) {
  Color color;
  if (score < 0) color = Colors.white.withOpacity(0.1); // No meds scheduled
  else if (score == 0) color = Colors.redAccent.withOpacity(0.3); // Missed all
  else if (score < 1.0) color = MyConstants.tealColor.withOpacity(0.4); // Partial
  else color = MyConstants.tealColor; // Perfect!

  return Container(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
      boxShadow: score >= 0 ? [
        BoxShadow(color: color.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
      ] : null,
    ),
  );
}