// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scholarship_chat.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SchMessageAdapter extends TypeAdapter<SchMessage> {
  @override
  final int typeId = 4;

  @override
  SchMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SchMessage(
      role: fields[0] as String,
      text: fields[1] as String,
      timestamp: fields[2] as DateTime?,
      imagePaths: fields[3] == null ? [] : (fields[3] as List).cast<String>(),
      imageText: fields[4] == null ? '' : fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SchMessage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.role)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.imagePaths)
      ..writeByte(4)
      ..write(obj.imageText);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SchConversationAdapter extends TypeAdapter<SchConversation> {
  @override
  final int typeId = 5;

  @override
  SchConversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SchConversation(
      id: fields[0] as String,
      title: fields[1] as String,
      scholarshipId: fields[2] as String,
      scholarshipName: fields[3] as String,
      messages: (fields[4] as List?)?.cast<SchMessage>(),
      createdAt: fields[5] as DateTime?,
      lastUpdated: fields[6] as DateTime?,
      ownerUid: fields[7] == null ? '' : fields[7] as String,
      synced: fields[8] == null ? false : fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SchConversation obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.scholarshipId)
      ..writeByte(3)
      ..write(obj.scholarshipName)
      ..writeByte(4)
      ..write(obj.messages)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.lastUpdated)
      ..writeByte(7)
      ..write(obj.ownerUid)
      ..writeByte(8)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchConversationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
