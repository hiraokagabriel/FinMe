import 'dart:convert';

import 'package:csv/csv.dart';

import '../../app/app_scope.dart';
import '../../features/accounts/domain/account.dart';
import '../../features/cards/domain/payment_card.dart';
import '../../features/categories/domain/transaction_category.dart';
import '../../features/recurring/domain/recurring_rule.dart';
import '../../features/transactions/domain/transaction.dart';
import '../models/app_settings.dart';
import '../models/year_month.dart';
import '../utils/formatters.dart';

/// Backup JSON completo (ida e volta) e exportação CSV de lançamentos.
class BackupService {
  static const int version = 1;

  static const _csvHeader = [
    'Data',
    'Descrição',
    'Tipo',
    'Status',
    'Valor',
    'Conta',
    'Cartão',
    'Categoria',
    'Parcela',
    'Notas',
  ];

  static String exportJson(AppServices s) => jsonEncode({
    'app': 'finme',
    'version': version,
    'exportedAt': s.clock().toIso8601String(),
    'accounts': [for (final a in s.accounts.all) a.toMap()],
    'cards': [for (final c in s.cards.all) c.toMap()],
    'categories': [for (final c in s.categories.all) c.toMap()],
    'transactions': [for (final t in s.transactions.all) t.toMap()],
    'recurring': [for (final r in s.recurring.all) r.toMap()],
    'settings': s.settings.value.toMap(),
  });

  /// Lê tudo antes de gravar: JSON ou registro inválido lança [FormatException] e nada muda.
  static Future<void> importJson(AppServices s, String json) async {
    final data = jsonDecode(json);
    if (data is! Map<String, dynamic> ||
        data['app'] != 'finme' ||
        data['version'] != version) {
      throw const FormatException('Arquivo não é um backup do FinMe');
    }
    final b = _parse(data);
    await s.accounts.replaceAll(b.accounts);
    await s.cards.replaceAll(b.cards);
    await s.categories.replaceAll(b.categories);
    await s.transactions.replaceAll(b.transactions);
    await s.recurring.replaceAll(b.recurring);
    await s.settings.update((_) => b.settings);
  }

  /// Lançamentos (ordenados por data) em CSV com `;`. Valor com sinal: saídas negativas.
  static String transactionsCsv(AppServices s, {YearMonth? month}) {
    final list = [
      for (final t in s.transactions.all)
        if (month == null || month.contains(t.date)) t,
    ]..sort((a, b) => a.date.compareTo(b.date));
    return const ListToCsvConverter(fieldDelimiter: ';').convert([
      _csvHeader,
      for (final t in list)
        [
          formatDate(t.date),
          t.description,
          _typeLabel(t.type),
          t.isPlanned ? 'Provisionado' : 'Efetivado',
          _csvMoney(_signed(t)),
          _nameOf(t.accountId, s.accounts.byId, (a) => a.name),
          _nameOf(t.cardId, s.cards.byId, (c) => c.name),
          _nameOf(t.categoryId, s.categories.byId, (c) => c.name),
          t.installmentIndex == null
              ? ''
              : '${t.installmentIndex}/${t.installmentCount}',
          t.notes ?? '',
        ],
    ]);
  }

  static ({
    List<Account> accounts,
    List<PaymentCard> cards,
    List<TransactionCategory> categories,
    List<Transaction> transactions,
    List<RecurringRule> recurring,
    AppSettings settings,
  })
  _parse(Map<String, dynamic> data) {
    try {
      return (
        accounts: _rows(data, 'accounts', Account.fromMap),
        cards: _rows(data, 'cards', PaymentCard.fromMap),
        categories: _rows(data, 'categories', TransactionCategory.fromMap),
        transactions: _rows(data, 'transactions', Transaction.fromMap),
        recurring: _rows(data, 'recurring', RecurringRule.fromMap),
        // Backup de instalação nova não devolve o usuário ao onboarding.
        settings: AppSettings.fromMap(
          data['settings'] as Map<String, dynamic>,
        ).copyWith(onboardingDone: true),
      );
    } on TypeError catch (e) {
      throw FormatException('Backup com campos inválidos: $e');
    }
  }

  static List<T> _rows<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic>) fromMap,
  ) => [
    for (final row in data[key] as List) fromMap(row as Map<String, dynamic>),
  ];

  static String _nameOf<T>(
    String? id,
    T? Function(String) byId,
    String Function(T) name,
  ) {
    final item = id == null ? null : byId(id);
    return item == null ? '' : name(item);
  }

  static int _signed(Transaction t) => switch (t.type) {
    TransactionType.income => t.amountCents,
    _ => -t.amountCents,
  };

  // Sem "R$" nem separador de milhar: "-1234,56" (formatMoney só remove o que não serve ao CSV).
  static String _csvMoney(int cents) {
    final digits = formatMoney(
      cents.abs(),
    ).replaceFirst('R\$ ', '').replaceAll('.', '');
    return cents < 0 ? '-$digits' : digits;
  }

  static String _typeLabel(TransactionType type) => switch (type) {
    TransactionType.expense => 'Despesa',
    TransactionType.income => 'Receita',
    TransactionType.transfer => 'Transferência',
    TransactionType.invoicePayment => 'Pagamento de fatura',
  };
}
