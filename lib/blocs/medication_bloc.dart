import 'dart:async';
import 'package:bloc/bloc.dart';
import '../repositories/medication_repository.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import 'medication_event.dart';
import 'medication_state.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class MedicationBloc extends Bloc<MedicationEvent, MedicationState> {
  final MedicationRepository repository;
  final FlutterLocalNotificationsPlugin notifications;

  MedicationBloc({
    required this.repository,
    required this.notifications,
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
      await _scheduleNotificationFor(event.medication);
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
      await notifications.cancel(event.medicationId);
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

      // Create and save the log
      final log = DoseLog(
        medId: event.medicationId,
        takenAt: event.when,
      );
      await repository.markTaken(log);

      // Update the logs map with the new log
      final updatedLogs = Map<int, List<DoseLog>>.from(currentState.logs);
      updatedLogs[event.medicationId] = [
        ...updatedLogs[event.medicationId] ?? [],
        log,
      ];

      // Emit updated state immediately
      emit(MedicationLoaded(
        meds: currentState.meds,
        logs: updatedLogs,
      ));

      // Schedule next notification
      final med = currentState.meds.firstWhere((m) => m.id == event.medicationId);
      await _scheduleNotificationFor(med);
    } catch (e) {
      emit(MedicationError(e.toString()));
    }
  }

  // --------------------------------------------------------
  // NOTIFICATION SCHEDULING
  // --------------------------------------------------------
  Future<void> _scheduleNotificationFor(Medication med) async {
    final now = DateTime.now();
    final target = med.nextDoseFrom(now);

    final androidDetails = AndroidNotificationDetails(
      'med_channel',
      'Med Reminders',
      channelDescription: 'Medication reminders',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        _notificationBody(med),
      ),
    );

    final platform = NotificationDetails(android: androidDetails);

    await notifications.zonedSchedule(
      med.id,
      _notificationTitle(med),
      _notificationBody(med),
      tz.TZDateTime.from(target, tz.local),
      platform,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // --------------------------------------------------------
  // Helpers for readable notifications
  // --------------------------------------------------------

  String _notificationTitle(Medication med) {
    switch (med.form) {
      case MedicationForm.pill:
        return 'Time to take ${med.name}';
      case MedicationForm.liquid:
        return 'Take your liquid medication: ${med.name}';
      case MedicationForm.other:
        return 'Medication Reminder: ${med.name}';
    }
  }

  String _notificationBody(Medication med) {
    switch (med.form) {
      case MedicationForm.pill:
        final stripInfo = med.pillsPerStrip != null
            ? ' (Strip size: ${med.pillsPerStrip})'
            : '';
        return 'Dose: ${med.dosage}$stripInfo${_addNotes(med)}';

      case MedicationForm.liquid:
        final volumeInfo = med.bottleSizeMl != null
            ? ' | Bottle: ${med.bottleSizeMl} ml'
            : '';
        final doseInfo = med.mlPerDose != null
            ? 'Take ${med.mlPerDose} ml'
            : 'Dose: ${med.dosage}';
        return '$doseInfo$volumeInfo${_addNotes(med)}';

      case MedicationForm.other:
        return 'Dose: ${med.dosage}${_addNotes(med)}';
    }
  }

  String _addNotes(Medication med) {
    return med.notes != null && med.notes!.isNotEmpty
        ? '\n📝 ${med.notes}'
        : '';
  }
}