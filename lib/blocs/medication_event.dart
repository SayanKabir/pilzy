import 'package:equatable/equatable.dart';
import '../models/medication.dart';

abstract class MedicationEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadMedications extends MedicationEvent {}

class AddMedicationEvent extends MedicationEvent {
  final Medication medication;
  AddMedicationEvent(this.medication);

  @override
  List<Object?> get props => [medication];
}

class RemoveMedicationEvent extends MedicationEvent {
  final int medicationId;
  RemoveMedicationEvent(this.medicationId);

  @override
  List<Object?> get props => [medicationId];
}

class MarkTakenEvent extends MedicationEvent {
  final int medicationId;
  final DateTime when;
  MarkTakenEvent(this.medicationId, this.when);

  @override
  List<Object?> get props => [medicationId, when];
}
