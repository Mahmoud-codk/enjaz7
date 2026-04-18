// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_line.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BusLineAdapter extends TypeAdapter<BusLine> {
  @override
  final int typeId = 1;

  @override
  BusLine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusLine(
      routeNumber: fields[0] as String,
      type: fields[1] as String,
      stops: (fields[2] as List).cast<String>(),
      emptySeats: fields[3] as int,
      lastUsed: fields[4] as DateTime?,
      usageCount: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, BusLine obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.routeNumber)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.stops)
      ..writeByte(3)
      ..write(obj.emptySeats)
      ..writeByte(4)
      ..write(obj.lastUsed)
      ..writeByte(5)
      ..write(obj.usageCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusLineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
