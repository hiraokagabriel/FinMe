import 'package:hive/hive.dart';
import '../domain/account_entity.dart';

// typeId: 4 (3 era conflito com CardModelAdapter — corrigido em #52)
class AccountModel extends HiveObject {
  String id;
  String name;
  int typeIndex;
  double initialBalance;
  int colorValue;
  bool isDefault;

  AccountModel({
    required this.id,
    required this.name,
    required this.typeIndex,
    this.initialBalance = 0.0,
    required this.colorValue,
    this.isDefault = false,
  });

  AccountEntity toEntity() => AccountEntity(
        id: id,
        name: name,
        type: AccountType.values[typeIndex],
        initialBalance: initialBalance,
        colorValue: colorValue,
        isDefault: isDefault,
      );

  static AccountModel fromEntity(AccountEntity e) => AccountModel(
        id: e.id,
        name: e.name,
        typeIndex: e.type.index,
        initialBalance: e.initialBalance,
        colorValue: e.colorValue,
        isDefault: e.isDefault,
      );
}

class AccountModelAdapter extends TypeAdapter<AccountModel> {
  @override
  final int typeId = 4;

  @override
  AccountModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccountModel(
      id:             fields[0] as String,
      name:           fields[1] as String,
      typeIndex:      fields[2] as int,
      initialBalance: (fields[3] as num?)?.toDouble() ?? 0.0,
      colorValue:     fields[4] as int,
      isDefault:      fields[5] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, AccountModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.name)
      ..writeByte(2)..write(obj.typeIndex)
      ..writeByte(3)..write(obj.initialBalance)
      ..writeByte(4)..write(obj.colorValue)
      ..writeByte(5)..write(obj.isDefault);
  }
}
