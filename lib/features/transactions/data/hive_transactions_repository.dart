import 'package:hive/hive.dart';

import '../../../core/models/date_range.dart';
import 'transaction_model.dart';
import '../domain/transaction_entity.dart';
import 'transactions_repository.dart';

class HiveTransactionsRepository implements TransactionsRepository {
  HiveTransactionsRepository(this._box) {
    _migrateLegacyInstallments();
  }

  final Box<TransactionModel> _box;

  // Migração para transações antigas que tinham installmentCount > 1
  // mas eram armazenadas como um único lançamento com o valor total.
  // Converte cada registro assim em N lançamentos mensais, dividindo o
  // valor em centavos e jogando o resto na última parcela.
  void _migrateLegacyInstallments() {
    final keys = _box.keys.toList(growable: false);

    for (final key in keys) {
      final model = _box.get(key);
      if (model == null) continue;

      final installments = model.installmentCount;
      if (installments == null || installments <= 1) continue;

      // Se já existem registros filhos apontando para este id, assume que
      // já foi migrado.
      final alreadyMigrated = _box.values.any(
        (m) => m.recurrenceSourceId == model.id,
      );
      if (alreadyMigrated) continue;

      final totalCents = (model.amount * 100).round();
      final baseCents  = totalCents ~/ installments;
      final remainder  = totalCents % installments;

      var currentDate = model.date;
      final newModels = <TransactionModel>[];

      for (var i = 0; i < installments; i++) {
        final cents      = baseCents + (i == installments - 1 ? remainder : 0);
        final partAmount = cents / 100.0;
        final newId      = i == 0 ? model.id : '${model.id}_$i';

        newModels.add(TransactionModel(
          id:                  newId,
          amount:              partAmount,
          currency:            model.currency,
          date:                currentDate,
          typeIndex:           model.typeIndex,
          paymentMethodIndex:  model.paymentMethodIndex,
          description:         model.description,
          categoryId:          model.categoryId,
          cardId:              model.cardId,
          accountId:           model.accountId,
          isBoleto:            model.isBoleto,
          isProvisioned:       model.isProvisioned,
          installmentCount:    installments,
          provisionedDueDate:  model.provisionedDueDate,
          recurrenceRuleIndex: 0, // RecurrenceRule.none
          recurrenceSourceId:  model.id,
          toAccountId:         model.toAccountId,
          notes:               model.notes,
          isBillPayment:       model.isBillPayment,
        ));

        // Próxima parcela no mês seguinte.
        currentDate = DateTime(
          currentDate.year,
          currentDate.month + 1,
          currentDate.day,
        );
      }

      if (newModels.isEmpty) continue;

      // Substitui o registro original pela 1ª parcela e adiciona as demais.
      _box.put(key, newModels.first);
      for (var i = 1; i < newModels.length; i++) {
        _box.add(newModels[i]);
      }
    }
  }

  @override
  Future<List<TransactionEntity>> getAll() async {
    return _box.values.map((m) => m.toEntity()).toList(growable: false);
  }

  @override
  Future<List<TransactionEntity>> getByRange(DateRange range) async {
    return _box.values
        .where((m) => range.contains(m.date))
        .map((m) => m.toEntity())
        .toList(growable: false);
  }

  @override
  Future<void> add(TransactionEntity transaction) async {
    final model = TransactionModel.fromEntity(transaction);
    await _box.add(model);
  }

  @override
  Future<void> update(TransactionEntity transaction) async {
    final model = TransactionModel.fromEntity(transaction);
    final key = _findKeyById(transaction.id);
    if (key == null) return;
    await _box.put(key, model);
  }

  @override
  Future<void> remove(String id) async {
    final key = _findKeyById(id);
    if (key == null) return;
    await _box.delete(key);
  }

  dynamic _findKeyById(String id) {
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value != null && value.id == id) {
        return key;
      }
    }
    return null;
  }
}
