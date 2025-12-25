import 'package:hive/hive.dart';

part 'medication.g.dart';

@HiveType(typeId: 0)
enum MedicationForm {
  @HiveField(0) pill,
  @HiveField(1) liquid,
  @HiveField(2) other
}

@HiveType(typeId: 3)
enum FrequencyType {
  @HiveField(0) daily,
  @HiveField(1) everyXDays,
  @HiveField(2) weekly
}

@HiveType(typeId: 1)
class Medication extends HiveObject {
  @HiveField(0) final int id;
  @HiveField(1) final String name;
  @HiveField(2) final String dosage;
  @HiveField(3) final DateTime scheduledTime;
  @HiveField(4) final MedicationForm form;

  // Stock tracking
  @HiveField(5) final int? pillsPerStrip;
  @HiveField(6) final double? bottleSizeMl;
  @HiveField(7) final double? mlPerDose;
  @HiveField(8) final String? notes;

  // Frequency logic
  @HiveField(9) final FrequencyType frequencyType;
  @HiveField(10) final int frequencyInterval;
  @HiveField(11) final int timesPerDay;

  // ✨ Course Duration Fields
  @HiveField(12) final DateTime startDate;
  @HiveField(13) final DateTime? endDate; // Null means "Continuous/Chronic"
  @HiveField(14) final DateTime? inventoryRestockDate; // ✨ Track when stock was last reset

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.scheduledTime,
    required this.form,
    required this.startDate, // Required for calculation
    this.endDate,
    this.pillsPerStrip,
    this.bottleSizeMl,
    this.mlPerDose,
    this.notes,
    this.inventoryRestockDate,
    this.frequencyType = FrequencyType.daily,
    this.frequencyInterval = 1,
    this.timesPerDay = 1,
  });

  /// Checks if the medication is currently within its course duration
  bool isActiveOn(DateTime date) {
    final checkDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    if (checkDate.isBefore(start)) return false;

    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (checkDate.isAfter(end)) return false;
    }

    return true;
  }

  /// Calculates the next dose, respecting the end date boundaries
  DateTime? nextDoseFrom(DateTime from) {
    // If the course has already ended, there is no next dose
    if (endDate != null && from.isAfter(endDate!)) return null;

    DateTime next = DateTime(
      from.year,
      from.month,
      from.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    // If scheduled time for today passed, jump to next interval
    if (next.isBefore(from)) {
      switch (frequencyType) {
        case FrequencyType.daily:
          next = next.add(const Duration(days: 1));
          break;
        case FrequencyType.everyXDays:
          next = next.add(Duration(days: frequencyInterval));
          break;
        case FrequencyType.weekly:
          next = next.add(Duration(days: 7 * frequencyInterval));
          break;
      }
    }

    // Check if the calculated next dose exceeds the end date Course
    if (endDate != null && next.isAfter(endDate!)) return null;

    return next;
  }

  String get formDescription {
    switch (form) {
      case MedicationForm.pill: return 'Pill';
      case MedicationForm.liquid: return 'Liquid';
      case MedicationForm.other: return 'Other';
    }
  }

  double? calculateRemainingDoses({required int timesConsumed}) {
    switch (form) {
      case MedicationForm.pill:
        return pillsPerStrip != null ? (pillsPerStrip! - timesConsumed).toDouble() : null;
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