// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_answer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedAnswerAdapter extends TypeAdapter<SavedAnswer> {
  @override
  final int typeId = 6;

  @override
  SavedAnswer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedAnswer(
      id: fields[0] as String,
      ownerUid: fields[1] as String,
      section: fields[2] as String,
      subject: fields[3] as String,
      text: fields[4] as String,
      grade: fields[6] == null ? 0 : fields[6] as int,
      track: fields[7] == null ? '' : fields[7] as String,
      savedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedAnswer obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ownerUid)
      ..writeByte(2)
      ..write(obj.section)
      ..writeByte(3)
      ..write(obj.subject)
      ..writeByte(4)
      ..write(obj.text)
      ..writeByte(5)
      ..write(obj.savedAt)
      ..writeByte(6)
      ..write(obj.grade)
      ..writeByte(7)
      ..write(obj.track);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedAnswerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
