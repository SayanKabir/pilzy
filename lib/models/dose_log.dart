import 'package:hive/hive.dart';

part 'dose_log.g.dart';

@HiveType(typeId: 1)
class DoseLog extends HiveObject{
  @HiveField(0)
  final int medId;

  @HiveField(1)
  final DateTime takenAt;

  DoseLog({
    required this.medId,
    required this.takenAt,
  });
}
