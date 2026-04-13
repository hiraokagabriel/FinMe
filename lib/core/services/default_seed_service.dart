import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/categories/domain/category_ids.dart';
import '../../features/cards/data/card_model.dart';
import '../../features/accounts/data/account_model.dart';
import '../../features/accounts/domain/account_entity.dart';
import '../../features/transactions/domain/transaction_type.dart';
import '../../features/transactions/domain/recurrence_rule.dart';
import '../../features/transactions/domain/payment_method.dart';
import 'hive_init.dart';
import 'auth_service.dart';
import 'profile_service.dart';

/// Seed mínimo para o perfil ativo — executado apenas se os boxes estiverem vazios.
class DefaultSeedService {
  DefaultSeedService._();
  static final DefaultSeedService instance = DefaultSeedService._();

  Future<void> seedIfEmpty() async {
    final loginId   = AuthService.instance.activeLoginId!;
    final profileId = ProfileService.instance.activeProfileId;

    final catBox = await Hive.openBox<CategoryModel>(
        ProfileService.boxName(HiveInit.categoriesBoxName, loginId, profileId));
    final cdBox  = await Hive.openBox<CardModel>(
        ProfileService.boxName(HiveInit.cardsBoxName, loginId, profileId));
    final acBox  = await Hive.openBox<AccountModel>(
        ProfileService.boxName(HiveInit.accountsBoxName, loginId, profileId));
    final txBox  = await Hive.openBox<TransactionModel>(
        ProfileService.boxName(HiveInit.transactionsBoxName, loginId, profileId));

    // Garante categoria reservada independentemente de o box estar vazio.
    await _ensureBillPaymentCategory(catBox);

    if (catBox.length == 1) {
      // Só a reservada: box estava vazio antes do ensureBillPaymentCategory.
      final seedCategories = [
        CategoryModel(id: 'cat_food',          name: 'Alimentação',  kindIndex: 0, colorValue: 0xFFF44336, iconCodePoint: Icons.restaurant_outlined.codePoint),
        CategoryModel(id: 'cat_transport',     name: 'Transporte',   kindIndex: 0, colorValue: 0xFF2196F3, iconCodePoint: Icons.directions_car_outlined.codePoint),
        CategoryModel(id: 'cat_subscriptions', name: 'Assinaturas',  kindIndex: 0, colorValue: 0xFF607D8B, iconCodePoint: Icons.subscriptions_outlined.codePoint),
        CategoryModel(id: 'cat_salary',        name: 'Salário',      kindIndex: 1, colorValue: 0xFF43A047, iconCodePoint: Icons.account_balance_wallet_outlined.codePoint),
      ];
      await catBox.putAll({for (final c in seedCategories) c.id: c});
    }

    if (cdBox.isEmpty) {
      final seedCards = [
        CardModel(id: 'card_1', name: 'Cartão Principal',   bankName: 'Banco A', typeIndex: 0, dueDay: 10, limit: 10000),
        CardModel(id: 'card_2', name: 'Cartão Secundário',  bankName: 'Banco B', typeIndex: 0, dueDay: 20, limit: 5000),
      ];
      await cdBox.putAll({for (final c in seedCards) c.id: c});
    }

    if (acBox.isEmpty) {
      final seedAccounts = [
        AccountModel(id: 'acc_checking', name: 'Conta Corrente', typeIndex: AccountType.checking.index, initialBalance: 0.0, colorValue: 0xFF01696F, isDefault: true),
        AccountModel(id: 'acc_savings',  name: 'Poupança',       typeIndex: AccountType.savings.index,  initialBalance: 0.0, colorValue: 0xFF43A047, isDefault: false),
        AccountModel(id: 'acc_cash',     name: 'Dinheiro',       typeIndex: AccountType.cash.index,     initialBalance: 0.0, colorValue: 0xFFD19900, isDefault: false),
      ];
      await acBox.putAll({for (final a in seedAccounts) a.id: a});
    }

    if (txBox.isEmpty) {
      final now = DateTime.now();
      final seedTxs = [
        TransactionModel(
          id: 'tx_1', amount: 120.50, currency: 'BRL',
          date: now.subtract(const Duration(days: 1)),
          typeIndex: TransactionType.expense.index,
          paymentMethodIndex: PaymentMethod.creditCard.index,
          description: 'Supermercado', categoryId: 'cat_food',
          cardId: 'card_1', isBoleto: false, isProvisioned: false,
          recurrenceRuleIndex: RecurrenceRule.none.index,
        ),
        TransactionModel(
          id: 'tx_2', amount: 45.00, currency: 'BRL',
          date: now.subtract(const Duration(days: 2)),
          typeIndex: TransactionType.expense.index,
          paymentMethodIndex: PaymentMethod.creditCard.index,
          description: 'Uber', categoryId: 'cat_transport',
          cardId: 'card_2', isBoleto: false, isProvisioned: false,
          recurrenceRuleIndex: RecurrenceRule.none.index,
        ),
        TransactionModel(
          id: 'tx_3', amount: 29.90, currency: 'BRL',
          date: now.subtract(const Duration(days: 5)),
          typeIndex: TransactionType.expense.index,
          paymentMethodIndex: PaymentMethod.creditCard.index,
          description: 'Streaming', categoryId: 'cat_subscriptions',
          cardId: 'card_1', isBoleto: false, isProvisioned: false,
          recurrenceRuleIndex: RecurrenceRule.none.index,
        ),
        TransactionModel(
          id: 'tx_4', amount: 5000.0, currency: 'BRL',
          date: now.subtract(const Duration(days: 10)),
          typeIndex: TransactionType.income.index,
          paymentMethodIndex: PaymentMethod.pix.index,
          description: 'Salário', categoryId: 'cat_salary',
          cardId: null, isBoleto: false, isProvisioned: false,
          recurrenceRuleIndex: RecurrenceRule.none.index,
        ),
      ];
      await txBox.putAll({for (final t in seedTxs) t.id: t});
    }
  }

  /// Garante que a categoria reservada de fatura exista no box.
  /// Idempotente — seguro chamar a cada boot.
  Future<void> _ensureBillPaymentCategory(Box<CategoryModel> catBox) async {
    if (!catBox.containsKey(CategoryIds.billPayment)) {
      await catBox.put(
        CategoryIds.billPayment,
        CategoryModel(
          id:            CategoryIds.billPayment,
          name:          'Fatura',
          kindIndex:     0,
          colorValue:    0xFF607D8B,
          iconCodePoint: Icons.credit_card_outlined.codePoint,
        ),
      );
    }
  }
}
