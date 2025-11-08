// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicationAdapter extends TypeAdapter<Medication> {
  @override
  final int typeId = 1;

  @override
  Medication read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medication(
      id: fields[0] as int,
      name: fields[1] as String,
      dosage: fields[2] as String,
      scheduledTime: fields[3] as DateTime,
      form: fields[4] as MedicationForm,
      pillsPerStrip: fields[5] as int?,
      bottleSizeMl: fields[6] as double?,
      mlPerDose: fields[7] as double?,
      notes: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Medication obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dosage)
      ..writeByte(3)
      ..write(obj.scheduledTime)
      ..writeByte(4)
      ..write(obj.form)
      ..writeByte(5)
      ..write(obj.pillsPerStrip)
      ..writeByte(6)
      ..write(obj.bottleSizeMl)
      ..writeByte(7)
      ..write(obj.mlPerDose)
      ..writeByte(8)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicationFormAdapter extends TypeAdapter<MedicationForm> {
  @override
  final int typeId = 0;

  @override
  MedicationForm read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MedicationForm.pill;
      case 1:
        return MedicationForm.liquid;
      case 2:
        return MedicationForm.other;
      default:
        return MedicationForm.pill;
    }
  }

  @override
  void write(BinaryWriter writer, MedicationForm obj) {
    switch (obj) {
      case MedicationForm.pill:
        writer.writeByte(0);
        break;
      case MedicationForm.liquid:
        writer.writeByte(1);
        break;
      case MedicationForm.other:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationFormAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
