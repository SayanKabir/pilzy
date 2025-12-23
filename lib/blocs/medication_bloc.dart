import 'dart:async';
import 'package:bloc/bloc.dart';
import '../repositories/medication_repository.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import 'medication_event.dart';
import 'medication_state.dart';
import '../services/notification_service.dart'; // Import your updated service

class MedicationBloc extends Bloc<MedicationEvent, MedicationState> {
  final MedicationRepository repository;
  final NotificationService notificationService; // Use the service instead of the raw plugin

  MedicationBloc({
    required this.repository,
    required this.notificationService,
  }) : super(MedicationLoading()) {
    on<LoadMedications>(_onLoad);
    on<AddMedicationEvent>(_onAdd);
    on<RemoveMedicationEvent>(_onRemove);
    on<MarkTakenEvent>(_onMarkTaken);
  }

  // --------------------------------------------------------
  // LOAD
  // --------------------------------------------------------
  Future<void> _onLoad(LoadMedications event, Emitter emit) async {
    emit(MedicationLoading());
    try {
      final meds = await repository.getMedications();
      final logs = await repository.getDoseLogs();

      // Update the daily summary based on current progress
      await _updateDailySummary(meds, logs);

      emit(MedicationLoaded(meds: meds, logs: logs));
    } catch (e) {
      emit(MedicationError(e.toString()));
    }
  }

  // --------------------------------------------------------
  // ADD
  // --------------------------------------------------------
  Future<void> _onAdd(AddMedicationEvent event, Emitter emit) async {
    try {
      await repository.addMedication(event.medication);

      // Use the new paired scheduling (Main + 1hr Missed Reminder)
      await notificationService.scheduleMedicationReminders(
        medId: event.medication.id,
        name: event.medication.name,
        dosage: event.medication.dosage,
        scheduledTime: event.medication.nextDoseFrom(DateTime.now()),
      );

      add(LoadMedications());
    } catch (e) {
      emit(MedicationError(e.toString()));
    }
  }

  // --------------------------------------------------------
  // REMOVE
  // --------------------------------------------------------
  Future<void> _onRemove(RemoveMedicationEvent event, Emitter emit) async {
    try {
      await repository.removeMedication(event.medicationId);

      // Cancel both main and missed notifications
      await notificationService.flutterLocalNotificationsPlugin.cancel(event.medicationId);
      await notificationService.cancelMissedReminder(event.medicationId);

      add(LoadMedications());
    } catch (e) {
      emit(MedicationError(e.toString()));
    }
  }

  // --------------------------------------------------------
  // MARK TAKEN
  // --------------------------------------------------------
  Future<void> _onMarkTaken(MarkTakenEvent event, Emitter emit) async {
    try {
      final currentState = state;
      if (currentState is! MedicationLoaded) return;

      final log = DoseLog(medId: event.medicationId, takenAt: event.when);
      await repository.markTaken(log);

      // 1. Cancel the missed reminder immediately because it was taken
      await notificationService.cancelMissedReminder(event.medicationId);

      // 2. Schedule the next day's paired reminders
      final med = currentState.meds.firstWhere((m) => m.id == event.medicationId);
      await notificationService.scheduleMedicationReminders(
        medId: med.id,
        name: med.name,
        dosage: med.dosage,
        scheduledTime: med.nextDoseFrom(DateTime.now().add(const Duration(minutes: 1))),
      );

      final updatedLogs = Map<int, List<DoseLog>>.from(currentState.logs);
      updatedLogs[event.medicationId] = [...updatedLogs[event.medicationId] ?? [], log];

      // Update summary notification with new counts
      await _updateDailySummary(currentState.meds, updatedLogs);

      emit(MedicationLoaded(meds: currentState.meds, logs: updatedLogs));
    } catch (e) {
      emit(MedicationError(e.toString()));
    }
  }

  // --------------------------------------------------------
  // SUMMARY HELPER
  // --------------------------------------------------------
  Future<void> _updateDailySummary(List<Medication> meds, Map<int, List<DoseLog>> logs) async {
    final now = DateTime.now();
    int takenCount = 0;

    for (var med in meds) {
      final medLogs = logs[med.id] ?? [];
      final takenToday = medLogs.any((l) =>
      l.takenAt.year == now.year &&
          l.takenAt.month == now.month &&
          l.takenAt.day == now.day);
      if (takenToday) takenCount++;
    }

    await notificationService.scheduleDailySummary(
      takenCount: takenCount,
      totalCount: meds.length,
    );
  }
}