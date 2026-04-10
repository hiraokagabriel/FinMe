import 'package:hive/hive.dart';

class ProfileModel {
  final String id;
  final String loginId;
  final String name;
  final String avatarEmoji;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.loginId,
    required this.name,
    required this.avatarEmoji,
    required this.createdAt,
  });
}

class ProfileModelAdapter extends TypeAdapter<ProfileModel> {
  @override
  final int typeId = 8;

  @override
  ProfileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProfileModel(
      id:          fields[0] as String,
      loginId:     fields[1] as String,
      name:        fields[2] as String,
      avatarEmoji: fields[3] as String,
      createdAt:   fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ProfileModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.loginId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.avatarEmoji)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}
