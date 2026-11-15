import 'package:finme/app/seed.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/cards/domain/invoice.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/importing/domain/category_history.dart';
import 'package:finme/features/importing/domain/categorizer.dart';
import 'package:finme/features/importing/domain/import_matcher.dart';
import 'package:finme/features/importing/domain/import_session.dart';
import 'package:finme/features/importing/domain/imported_line.dart';
import 'package:finme/features/importing/domain/merchant_dictionary.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 14);

ImportedLine _line(
  int row,
  DateTime date,
  String desc,
  int cents, {
  String? fitid,
  String? bankCategory,
}) => ImportedLine(
  row: row,
  date: date,
  description: desc,
  amountCents: cents,
  fitid: fitid,
  bankCategory: bankCategory,
);

/// Linhas válidas do extrato_conta.csv (montadas à mão).
List<ImportedLine> _extrato() => [
  _line(
    2,
    DateTime(2026, 11, 5),
    'PADARIA PAO BOM CURITIBA PR',
    -1250,
    bankCategory: 'Alimentação',
  ),
  _line(
    3,
    DateTime(2026, 11, 6),
    'MERCADO EXEMPLO; FILIAL 2',
    -123456,
    bankCategory: 'Supermercado',
  ),
  _line(4, DateTime(2026, 11, 7), 'SALARIO EMPRESA FICTICIA', 500000),
  _line(5, DateTime(2026, 11, 8), 'PAGTO FATURA CARTAO', -80000),
  _line(
    7,
    DateTime(2026, 11, 10),
    'LOJA EXEMPLO PARC 03/10',
    -15000,
    bankCategory: 'Compras',
  ),
];

Categorizer _categorizer({List<TransactionRule> rules = const []}) =>
    Categorizer(
      rules: rules,
      categories: defaultCategories(),
      history: CategoryHistory.empty,
      dictionary: defaultDictionary(),
    );

ImportSession _session(
  List<ImportedLine> lines, {
  ImportTarget target = const ImportTarget(accountId: 'acc_a'),
  List<Transaction> existing = const [],
  Categorizer? categorizer,
}) => ImportSession.build(
  lines: lines,
  target: target,
  categorizer: categorizer ?? _categorizer(),
  matcher: ImportMatcher(existing),
);

Transaction _tx(
  String id, {
  required int cents,
  required DateTime date,
  required String desc,
  String? acc,
  String? card,
  TransactionStatus status = TransactionStatus.paid,
}) => Transaction(
  id: id,
  type: TransactionType.expense,
  amountCents: cents,
  date: date,
  description: desc,
  accountId: acc,
  cardId: card,
  status: status,
);

