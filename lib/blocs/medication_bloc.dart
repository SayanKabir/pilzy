import 'dart:async';
import 'package:bloc/bloc.dart';
import '../repositories/medication_repository.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import 'medication_event.dart';
import 'medication_state.dart';
import '../services/notification_service.dart';

class MedicationBloc extends Bloc<MedicationEvent, MedicationState> {
  final MedicationRepository repository;
  final NotificationService notificationService;

  MedicationBloc({
    required this.repository,
    required this.notificationService,
  }) : super(MedicationLoading()) {
    on<LoadMedications>(_onLoad);
    on<AddMedicationEvent>(_onAdd);
    on<RemoveMedicationEvent>(_onRemove);
    on<MarkTakenEvent>(_onMarkTaken);
    on<MarkMultipleTakenEvent>(_onMarkMultipleTaken);
    on<RestockMedicationEvent>(_onRestock);
    on<UpdateMedicationDurationEvent>(_onUpdateDuration);
  }

  // ─────────────────────────────────────────────────────────────
  // 📥 LOAD MEDICATIONS
  // ─────────────────────────────────────────────────────────────
  Future<void> _onLoad(LoadMedications event, Emitter<MedicationState> emit) async {
    emit(MedicationLoading());
    try {
      final meds = await repository.getMedications();
      final logs = await repository.getDoseLogs();

      await _updateDailySummary(meds, logs);
      emit(MedicationLoaded(meds: meds, logs: logs));
    } catch (e) {
      emit(MedicationError("Failed to load medications: ${e.toString()}"));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ➕ ADD MEDICATION
  // ─────────────────────────────────────────────────────────────
  Future<void> _onAdd(AddMedicationEvent event, Emitter<MedicationState> emit) async {
    try {
      await repository.addMedication(event.medication);

      // Respect start dates and course duration in notifications
      final nextDose = event.medication.nextDoseFrom(DateTime.now());
      if (nextDose != null) {
        await notificationService.scheduleMedicationReminders(
          medId: event.medication.id,
          name: event.medication.name,
          dosage: event.medication.dosage,
          scheduledTime: nextDose,
        );
      }

      add(LoadMedications());
    } catch (e) {
      emit(MedicationError("Could not add medication: ${e.toString()}"));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🗑️ REMOVE MEDICATION
  // ─────────────────────────────────────────────────────────────
  Future<void> _onRemove(RemoveMedicationEvent event, Emitter<MedicationState> emit) async {
    try {
      await repository.removeMedication(event.medicationId);

      await notificationService.flutterLocalNotificationsPlugin.cancel(event.medicationId);
      await notificationService.cancelMissedReminder(event.medicationId);

      add(LoadMedications());
    } catch (e) {
      emit(MedicationError("Failed to remove medication: ${e.toString()}"));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ MARK DOSE AS TAKEN
  // ─────────────────────────────────────────────────────────────
  Future<void> _onMarkTaken(MarkTakenEvent event, Emitter<MedicationState> emit) async {
    try {
      final currentState = state;
      if (currentState is! MedicationLoaded) return;

      final log = DoseLog(medId: event.medicationId, takenAt: event.when);
      await repository.markTaken(log);

      await notificationService.cancelMissedReminder(event.medicationId);

      final med = currentState.meds.firstWhere((m) => m.id == event.medicationId);
      final nextDoseTime = med.nextDoseFrom(DateTime.now().add(const Duration(minutes: 1)));

      if (nextDoseTime != null) {
        await notificationService.scheduleMedicationReminders(
          medId: med.id,
          name: med.name,
          dosage: med.dosage,
          scheduledTime: nextDoseTime,
        );
      }

      final updatedLogs = Map<int, List<DoseLog>>.from(currentState.logs);
      updatedLogs[event.medicationId] = [...updatedLogs[event.medicationId] ?? [], log];

      await _updateDailySummary(currentState.meds, updatedLogs);
      emit(MedicationLoaded(meds: currentState.meds, logs: updatedLogs));
    } catch (e) {
      emit(MedicationError("Failed to log dose: ${e.toString()}"));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ MARK MULTIPLE DOSES AS TAKEN (Atomic Batch)
  // ─────────────────────────────────────────────────────────────
  Future<void> _onMarkMultipleTaken(MarkMultipleTakenEvent event, Emitter<MedicationState> emit) async {
    try {
      final currentState = state;
      if (currentState is! MedicationLoaded) return;

      final updatedLogs = Map<int, List<DoseLog>>.from(currentState.logs);

      for (int medId in event.medicationIds) {
        final log = DoseLog(medId: medId, takenAt: event.when);
        await repository.markTaken(log);
        await notificationService.cancelMissedReminder(medId);

        final med = currentState.meds.firstWhere((m) => m.id == medId);
        final nextDoseTime = med.nextDoseFrom(DateTime.now().add(const Duration(minutes: 1)));

        if (nextDoseTime != null) {
          await notificationService.scheduleMedicationReminders(
            medId: med.id,
            name: med.name,
            dosage: med.dosage,
            scheduledTime: nextDoseTime,
          );
        }

        updatedLogs[medId] = [...updatedLogs[medId] ?? [], log];
      }

      await _updateDailySummary(currentState.meds, updatedLogs);
      emit(MedicationLoaded(meds: currentState.meds, logs: updatedLogs));
    } catch (e) {
      emit(MedicationError("Failed to log multiple doses: ${e.toString()}"));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 📦 RESTOCK INVENTORY
  // ─────────────────────────────────────────────────────────────
  Future<void> _onRestock(RestockMedicationEvent event, Emitter<MedicationState> emit) async {
    try {
      final currentState = state;
      if (currentState is! MedicationLoaded) return;
      final med = currentState.meds.firstWhere((m) => m.id == event.medicationId);
      
      // Update with new Restock Date
      final updatedMed = Medication(
        id: med.id,
        name: med.name,
        dosage: med.dosage,
        scheduledTime: med.scheduledTime,
        form: med.form,
        startDate: med.startDate,
        endDate: med.endDate,
        pillsPerStrip: med.pillsPerStrip,
        bottleSizeMl: med.bottleSizeMl,
        mlPerDose: med.mlPerDose,
        inventoryRestockDate: DateTime.now(), // ✨ Reset stock tracking
        notes: med.notes,
        frequencyType: med.frequencyType,
        frequencyInterval: med.frequencyInterval,
        timesPerDay: med.timesPerDay,
      );

      await repository.updateMedication(updatedMed);
      add(LoadMedications());
    } catch (e) {
      emit(MedicationError("Failed to restock medication: ${e.toString()}"));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🔄 UPDATE DURATION (Soft Expiry Management)
  // ─────────────────────────────────────────────────────────────
  Future<void> _onUpdateDuration(UpdateMedicationDurationEvent event, Emitter<MedicationState> emit) async {
    try {
      if (event.shouldContinue) {
        // Create a NEW instance with the updated field instead of modifying the old one
        final med = event.medication;
        final updatedMed = Medication(
          id: med.id,
          name: med.name,
          dosage: med.dosage,
          scheduledTime: med.scheduledTime,
          form: med.form,
          startDate: med.startDate,
          endDate: null, // ✨ This effectively makes it chronic/continuous
          pillsPerStrip: med.pillsPerStrip,
          bottleSizeMl: med.bottleSizeMl,
          mlPerDose: med.mlPerDose,
          inventoryRestockDate: med.inventoryRestockDate,
          notes: med.notes,
          frequencyType: med.frequencyType,
          frequencyInterval: med.frequencyInterval,
          timesPerDay: med.timesPerDay,
        );

        await repository.updateMedication(updatedMed);
        add(LoadMedications());
      } else {
        add(RemoveMedicationEvent(event.medication.id));
      }
    } catch (e) {
      emit(MedicationError("Failed to update medication course: ${e.toString()}"));
    }
  }


  // ─────────────────────────────────────────────────────────────
  // 📊 ADHERENCE SUMMARY HELPER
  // ─────────────────────────────────────────────────────────────
  Future<void> _updateDailySummary(List<Medication> meds, Map<int, List<DoseLog>> logs) async {
    final now = DateTime.now();
    int takenCount = 0;

    // Filter only currently active medications for summary logic
    final activeMeds = meds.where((m) => m.isActiveOn(now)).toList();
    int totalCount = activeMeds.length;

    for (var med in activeMeds) {
      final medLogs = logs[med.id] ?? [];
      final takenToday = medLogs.any((l) =>
      l.takenAt.year == now.year &&
          l.takenAt.month == now.month &&
          l.takenAt.day == now.day);
      if (takenToday) takenCount++;
    }

    final double score = totalCount > 0 ? (takenCount / totalCount) : 0.0;
    String message;

    if (totalCount == 0) {
      message = "No medications scheduled for today. Rest well!";
    } else if (score == 1.0) {
      message = "Perfect day! You've taken all $takenCount doses. 🌟";
    } else {
      message = "You've taken $takenCount/$totalCount doses today.";
    }

    await notificationService.scheduleDailySummary(
      takenCount: takenCount,
      totalCount: totalCount,
      customMessage: message,
    );
  }
}