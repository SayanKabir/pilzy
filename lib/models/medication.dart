import 'package:hive/hive.dart';

part 'medication.g.dart';

@HiveType(typeId: 0)
enum MedicationForm {
  @HiveField(0)
  pill, // tablets, capsules

  @HiveField(1)
  liquid, // syrups, solutions

  @HiveField(2)
  other, // injections, inhalers, drops, creams, patches, etc.
}

@HiveType(typeId: 1)
class Medication extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String dosage; // e.g., "500mg", "2 pills", "5ml"

  @HiveField(3)
  final DateTime scheduledTime;

  @HiveField(4)
  final MedicationForm form;

  // Stock tracking (optional)
  @HiveField(5)
  final int? pillsPerStrip; // for pills

  @HiveField(6)
  final double? bottleSizeMl; // for liquids

  @HiveField(7)
  final double? mlPerDose; // for liquids

  @HiveField(8)
  final String? notes; // instructions, warnings, or other important info

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.scheduledTime,
    required this.form,
    this.pillsPerStrip,
    this.bottleSizeMl,
    this.mlPerDose,
    this.notes,
  });

  /// Returns the next DateTime when this medication should be taken
  DateTime nextDoseFrom(DateTime from) {
    final todayDose = DateTime(
      from.year,
      from.month,
      from.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    if (todayDose.isAfter(from)) {
      return todayDose;
    }
    return todayDose.add(const Duration(days: 1));
  }

  /// Human-readable form description
  String get formDescription {
    switch (form) {
      case MedicationForm.pill:
        return 'Pill';
      case MedicationForm.liquid:
        return 'Liquid';
      case MedicationForm.other:
        return 'Other';
    }
  }

  /// Calculate remaining stock (if tracking data is available)
  double? calculateRemainingDoses({
    required int timesConsumed,
  }) {
    switch (form) {
      case MedicationForm.pill:
        if (pillsPerStrip != null) {
          return (pillsPerStrip! - timesConsumed).toDouble();
        }
        break;
      case MedicationForm.liquid:
        if (bottleSizeMl != null && mlPerDose != null) {
          return (bottleSizeMl! - (timesConsumed * mlPerDose!)) / mlPerDose!;
        }
        break;
      case MedicationForm.other:
        return null;
    }
    return null;
  }
}