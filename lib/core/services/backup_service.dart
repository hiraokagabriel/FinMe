import 'dart:convert';

import 'package:csv/csv.dart';

import '../../app/app_scope.dart';
import '../../app/bootstrap.dart';
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
    'Destino',
    'Conta no total',
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
  /// Depois de gravar, materializa as recorrências até ontem (como no boot).
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
    await materializeRecurring(s);
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
          _csvText(t.description),
          _typeLabel(t.type),
          t.isPlanned ? 'Provisionado' : 'Efetivado',
          _csvMoney(_signed(t)),
          _csvText(_nameOf(t.accountId, s.accounts.byId, (a) => a.name)),
          _csvText(_nameOf(t.cardId, s.cards.byId, (c) => c.name)),
          _csvText(_destinationOf(t, s)),
          // Transferência e pagamento de fatura não entram no total: o dinheiro só muda de lugar.
          _countsInTotal(t, s) ? 'sim' : 'não',
          _csvText(_nameOf(t.categoryId, s.categories.byId, (c) => c.name)),
          t.installmentIndex == null
              ? ''
              : '${t.installmentIndex}/${t.installmentCount}',
          _csvText(t.notes ?? ''),
        ],
    ]);
  }

  static String _destinationOf(Transaction t, AppServices s) =>
      switch (t.type) {
        TransactionType.transfer => _nameOf(
          t.toAccountId,
          s.accounts.byId,
          (a) => a.name,
        ),
        TransactionType.invoicePayment => _nameOf(
          t.cardId,
          s.cards.byId,
          (c) => c.name,
        ),
        _ => '',
      };

  /// Crédito só afeta conta via pagamento de fatura (SPEC §5.5), então fica fora do total.
  static bool _countsInTotal(Transaction t, AppServices s) {
    if (t.type == TransactionType.transfer ||
        t.type == TransactionType.invoicePayment) {
      return false;
    }
    final cardId = t.cardId;
    final card = cardId == null ? null : s.cards.byId(cardId);
    return card?.kind != CardKind.credit;
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
      final accountIds = _idsOf(data, 'accounts');
      final cardIds = _idsOf(data, 'cards');
      final categoryIds = _idsOf(data, 'categories');
      return (
        accounts: _rows(_maps(data, 'accounts'), Account.fromMap),
        cards: _rows(_maps(data, 'cards'), PaymentCard.fromMap),
        categories: _rows(
          _maps(data, 'categories'),
          TransactionCategory.fromMap,
        ),
        // Lançamento preso a conta ou cartão ausente no backup é descartado.
        transactions: _rows([
          for (final row in _maps(data, 'transactions'))
            if (_linked(row['accountId'], accountIds) &&
                _linked(row['cardId'], cardIds))
              _unlinkedCategory(row, categoryIds),
        ], Transaction.fromMap),
        recurring: _rows([
          for (final row in _maps(data, 'recurring'))
            _unlinkedCategory(row, categoryIds),
        ], RecurringRule.fromMap),
        // Backup de instalação nova não devolve o usuário ao onboarding.
        settings: AppSettings.fromMap(
          data['settings'] as Map<String, dynamic>,
        ).copyWith(onboardingDone: true),
      );
    } on TypeError catch (e) {
      throw FormatException('Backup com campos inválidos: $e');
    }
  }

  static List<Map<String, dynamic>> _maps(
    Map<String, dynamic> data,
    String key,
  ) => [for (final row in data[key] as List) row as Map<String, dynamic>];

  static Set<String> _idsOf(Map<String, dynamic> data, String key) => {
    for (final row in _maps(data, key)) row['id'] as String,
  };

  /// Referência nula ou existente no backup; qualquer outra é órfã.
  static bool _linked(Object? id, Set<String> ids) =>
      id == null || ids.contains(id);

  static Map<String, dynamic> _unlinkedCategory(
    Map<String, dynamic> row,
    Set<String> categoryIds,
  ) => _linked(row['categoryId'], categoryIds)
      ? row
      : {...row, 'categoryId': null};

  static List<T> _rows<T>(
    List<Map<String, dynamic>> rows,
    T Function(Map<String, dynamic>) fromMap,
  ) => [for (final row in rows) fromMap(row)];

  static String _nameOf<T>(
    String? id,
    T? Function(String) byId,
    String Function(T) name,
  ) {
    final item = id == null ? null : byId(id);
    return item == null ? '' : name(item);
  }

  /// Planilha trata texto iniciado em = + - @ como fórmula: prefixa uma aspa simples.
  static String _csvText(String value) =>
      value.isNotEmpty && '=+-@'.contains(value[0]) ? "'$value" : value;

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
