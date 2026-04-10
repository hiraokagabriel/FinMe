import 'package:hive/hive.dart';

class LoginModel {
  final String id;
  final String username;
  final String passwordHash; // SHA-256 hex; vazio = sem senha
  final DateTime createdAt;

  LoginModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.createdAt,
  });
}

class LoginModelAdapter extends TypeAdapter<LoginModel> {
  @override
  final int typeId = 7;

  @override
  LoginModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoginModel(
      id:           fields[0] as String,
      username:     fields[1] as String,
      passwordHash: fields[2] as String,
      createdAt:    fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LoginModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.passwordHash)
      ..writeByte(3)
      ..write(obj.createdAt);
  }
}
