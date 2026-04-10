import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/cards/data/card_model.dart';
import '../../features/accounts/data/account_model.dart';
import '../../features/accounts/domain/account_entity.dart';
import '../../features/goals/data/goals_repository.dart';
import '../../features/goals/domain/goal_entity.dart';
import '../../features/goals/domain/goal_type.dart';
import '../../features/transactions/domain/transaction_type.dart';
import '../../features/transactions/domain/recurrence_rule.dart';
import '../../features/transactions/domain/payment_method.dart';
import 'hive_init.dart';
import 'profile_service.dart';
import 'auth_service.dart';

/// Popula o perfil 'demo' com dados realistas cobrindo 12 meses.
/// Idempotente: verifica se já existe dados antes de inserir.
class DemoSeedService {
  DemoSeedService._();
  static final DemoSeedService instance = DemoSeedService._();

  Future<void> populate() async {
    final loginId = AuthService.instance.activeLoginId!;
    final pid     = ProfileService.profileDemo;

    final txBox  = await Hive.openBox<TransactionModel>(ProfileService.boxName(HiveInit.transactionsBoxName, loginId, pid));
    final catBox = await Hive.openBox<CategoryModel>(ProfileService.boxName(HiveInit.categoriesBoxName,   loginId, pid));
    final cdBox  = await Hive.openBox<CardModel>(ProfileService.boxName(HiveInit.cardsBoxName,        loginId, pid));
    final acBox  = await Hive.openBox<AccountModel>(ProfileService.boxName(HiveInit.accountsBoxName,     loginId, pid));
    final goBox  = await Hive.openBox(ProfileService.boxName(HiveInit.goalsBoxName,        loginId, pid));
    final buBox  = await Hive.openBox(ProfileService.boxName(HiveInit.budgetsBoxName,      loginId, pid));

    if (txBox.isNotEmpty) return;

    // ── Categorias ────────────────────────────────────────────────────────────────────
    final cats = [
      CategoryModel(id: 'dcat_food',    name: 'Alimentação',   kindIndex: 0, colorValue: 0xFFF44336, iconCodePoint: Icons.restaurant_outlined.codePoint),
      CategoryModel(id: 'dcat_trans',   name: 'Transporte',    kindIndex: 0, colorValue: 0xFF2196F3, iconCodePoint: Icons.directions_car_outlined.codePoint),
      CategoryModel(id: 'dcat_subs',    name: 'Assinaturas',   kindIndex: 0, colorValue: 0xFF607D8B, iconCodePoint: Icons.subscriptions_outlined.codePoint),
      CategoryModel(id: 'dcat_health',  name: 'Saúde',         kindIndex: 0, colorValue: 0xFFE91E63, iconCodePoint: Icons.favorite_outline.codePoint),
      CategoryModel(id: 'dcat_leisure', name: 'Lazer',         kindIndex: 0, colorValue: 0xFF9C27B0, iconCodePoint: Icons.sports_esports_outlined.codePoint),
      CategoryModel(id: 'dcat_home',    name: 'Casa',          kindIndex: 0, colorValue: 0xFFFF9800, iconCodePoint: Icons.home_outlined.codePoint),
      CategoryModel(id: 'dcat_edu',     name: 'Educação',      kindIndex: 0, colorValue: 0xFF00BCD4, iconCodePoint: Icons.school_outlined.codePoint),
      CategoryModel(id: 'dcat_salary',  name: 'Salário',       kindIndex: 1, colorValue: 0xFF43A047, iconCodePoint: Icons.account_balance_wallet_outlined.codePoint),
      CategoryModel(id: 'dcat_extra',   name: 'Renda Extra',   kindIndex: 1, colorValue: 0xFF8BC34A, iconCodePoint: Icons.trending_up_outlined.codePoint),
    ];
    await catBox.putAll({for (final c in cats) c.id: c});

    // ── Cartões ─────────────────────────────────────────────────────────────────────
    final cards = [
      CardModel(id: 'dcard_1', name: 'Nubank',   bankName: 'Nubank',  typeIndex: 0, dueDay: 10, limit: 8000),
      CardModel(id: 'dcard_2', name: 'Inter',    bankName: 'Inter',   typeIndex: 0, dueDay: 20, limit: 5000),
    ];
    await cdBox.putAll({for (final c in cards) c.id: c});

    // ── Contas ─────────────────────────────────────────────────────────────────────
    final accounts = [
      AccountModel(id: 'dacc_1', name: 'Conta Corrente', typeIndex: AccountType.checking.index, initialBalance: 2500.0, colorValue: 0xFF01696F, isDefault: true),
      AccountModel(id: 'dacc_2', name: 'Poupança',       typeIndex: AccountType.savings.index,  initialBalance: 8000.0, colorValue: 0xFF43A047, isDefault: false),
      AccountModel(id: 'dacc_3', name: 'Carteira',       typeIndex: AccountType.cash.index,     initialBalance: 350.0,  colorValue: 0xFFD19900, isDefault: false),
    ];
    await acBox.putAll({for (final a in accounts) a.id: a});

    // ── Metas ─────────────────────────────────────────────────────────────────────
    final now = DateTime.now();
    final goals = [
      GoalEntity(id: 'dgoal_1', type: GoalType.savingsGoal,    title: 'Reserva de Emergência', targetAmount: 20000.0, currentAmount: 8000.0, categoryId: null, limitAmount: null, month: null),
      GoalEntity(id: 'dgoal_2', type: GoalType.savingsGoal,    title: 'Viagem Internacional',  targetAmount: 15000.0, currentAmount: 3200.0, categoryId: null, limitAmount: null, month: null),
      GoalEntity(id: 'dgoal_3', type: GoalType.spendingCeiling, title: 'Teto Alimentação',    targetAmount: null, currentAmount: null, categoryId: 'dcat_food',    limitAmount: 800.0,  month: DateTime(now.year, now.month, 1)),
      GoalEntity(id: 'dgoal_4', type: GoalType.spendingCeiling, title: 'Teto Lazer',           targetAmount: null, currentAmount: null, categoryId: 'dcat_leisure', limitAmount: 300.0,  month: DateTime(now.year, now.month, 1)),
      GoalEntity(id: 'dgoal_5', type: GoalType.spendingCeiling, title: 'Teto Assinaturas',     targetAmount: null, currentAmount: null, categoryId: 'dcat_subs',    limitAmount: 150.0,  month: DateTime(now.year, now.month, 1)),
    ];
    for (final g in goals) {
      await goBox.put(g.id, GoalsRepository.toMap(g));
    }

    // ── Orçamentos ─────────────────────────────────────────────────────────────────
    final budgetEntries = [
      {'id': 'dbudget_food',    'categoryId': 'dcat_food',    'limitAmount': 900.0,  'month': DateTime(now.year, now.month, 1).millisecondsSinceEpoch},
      {'id': 'dbudget_trans',   'categoryId': 'dcat_trans',   'limitAmount': 400.0,  'month': DateTime(now.year, now.month, 1).millisecondsSinceEpoch},
      {'id': 'dbudget_subs',    'categoryId': 'dcat_subs',    'limitAmount': 150.0,  'month': DateTime(now.year, now.month, 1).millisecondsSinceEpoch},
      {'id': 'dbudget_health',  'categoryId': 'dcat_health',  'limitAmount': 300.0,  'month': DateTime(now.year, now.month, 1).millisecondsSinceEpoch},
      {'id': 'dbudget_leisure', 'categoryId': 'dcat_leisure', 'limitAmount': 250.0,  'month': DateTime(now.year, now.month, 1).millisecondsSinceEpoch},
      {'id': 'dbudget_home',    'categoryId': 'dcat_home',    'limitAmount': 2100.0, 'month': DateTime(now.year, now.month, 1).millisecondsSinceEpoch},
      {'id': 'dbudget_edu',     'categoryId': 'dcat_edu',     'limitAmount': 250.0,  'month': DateTime(now.year, now.month, 1).millisecondsSinceEpoch},
    ];
    await buBox.putAll({for (final b in budgetEntries) b['id'] as String: b});

    // ── Transações ─ 12 meses ──────────────────────────────────────────────────────────
    final txs = <TransactionModel>[];
    int idx = 0;
    String tid() => 'dtx_${idx++}';

    for (int m = 11; m >= 0; m--) {
      final month = DateTime(now.year, now.month - m, 1);

      txs.add(TransactionModel(id: tid(), amount: 7500.0, currency: 'BRL', date: DateTime(month.year, month.month, 5), typeIndex: TransactionType.income.index, paymentMethodIndex: PaymentMethod.pix.index, description: 'Salário', categoryId: 'dcat_salary', cardId: null, isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      if (m % 2 == 0) txs.add(TransactionModel(id: tid(), amount: 800.0 + (m * 50), currency: 'BRL', date: DateTime(month.year, month.month, 12), typeIndex: TransactionType.income.index, paymentMethodIndex: PaymentMethod.pix.index, description: 'Freelance', categoryId: 'dcat_extra', cardId: null, isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      txs.add(TransactionModel(id: tid(), amount: 1800.0, currency: 'BRL', date: DateTime(month.year, month.month, 10), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.boleto.index, description: 'Aluguel', categoryId: 'dcat_home', cardId: null, isBoleto: true, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      txs.add(TransactionModel(id: tid(), amount: 39.90, currency: 'BRL', date: DateTime(month.year, month.month, 15), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.creditCard.index, description: 'Netflix', categoryId: 'dcat_subs', cardId: 'dcard_1', isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      txs.add(TransactionModel(id: tid(), amount: 21.90, currency: 'BRL', date: DateTime(month.year, month.month, 16), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.creditCard.index, description: 'Spotify', categoryId: 'dcat_subs', cardId: 'dcard_1', isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      txs.add(TransactionModel(id: tid(), amount: 45.90, currency: 'BRL', date: DateTime(month.year, month.month, 17), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.creditCard.index, description: 'Disney+', categoryId: 'dcat_subs', cardId: 'dcard_1', isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      txs.add(TransactionModel(id: tid(), amount: 99.90, currency: 'BRL', date: DateTime(month.year, month.month, 3), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.debitCard.index, description: 'Academia', categoryId: 'dcat_health', cardId: null, isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      txs.add(TransactionModel(id: tid(), amount: 119.90, currency: 'BRL', date: DateTime(month.year, month.month, 8), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.boleto.index, description: 'Internet', categoryId: 'dcat_home', cardId: null, isBoleto: true, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));

      final foodAmounts = [85.40, 120.80, 67.30, 145.20];
      for (int i = 0; i < 4; i++) {
        txs.add(TransactionModel(id: tid(), amount: foodAmounts[i] + (m * 2.5), currency: 'BRL', date: DateTime(month.year, month.month, 4 + (i * 6)), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.creditCard.index, description: 'Supermercado', categoryId: 'dcat_food', cardId: 'dcard_1', isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      }
      final restAmounts = [52.0, 78.5, 44.0];
      final restNames   = ['iFood', 'Restaurante', 'Lanchonete'];
      for (int i = 0; i < 3; i++) {
        txs.add(TransactionModel(id: tid(), amount: restAmounts[i], currency: 'BRL', date: DateTime(month.year, month.month, 7 + (i * 8)), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.creditCard.index, description: restNames[i], categoryId: 'dcat_food', cardId: 'dcard_2', isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      }
      txs.add(TransactionModel(id: tid(), amount: 35.0 + (m * 3), currency: 'BRL', date: DateTime(month.year, month.month, 9), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.creditCard.index, description: 'Uber', categoryId: 'dcat_trans', cardId: 'dcard_1', isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      txs.add(TransactionModel(id: tid(), amount: 180.0, currency: 'BRL', date: DateTime(month.year, month.month, 18), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.debitCard.index, description: 'Combustível', categoryId: 'dcat_trans', cardId: null, isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));

      final leisureNames   = ['Cinema', 'Steam', 'Shows', 'Museu'];
      final leisureAmounts = [45.0, 89.90, 120.0, 30.0];
      txs.add(TransactionModel(id: tid(), amount: leisureAmounts[m % 4], currency: 'BRL', date: DateTime(month.year, month.month, 20), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.creditCard.index, description: leisureNames[m % 4], categoryId: 'dcat_leisure', cardId: 'dcard_2', isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      if (m % 2 == 1) txs.add(TransactionModel(id: tid(), amount: 250.0, currency: 'BRL', date: DateTime(month.year, month.month, 22), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.creditCard.index, description: 'Consulta médica', categoryId: 'dcat_health', cardId: 'dcard_1', isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      if (m % 3 == 0) txs.add(TransactionModel(id: tid(), amount: 199.90, currency: 'BRL', date: DateTime(month.year, month.month, 25), typeIndex: TransactionType.expense.index, paymentMethodIndex: PaymentMethod.creditCard.index, description: 'Udemy', categoryId: 'dcat_edu', cardId: 'dcard_1', isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index));
      txs.add(TransactionModel(id: '${tid()}_out', amount: 500.0, currency: 'BRL', date: DateTime(month.year, month.month, 6), typeIndex: TransactionType.transfer.index, paymentMethodIndex: PaymentMethod.pix.index, description: 'Reserva mensal', categoryId: 'dcat_salary', cardId: null, isBoleto: false, isProvisioned: false, recurrenceRuleIndex: RecurrenceRule.none.index, toAccountId: 'dacc_2', notes: 'dacc_1'));
    }
    await txBox.putAll({for (final t in txs) t.id: t});
  }
}
