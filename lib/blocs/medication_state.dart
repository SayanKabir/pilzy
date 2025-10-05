import 'package:equatable/equatable.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';

abstract class MedicationState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MedicationLoading extends MedicationState {}

class MedicationLoaded extends MedicationState {
  final List<Medication> meds;
  final Map<int, List<DoseLog>> logs; // medId -> logs
  MedicationLoaded({required this.meds, required this.logs});

  @override
  List<Object?> get props => [meds, logs];
}

class MedicationError extends MedicationState {
  final String message;
  MedicationError(this.message);

  @override
  List<Object?> get props => [message];
}
