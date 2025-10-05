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

  MedicationBloc({required this.repository, required this.notifications})
      : super(MedicationLoading()) {
    on<LoadMedications>(_onLoad);
    on<AddMedicationEvent>(_onAdd);
    on<RemoveMedicationEvent>(_onRemove);
    on<MarkTakenEvent>(_onMarkTaken);
  }

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

  Future<void> _onAdd(AddMedicationEvent event, Emitter emit) async {
    try {
      await repository.addMedication(event.medication);
      await _scheduleNotificationFor(event.medication);
      add(LoadMedications());
    } catch (e) {
      emit(MedicationError(e.toString()));
    }
  }

  Future<void> _onRemove(RemoveMedicationEvent event, Emitter emit) async {
    try {
      await repository.removeMedication(event.medicationId);
      await notifications.cancel(event.medicationId); // cancel scheduled notification
      add(LoadMedications());
    } catch (e) {
      emit(MedicationError(e.toString()));
    }
  }

  Future<void> _onMarkTaken(MarkTakenEvent event, Emitter emit) async {
    try {
      final log = DoseLog(
        medId: event.medicationId,
        takenAt: event.when,
      );
      await repository.markTaken(log);

      // Reschedule next day's notification
      final currentState = state;
      if (currentState is MedicationLoaded) {
        final med = currentState.meds.firstWhere(
              (m) => m.id == event.medicationId,
        );
        await _scheduleNotificationFor(med);
      }

      add(LoadMedications());
    } catch (e) {
      emit(MedicationError(e.toString()));
    }
  }

  Future<void> _scheduleNotificationFor(Medication med) async {
    final now = DateTime.now();
    final target = med.nextDoseFrom(now);

    const androidDetails = AndroidNotificationDetails(
      'med_channel',
      'Med Reminders',
      channelDescription: 'Medication reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    const platform = NotificationDetails(android: androidDetails);

    await notifications.zonedSchedule(
      med.id, // unique notification id
      'Time to take ${med.name}', // title
      'Dose: ${med.dose}', // body
      tz.TZDateTime.from(target, tz.local), // schedule time
      platform,
      androidScheduleMode: AndroidScheduleMode.alarmClock, // v19+
      matchDateTimeComponents: DateTimeComponents.time, // daily
    );
  }
}
