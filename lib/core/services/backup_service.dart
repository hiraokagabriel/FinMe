import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_scope.dart';
import '../../app/bootstrap.dart';
import '../../features/accounts/domain/account.dart';
import '../../features/cards/domain/payment_card.dart';
import '../../features/categories/domain/category_tree.dart';
import '../../features/categories/domain/transaction_category.dart';
import '../../features/goals/domain/goal.dart';
import '../../features/importing/domain/import_profile.dart';
import '../../features/importing/domain/merchant_dictionary.dart';
import '../../features/recurring/domain/recurring_rule.dart';
import '../../features/rules/domain/transaction_rule.dart';
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
    'Tags',
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
    'rules': [for (final r in s.rules.all) r.toMap()],
    'importProfiles': [for (final p in s.importProfiles.all) p.toMap()],
    'dictionary': [for (final e in s.dictionary.all) e.toMap()],
    'goals': [for (final g in s.goals.all) g.toMap()],
  });

  /// Lê tudo antes de gravar: JSON ou registro inválido lança [FormatException] e nada muda.
  /// Depois de gravar, materializa as recorrências até ontem (como no boot).
  /// Falha na gravação restaura o retrato anterior (Hive não tem transação entre boxes) e relança.
  static Future<void> importJson(AppServices s, String json) async {
    final data = jsonDecode(json);
    if (data is! Map<String, dynamic> ||
        data['app'] != 'finme' ||
        data['version'] != version) {
      throw const FormatException('Arquivo não é um backup do FinMe');
    }
    final b = _parse(data);
    final retrato = (
      accounts: s.accounts.all,
      cards: s.cards.all,
      categories: s.categories.all,
      transactions: s.transactions.all,
      recurring: s.recurring.all,
      settings: s.settings.value,
      rules: s.rules.all,
      importProfiles: s.importProfiles.all,
      dictionary: s.dictionary.all,
      goals: s.goals.all,
    );
    try {
      await s.accounts.replaceAll(b.accounts);
      await s.cards.replaceAll(b.cards);
      await s.categories.replaceAll(b.categories);
      await s.transactions.replaceAll(b.transactions);
      await s.recurring.replaceAll(b.recurring);
      await s.settings.update((_) => b.settings);
      await s.rules.replaceAll(b.rules);
      await s.importProfiles.replaceAll(b.importProfiles);
      await s.dictionary.replaceAll(b.dictionary);
      await s.goals.replaceAll(b.goals);
      await materializeRecurring(s);
    } catch (e, st) {
      // Cada restauração tem try próprio: uma falha não impede as demais.
      final restores = <Future<void> Function()>[
        () => s.accounts.replaceAll(retrato.accounts),
        () => s.cards.replaceAll(retrato.cards),
        () => s.categories.replaceAll(retrato.categories),
        () => s.transactions.replaceAll(retrato.transactions),
        () => s.recurring.replaceAll(retrato.recurring),
        () => s.settings.update((_) => retrato.settings),
        () => s.rules.replaceAll(retrato.rules),
        () => s.importProfiles.replaceAll(retrato.importProfiles),
        () => s.dictionary.replaceAll(retrato.dictionary),
        () => s.goals.replaceAll(retrato.goals),
      ];
      for (final restore in restores) {
        try {
          await restore();
        } catch (restoreError) {
          debugPrint('BackupService: falha ao restaurar: $restoreError');
        }
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  /// Lançamentos (ordenados por data) em CSV com `;`. Valor com sinal: saídas negativas.
  static String transactionsCsv(AppServices s, {YearMonth? month}) {
    final list = [
      for (final t in s.transactions.all)
        if (month == null || month.contains(t.date)) t,
    ]..sort((a, b) => a.date.compareTo(b.date));
    final tree = CategoryTree(s.categories.all);
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
          // "Pai › Filha" (SPEC §5.20); id desconhecido ou nulo sai vazio.
          _csvText(tree.label(t.categoryId ?? '')),
          t.installmentIndex == null
              ? ''
              : '${t.installmentIndex}/${t.installmentCount}',
          _csvText(t.notes ?? ''),
          _csvText(t.tags.join(', ')),
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
    List<TransactionRule> rules,
    List<ImportProfile> importProfiles,
    List<DictionaryEntry> dictionary,
    List<Goal> goals,
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
        // Lançamento ou regra presa a conta/cartão ausente no backup é descartado;
        // transferência também cai se a conta de destino não existir.
        transactions: _rows([
          for (final row in _maps(data, 'transactions'))
            if (_linked(row['accountId'], accountIds) &&
                _linked(row['cardId'], cardIds) &&
                (row['type'] != TransactionType.transfer.name ||
                    _linked(row['toAccountId'], accountIds)))
              _unlinkedCategory(row, categoryIds),
        ], Transaction.fromMap),
        recurring: _rows([
          for (final row in _maps(data, 'recurring'))
            if (_linked(row['accountId'], accountIds) &&
                _linked(row['cardId'], cardIds))
              _unlinkedCategory(row, categoryIds),
        ], RecurringRule.fromMap),
        // Backup de instalação nova não devolve o usuário ao onboarding.
        settings: AppSettings.fromMap(
          data['settings'] as Map<String, dynamic>,
        ).copyWith(onboardingDone: true),
        // Chaves da Fase 8 ausentes (backup antigo): regras e perfis vazios, dicionário padrão.
        rules: _rows([
          for (final row in _optMaps(data, 'rules'))
            _unlinkedCategory(row, categoryIds),
        ], TransactionRule.fromMap),
        importProfiles: _rows([
          for (final row in _optMaps(data, 'importProfiles'))
            if (_hasDestino(row, accountIds, cardIds)) row,
        ], ImportProfile.fromMap),
        dictionary: data.containsKey('dictionary')
            ? _rows(_maps(data, 'dictionary'), DictionaryEntry.fromMap)
            : defaultDictionary(),
        // Meta com conta ausente no backup é descartada; chave ausente → []. Conta é obrigatória, por isso não usa _linked.
        goals: _rows([
          for (final row in _goalRows(data))
            if (accountIds.contains(row['accountId'])) row,
        ], Goal.fromMap),
      );
    } on TypeError catch (e) {
      throw FormatException('Backup com campos inválidos: $e');
    }
  }

  static List<Map<String, dynamic>> _maps(
    Map<String, dynamic> data,
    String key,
  ) => [for (final row in data[key] as List) row as Map<String, dynamic>];

  /// Alvo de meta nulo ou ≤ 0 invalida o backup inteiro (nada é gravado).
  static List<Map<String, dynamic>> _goalRows(Map<String, dynamic> data) {
    final rows = _optMaps(data, 'goals');
    for (final row in rows) {
      final target = row['targetCents'];
      if (target is! num || target <= 0) {
        throw const FormatException('Backup com meta de alvo inválido');
      }
    }
    return rows;
  }

  static List<Map<String, dynamic>> _optMaps(
    Map<String, dynamic> data,
    String key,
  ) => data.containsKey(key) ? _maps(data, key) : const [];

  static Set<String> _idsOf(Map<String, dynamic> data, String key) => {
    for (final row in _maps(data, key)) row['id'] as String,
  };

  /// Referência nula ou existente no backup; qualquer outra é órfã.
  static bool _linked(Object? id, Set<String> ids) =>
      id == null || ids.contains(id);

  /// Perfil precisa de um destino que exista no backup; sem destino ou com destino órfão, é descartado.
  static bool _hasDestino(
    Map<String, dynamic> row,
    Set<String> accountIds,
    Set<String> cardIds,
  ) {
    final accountId = row['accountId'];
    final cardId = row['cardId'];
    return (accountId != null || cardId != null) &&
        _linked(accountId, accountIds) &&
        _linked(cardId, cardIds);
  }

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
