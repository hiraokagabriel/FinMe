import 'package:hive/hive.dart';

import '../../../core/models/money.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_type.dart';
import '../domain/payment_method.dart';

class TransactionModel {
  final String id;
  final double amount;
  final String currency;
  final DateTime date;
  final int typeIndex;
  final int paymentMethodIndex;
  final String? description;
  final String categoryId;
  final String? cardId;
  final bool isBoleto;
  final bool isProvisioned;
  // M3 - provisionamento avancado (indices 11 e 12 - retrocompativeis)
  final int? installmentCount;
  final DateTime? provisionedDueDate;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.currency,
    required this.date,
    required this.typeIndex,
    required this.paymentMethodIndex,
    required this.description,
    required this.categoryId,
    required this.cardId,
    required this.isBoleto,
    required this.isProvisioned,
    this.installmentCount,
    this.provisionedDueDate,
  });

  TransactionEntity toEntity() {
    return TransactionEntity(
      id: id,
      amount: Money(amount, currency: currency),
      date: date,
      type: TransactionType.values[typeIndex],
      paymentMethod: PaymentMethod.values[paymentMethodIndex],
      description: description,
      categoryId: categoryId,
      cardId: cardId,
      isBoleto: isBoleto,
      isProvisioned: isProvisioned,
      installmentCount: installmentCount,
      provisionedDueDate: provisionedDueDate,
    );
  }

  static TransactionModel fromEntity(TransactionEntity entity) {
    return TransactionModel(
      id: entity.id,
      amount: entity.amount.amount,
      currency: entity.amount.currency,
      date: entity.date,
      typeIndex: entity.type.index,
      paymentMethodIndex: entity.paymentMethod.index,
      description: entity.description,
      categoryId: entity.categoryId,
      cardId: entity.cardId,
      isBoleto: entity.isBoleto,
      isProvisioned: entity.isProvisioned,
      installmentCount: entity.installmentCount,
      provisionedDueDate: entity.provisionedDueDate,
    );
  }
}

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 1;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      amount: fields[1] as double,
      currency: fields[2] as String,
      date: fields[3] as DateTime,
      typeIndex: fields[4] as int,
      paymentMethodIndex: fields[5] as int,
      description: fields[6] as String?,
      categoryId: fields[7] as String,
      cardId: fields[8] as String?,
      isBoleto: fields[9] as bool,
      isProvisioned: fields[10] as bool,
      // indices 11 e 12: opcionais - registros antigos nao terao esses campos
      installmentCount: fields[11] as int?,
      provisionedDueDate: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.currency)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.typeIndex)
      ..writeByte(5)
      ..write(obj.paymentMethodIndex)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.categoryId)
      ..writeByte(8)
      ..write(obj.cardId)
      ..writeByte(9)
      ..write(obj.isBoleto)
      ..writeByte(10)
      ..write(obj.isProvisioned)
      ..writeByte(11)
      ..write(obj.installmentCount)
      ..writeByte(12)
      ..write(obj.provisionedDueDate);
  }
}
