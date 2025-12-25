import 'package:equatable/equatable.dart';
import '../models/medication.dart';

abstract class MedicationEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Initial event to fetch all medications and logs from Hive.
class LoadMedications extends MedicationEvent {}

/// Triggered when a new medication is created.
class AddMedicationEvent extends MedicationEvent {
  final Medication medication;
  AddMedicationEvent(this.medication);

  @override
  List<Object?> get props => [medication];
}

/// Triggered when a user deletes a medication.
class RemoveMedicationEvent extends MedicationEvent {
  final int medicationId;
  RemoveMedicationEvent(this.medicationId);

  @override
  List<Object?> get props => [medicationId];
}

/// Triggered when a user confirms they have taken a dose.
class MarkTakenEvent extends MedicationEvent {
  final int medicationId;
  final DateTime when;
  MarkTakenEvent(this.medicationId, this.when);

  @override
  List<Object?> get props => [medicationId, when];
}

/// Triggered when a user confirms they have taken multiple doses at once.
class MarkMultipleTakenEvent extends MedicationEvent {
  final List<int> medicationIds;
  final DateTime when;
  MarkMultipleTakenEvent(this.medicationIds, this.when);

  @override
  List<Object?> get props => [medicationIds, when];
}

// ─────────────────────────────────────────────────────────────
// ✨ NEW EVENTS FOR INVENTORY & EXPIRY
// ─────────────────────────────────────────────────────────────

/// Triggered when a user restocks a medication.
/// Resets the visual counters for pills/liquid.
class RestockMedicationEvent extends MedicationEvent {
  final int medicationId;
  RestockMedicationEvent(this.medicationId);

  @override
  List<Object?> get props => [medicationId];
}

/// Triggered when a medication course reaches its end date.
/// If [shouldContinue] is true, the medication becomes chronic (endDate = null).
/// If false, the medication is removed.
class UpdateMedicationDurationEvent extends MedicationEvent {
  final Medication medication;
  final bool shouldContinue;

  UpdateMedicationDurationEvent(this.medication, {required this.shouldContinue});

  @override
  List<Object?> get props => [medication, shouldContinue];
}