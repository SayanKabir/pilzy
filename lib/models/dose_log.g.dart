// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dose_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DoseLogAdapter extends TypeAdapter<DoseLog> {
  @override
  final int typeId = 2;

  @override
  DoseLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DoseLog(
      medId: fields[0] as int,
      takenAt: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DoseLog obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.medId)
      ..writeByte(1)
      ..write(obj.takenAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoseLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
