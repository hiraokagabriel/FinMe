import 'package:hive/hive.dart';

import '../domain/category_entity.dart';
import '../domain/category_kind.dart';

class CategoryModel {
  final String id;
  final String name;
  final int kindIndex;
  final int? colorValue;
  // índice 4: iconCodePoint — retrocompatível com registros antigos
  final int? iconCodePoint;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.kindIndex,
    required this.colorValue,
    this.iconCodePoint,
  });

  CategoryEntity toEntity() {
    return CategoryEntity(
      id: id,
      name: name,
      kind: CategoryKind.values[kindIndex],
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
    );
  }

  static CategoryModel fromEntity(CategoryEntity entity) {
    return CategoryModel(
      id: entity.id,
      name: entity.name,
      kindIndex: entity.kind.index,
      colorValue: entity.colorValue,
      iconCodePoint: entity.iconCodePoint,
    );
  }
}

class CategoryModelAdapter extends TypeAdapter<CategoryModel> {
  @override
  final int typeId = 2;

  @override
  CategoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryModel(
      id: fields[0] as String,
      name: fields[1] as String,
      kindIndex: fields[2] as int,
      colorValue: fields[3] as int?,
      // índice 4: opcional — registros antigos não terão esse campo
      iconCodePoint: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.kindIndex)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.iconCodePoint);
  }
}
