import 'package:hive/hive.dart';

import '../domain/card_entity.dart';
import '../domain/card_type.dart';

class CardModel {
  final String id;
  final String name;
  final String bankName;
  final int typeIndex;
  final int dueDay;
  final double? limit;

  CardModel({
    required this.id,
    required this.name,
    required this.bankName,
    required this.typeIndex,
    required this.dueDay,
    required this.limit,
  });

  CardEntity toEntity() {
    return CardEntity(
      id: id,
      name: name,
      bankName: bankName,
      type: CardType.values[typeIndex],
      dueDay: dueDay,
      limit: limit,
    );
  }

  static CardModel fromEntity(CardEntity entity) {
    return CardModel(
      id: entity.id,
      name: entity.name,
      bankName: entity.bankName,
      typeIndex: entity.type.index,
      dueDay: entity.dueDay,
      limit: entity.limit,
    );
  }
}

class CardModelAdapter extends TypeAdapter<CardModel> {
  @override
  final int typeId = 3;

  @override
  CardModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CardModel(
      id: fields[0] as String,
      name: fields[1] as String,
      bankName: fields[2] as String,
      typeIndex: fields[3] as int,
      dueDay: fields[4] as int,
      limit: fields[5] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, CardModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.bankName)
      ..writeByte(3)
      ..write(obj.typeIndex)
      ..writeByte(4)
      ..write(obj.dueDay)
      ..writeByte(5)
      ..write(obj.limit);
  }
}
