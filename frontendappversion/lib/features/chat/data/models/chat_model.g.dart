// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 0;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      role: fields[0] as String,
      text: fields[1] as String,
      refs: (fields[2] as List).cast<String>(),
      timestamp: fields[3] as DateTime?,
      imagePath: fields[4] == null ? '' : fields[4] as String,
      imagePaths: fields[5] == null ? [] : (fields[5] as List).cast<String>(),
      imageText: fields[6] == null ? '' : fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.role)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.refs)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.imagePaths)
      ..writeByte(6)
      ..write(obj.imageText);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatConversationAdapter extends TypeAdapter<ChatConversation> {
  @override
  final int typeId = 1;

  @override
  ChatConversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatConversation(
      id: fields[0] as String,
      title: fields[1] as String,
      subject: fields[2] as String,
      mode: fields[3] as String,
      messages: (fields[4] as List).cast<ChatMessage>(),
      createdAt: fields[5] as DateTime?,
      lastUpdated: fields[6] as DateTime?,
      grade: fields[7] == null ? 3 : fields[7] as int,
      track: fields[8] == null ? 'علمي' : fields[8] as String,
      branch: fields[9] == null ? '' : fields[9] as String,
      ownerUid: fields[10] == null ? '' : fields[10] as String,
      unit: fields[11] == null ? '' : fields[11] as String,
      lesson: fields[12] == null ? '' : fields[12] as String,
      contentMode: fields[13] == null ? '' : fields[13] as String,
      pages: fields[14] == null ? [] : (fields[14] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatConversation obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.subject)
      ..writeByte(3)
      ..write(obj.mode)
      ..writeByte(4)
      ..write(obj.messages)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.lastUpdated)
      ..writeByte(7)
      ..write(obj.grade)
      ..writeByte(8)
      ..write(obj.track)
      ..writeByte(9)
      ..write(obj.branch)
      ..writeByte(10)
      ..write(obj.ownerUid)
      ..writeByte(11)
      ..write(obj.unit)
      ..writeByte(12)
      ..write(obj.lesson)
      ..writeByte(13)
      ..write(obj.contentMode)
      ..writeByte(14)
      ..write(obj.pages);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatConversationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