void main() {
  test(
    'resumo das linhas válidas do extrato, parcela 3/10 e fatura desmarcada',
    () {
      final s = _session(_extrato());
      expect(s.summary, (
        create: 4,
        confirm: 0,
        skipped: 1,
        futureInstallments: 7,
      ));
      expect(s.rows[3].include, isFalse);
      expect(
        s.rows[3].match.flags.contains(ImportFlag.invoicePaymentLike),
        isTrue,
      );
      expect(s.rows[4].installment, (index: 3, count: 10));
      expect(s.rows[4].createInstallments, isTrue);
      expect(s.rows[0].include, isTrue);
    },
  );

  test('linha com duplicata provável começa desmarcada', () {
    final s = _session(
      [_line(1, DateTime(2026, 11, 5), 'PADARIA PAO BOM', -1250)],
      existing: [
        _tx(
          'e1',
          cents: 1250,
          date: DateTime(2026, 11, 5),
          desc: 'PADARIA PAO BOM',
          acc: 'acc_a',
        ),
      ],
    );
    expect(s.rows.single.match.flags, {ImportFlag.probableDuplicate});
    expect(s.rows.single.include, isFalse);
  });

  test(
    'setCategory marca categoryEdited e recategorize preserva a editada',
    () {
      final s = _session(_extrato());
      final edited = s.setCategory(0, 'cat_lazer');
      expect(edited.rows[0].categoryEdited, isTrue);
      expect(edited.rows[0].categoryId, 'cat_lazer');

      final cz = _categorizer(
        rules: const [
          TransactionRule(
            id: 'r',
            pattern: 'PADARIA',
            categoryId: 'cat_transporte',
          ),
        ],
      );
      final re = edited.recategorize(cz);
      expect(re.rows[0].categoryId, 'cat_lazer');
      expect(re.rows[0].categoryEdited, isTrue);

      final re2 = s.recategorize(cz);
      expect(re2.rows[0].categoryId, 'cat_transporte');
      expect(re2.rows[0].suggestion.ruleId, 'r');
    },
  );

  test(
    'setAllIncluded(false) zera as linhas a criar; uncategorizedIndices só sem categoria',
    () {
      final s = _session(
        _extrato(),
        categorizer: Categorizer(
          rules: const [],
          categories: defaultCategories(),
          history: CategoryHistory.empty,
          dictionary: const [],
        ),
      );
      expect(s.setAllIncluded(false).summary.create, 0);
      // Só as linhas 0 (banco "Alimentação") e 4 (banco "Compras") têm categoria.
      expect(s.rows[0].categoryId, 'cat_alimentacao');
      expect(s.rows[4].categoryId, 'cat_compras');
      expect(s.uncategorizedIndices(), [1, 2, 3]);
    },
  );

  test(
    'setCreateInstallments(false) gera transação única sem campos de parcela',
    () {
      final s = _session(_extrato()).setCreateInstallments(4, false);
      final plan = buildImportPlan(
        s,
        target: const ImportTarget(accountId: 'acc_a'),
        today: _today,
        idGenerator: _seqIds(),
      );
      final single = plan.create
          .where((t) => t.description.contains('LOJA'))
          .toList();
      expect(single, hasLength(1));
      expect(single.single.installmentGroupId, isNull);
      expect(single.single.installmentIndex, isNull);
      expect(single.single.installmentCount, isNull);
    },
  );

  test(
    '"UBER *TRIP 05/11" em 05/11 não vira parcela; "LOJA 3/10" fraca começa desligada',
    () {
      final s = _session([
        _line(1, DateTime(2026, 11, 5), 'UBER *TRIP 05/11', -2000),
        _line(2, DateTime(2026, 11, 8), 'LOJA X 3/10', -3000),
        _line(3, DateTime(2026, 11, 8), 'LOJA Y PARC 3/10', -3000),
      ]);
      expect(s.rows[0].installment, isNull);
      expect(s.rows[0].makesSeries, isFalse);
      expect(s.rows[1].installment, (index: 3, count: 10));
      expect(s.rows[1].createInstallments, isFalse);
      expect(s.rows[2].createInstallments, isTrue);
      expect(s.summary.futureInstallments, 7);
    },
  );

  test('provisionado confirmado usa a categoria editada pelo usuário', () {
    final planned = Transaction(
      id: 'p1',
      type: TransactionType.expense,
      amountCents: 4500,
      date: DateTime(2026, 11, 8),
      description: 'ACADEMIA EXEMPLO',
      categoryId: 'cat_saude',
      accountId: 'acc_a',
      status: TransactionStatus.planned,
    );
    final lines = [
      _line(1, DateTime(2026, 11, 10), 'ACADEMIA EXEMPLO MENSAL', -4500),
    ];
    final kept = buildImportPlan(
      _session(lines, existing: [planned]),
      target: const ImportTarget(accountId: 'acc_a'),
      today: _today,
    );
    expect(kept.update.single.categoryId, 'cat_saude');

    final edited = buildImportPlan(
      _session(lines, existing: [planned]).setCategory(0, 'cat_lazer'),
      target: const ImportTarget(accountId: 'acc_a'),
      today: _today,
    );
    expect(edited.update.single.categoryId, 'cat_lazer');
  });

  test('learnedBankCategories usa só linhas incluídas com categoria', () {
    final s = _session(_extrato());
    final learned = learnedBankCategories(s);
    expect(learned['ALIMENTACAO'], 'cat_alimentacao');
    expect(learned['COMPRAS'], 'cat_compras');
    expect(learned.containsKey('SALARIO'), isFalse);
    final off = s.setInclude(0, false);
    expect(learnedBankCategories(off).containsKey('ALIMENTACAO'), isFalse);
  });

  test(
    'plano conta A: provisionado confirmado, parcelas, data futura e linha desmarcada',
    () {
      final planned = _tx(
        'p1',
        cents: 4500,
        date: DateTime(2026, 11, 8),
        desc: 'ACADEMIA EXEMPLO',
        acc: 'acc_a',
        status: TransactionStatus.planned,
      );
      final lines = [
        _line(1, DateTime(2026, 11, 10), 'ACADEMIA EXEMPLO MENSAL', -4500),
        _line(2, DateTime(2026, 11, 10), 'LOJA EXEMPLO PARC 03/10', -15000),
        _line(3, DateTime(2026, 11, 20), 'ASSINATURA FUTURA', -900),
        _line(4, DateTime(2026, 11, 12), 'DESMARCADA', -100),
      ];
      final s = _session(lines, existing: [planned]).setInclude(3, false);
      final plan = buildImportPlan(
        s,
        target: const ImportTarget(accountId: 'acc_a'),
        today: _today,
        idGenerator: _seqIds(),
      );

      expect(plan.update, hasLength(1));
      final up = plan.update.single;
      expect(up.id, 'p1');
      expect(up.status, TransactionStatus.paid);
      expect(up.date, DateTime(2026, 11, 10));
      expect(up.description, 'ACADEMIA EXEMPLO');
      expect(up.amountCents, 4500);
      expect(up.importedDescription, 'ACADEMIA EXEMPLO MENSAL');

      // Grupo: id1 (groupId) → ids id1_3..id1_10.
      final series = plan.create
          .where((t) => t.installmentGroupId != null)
          .toList();
      expect(series.map((t) => t.id), [for (var i = 3; i <= 10; i++) 'id1_$i']);
      expect(series.every((t) => t.amountCents == 15000), isTrue);
      expect(series.every((t) => t.installmentGroupId == 'id1'), isTrue);
      expect(series.first.status, TransactionStatus.paid);
      expect(series.first.importedDescription, 'LOJA EXEMPLO PARC 03/10');
      expect(
        series.skip(1).every((t) => t.status == TransactionStatus.planned),
        isTrue,
      );

      final future = plan.create
          .where((t) => t.description == 'ASSINATURA FUTURA')
          .single;
      expect(future.status, TransactionStatus.planned);

      expect(plan.create.any((t) => t.description == 'DESMARCADA'), isFalse);
    },
  );

  test('plano cartão de crédito: parcelas caem nas faturas certas', () {
    const card = PaymentCard(
      id: 'card_c',
      name: 'Cartão Alfa',
      bankName: 'Banco Alfa',
      brand: CardBrand.visa,
      kind: CardKind.credit,
      last4: '1234',
      closingDay: 5,
      dueDay: 12,
      colorValue: 0xFF42A5F5,
    );
    final s = _session([
      _line(
        7,
        DateTime(2026, 11, 8),
        'LOJA EXEMPLO PARC 03/10',
        -20000,
        fitid: 'CC-2',
      ),
    ], target: const ImportTarget(cardId: 'card_c'));
    final plan = buildImportPlan(
      s,
      target: const ImportTarget(cardId: 'card_c'),
      card: card,
      today: _today,
      idGenerator: _seqIds(),
    );

    expect(plan.create, hasLength(8));
    expect(plan.create.every((t) => t.cardId == 'card_c'), isTrue);
    // A 1ª do grupo é a parcela 3 (a linha importada): só ela leva o FITID.
    expect(plan.create.first.installmentIndex, 3);
    expect(
      plan.create.where((t) => t.externalId != null).map((t) => t.externalId),
      ['CC-2'],
    );

    final invoices = InvoiceService.build(
      card: card,
      transactions: plan.create,
    );
    final dueOf = {
      for (final inv in invoices)
        for (final t in inv.items) t.installmentIndex: inv.dueMonth,
    };
    expect(dueOf[3], const YearMonth(2026, 12));
    expect(dueOf[10], const YearMonth(2027, 7));
  });

  test('desempenho: 2.000 linhas contra 10.000 transações < 2 s', () {
    final existing = [
      for (var i = 0; i < 10000; i++)
        _tx(
          'e$i',
          cents: 100 + (i * 37) % 9973,
          date: DateTime(2026, 10, 1).add(Duration(days: i % 60)),
          desc: 'LOJA ${i % 700} EXEMPLO ${i % 13}',
          acc: i % 3 == 2 ? null : (i % 3 == 0 ? 'acc_a' : 'acc_b'),
          card: i % 3 == 2 ? 'card_c' : null,
        ),
    ];
    // 10% das linhas repetem existentes da origem acc_a (índices múltiplos de 3).
    final lines = [
      for (var i = 0; i < 2000; i++)
        if (i % 10 == 0)
          _line(
            i + 1,
            existing[3 * i].date,
            existing[3 * i].description,
            -existing[3 * i].amountCents,
          )
        else
          _line(
            i + 1,
            DateTime(2026, 11, 1).add(Duration(days: i % 20)),
            'COMPRA $i EXEMPLO ${i % 50}',
            -(50000 + i * 13),
          ),
    ];
    final history = CategoryHistory.build(existing);
    final cz = Categorizer(
      rules: const [],
      categories: defaultCategories(),
      history: history,
      dictionary: defaultDictionary(),
    );
    final matcher = ImportMatcher(existing);

    final sw = Stopwatch()..start();
    final session = ImportSession.build(
      lines: lines,
      target: const ImportTarget(accountId: 'acc_a'),
      categorizer: cz,
      matcher: matcher,
    );
    final plan = buildImportPlan(
      session,
      target: const ImportTarget(accountId: 'acc_a'),
      today: _today,
    );
    sw.stop();

    expect(plan.create.length + plan.update.length, greaterThan(0));
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}

/// Gerador de ids determinístico: 'id1', 'id2', …
String Function() _seqIds() {
  var n = 0;
  return () => 'id${++n}';
}
