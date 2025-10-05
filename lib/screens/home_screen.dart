import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pilzy/constants/constants.dart';
import '../blocs/medication_bloc.dart';
import '../blocs/medication_state.dart';
import '../blocs/medication_event.dart';
// import '../models/medication.dart';
// import '../models/dose_log.dart';
import '../widgets/medication_card.dart';
import 'add_med_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  String formatTime(DateTime dt) {
    return DateFormat.Hm().format(dt); // e.g. "08:30"
  }

  String formatDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    // final bloc = context.read<MedicationBloc>();
    return Scaffold(
      backgroundColor: MyConstants.mintColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              toolbarHeight: 60,
              centerTitle: false,
              backgroundColor: MyConstants.mintColor.withValues(alpha: 0.9), // translucent
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
      ),
      body: BlocBuilder<MedicationBloc, MedicationState>(
        builder: (context, state) {
          if (state is MedicationLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MedicationLoaded) {
            final meds = state.meds;
            if (meds.isEmpty) {
              return Center(child: Text(
                'No medications yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,                    // slightly larger
                  fontWeight: FontWeight.w600,     // semi-bold
                  color: MyConstants.charcoalColor.withValues(alpha: 0.7),
                ),
              )
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, top: 0), // space for FAB
              itemCount: meds.length,
              itemBuilder: (context, idx) {
                final med = meds[idx];
                // final logs = state.logs[med.id] ?? <DoseLog>[];
                // final last = logs.isEmpty ? null : logs.last;

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
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: GestureDetector(
            onTap: () async {
              final added = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddMedScreen()),
              );
              if (added == true) {
                context.read<MedicationBloc>().add(LoadMedications());
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: MyConstants.tealColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  // BoxShadow(
                  //   color: Colors.black.withOpacity(0.1),
                  //   blurRadius: 8,
                  //   offset: const Offset(0, 4),
                  // )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add, color: Colors.white, size: 26),
                  SizedBox(width: 8),
                  Text(
                    "Add Medication",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
}
