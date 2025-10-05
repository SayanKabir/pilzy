import 'package:hive/hive.dart';

part 'medication.g.dart';

@HiveType(typeId: 0)
class Medication extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String dose;

  @HiveField(3)
  final DateTime time;

  @HiveField(4)
  final int stripSize; // ✅ new field for blister strip size

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
    this.stripSize = 10, // default to 10 pills per strip
  });

  /// Returns the next DateTime when this medication should be taken
  DateTime nextDoseFrom(DateTime from) {
    final todayDose = DateTime(
      from.year,
      from.month,
      from.day,
      time.hour,
      time.minute,
    );

    if (todayDose.isAfter(from)) {
      return todayDose;
    }
    return todayDose.add(const Duration(days: 1));
  }
}
