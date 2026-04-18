// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StopAdapter extends TypeAdapter<Stop> {
  @override
  final int typeId = 2;

  @override
  Stop read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Stop(
      name: fields[0] as String,
      lat: fields[1] as double,
      lng: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Stop obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.lat)
      ..writeByte(2)
      ..write(obj.lng);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StopAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
