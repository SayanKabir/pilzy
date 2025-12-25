import 'package:hive/hive.dart';
import 'medication.dart';
part 'dose_log.g.dart';

@HiveType(typeId: 2)
class DoseLog extends HiveObject {
  @HiveField(0)
  final int medId;

  @HiveField(1)
  final DateTime takenAt;

  DoseLog({
    required this.medId,
    required this.takenAt,
  });
}
