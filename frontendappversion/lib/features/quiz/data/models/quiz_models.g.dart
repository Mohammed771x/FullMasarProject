// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WrongAnswerAdapter extends TypeAdapter<WrongAnswer> {
  @override
  final int typeId = 2;

  @override
  WrongAnswer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WrongAnswer(
      topic: fields[0] as String,
      lesson: fields[1] as String,
      unit: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WrongAnswer obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.topic)
      ..writeByte(1)
      ..write(obj.lesson)
      ..writeByte(2)
      ..write(obj.unit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WrongAnswerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuizResultAdapter extends TypeAdapter<QuizResult> {
  @override
  final int typeId = 3;

  @override
  QuizResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizResult(
      id: fields[0] as String,
      subject: fields[1] as String,
      grade: fields[2] as int,
      track: fields[3] as String,
      unit: fields[4] as String,
      lessons: (fields[5] as List).cast<String>(),
      score: fields[6] as int,
      total: fields[7] as int,
      wrong: (fields[8] as List).cast<WrongAnswer>(),
      durationSec: fields[10] as int,
      createdAt: fields[9] as DateTime?,
      ownerUid: fields[11] == null ? '' : fields[11] as String,
      synced: fields[12] == null ? false : fields[12] as bool,
      askedPerLesson:
          fields[13] == null ? {} : (fields[13] as Map).cast<String, int>(),
      reviewRaw: fields[14] == null ? [] : (fields[14] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, QuizResult obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subject)
      ..writeByte(2)
      ..write(obj.grade)
      ..writeByte(3)
      ..write(obj.track)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.lessons)
      ..writeByte(6)
      ..write(obj.score)
      ..writeByte(7)
      ..write(obj.total)
      ..writeByte(8)
      ..write(obj.wrong)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.durationSec)
      ..writeByte(11)
      ..write(obj.ownerUid)
      ..writeByte(12)
      ..write(obj.synced)
      ..writeByte(13)
      ..write(obj.askedPerLesson)
      ..writeByte(14)
      ..write(obj.reviewRaw);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
