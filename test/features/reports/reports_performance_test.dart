import 'dart:math';

import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/category_pivot.dart';
import 'package:finme/features/reports/domain/category_reports.dart';
import 'package:finme/features/reports/domain/merchant_report.dart';
import 'package:finme/features/reports/domain/monthly_flow.dart';
import 'package:finme/features/reports/domain/report_csv.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/reports/domain/spending_heatmap.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/tags.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// Desempenho dos relatórios (SPEC §5.32): base sintética determinística, sem dado real.
// Cada medição < 300 ms. Se algo passar do limite, otimizar o domínio, nunca afrouxar.

const int _total = 20000;
const YearMonth _inicio = YearMonth(2024, 12);
const YearMonth _fim = YearMonth(2026, 11);
final DateTime _hoje = DateTime(2026, 11, 15);

// Heatmap de 731 dias inclusive (30/11/2024 a 30/11/2026).
final DateTime _diaIni = DateTime(2024, 11, 30);
final DateTime _diaFim = DateTime(2026, 11, 30);

const String _alnum = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

TransactionCategory _cat(
  String id,
  String name,
  CategoryKind kind, {
  String? parentId,
}) => TransactionCategory(
  id: id,
  name: name,
  kind: kind,
  iconCodePoint: 0,
  colorValue: 0,
  parentId: parentId,
);

/// 10 raízes de despesa com 3 filhas cada (40) e 2 de receita.
List<TransactionCategory> _categorias() => [
  for (var r = 0; r < 10; r++) ...[
    _cat('r$r', 'Categoria $r', CategoryKind.expense),
    for (var c = 0; c < 3; c++)
      _cat(
        'r${r}_$c',
        'Subcategoria $r.$c',
        CategoryKind.expense,
        parentId: 'r$r',
      ),
  ],
  _cat('i0', 'Salário', CategoryKind.income),
  _cat('i1', 'Outras receitas', CategoryKind.income),
];

final List<String> _idsDespesa = [
  for (var r = 0; r < 10; r++) ...[
    'r$r',
    for (var c = 0; c < 3; c++) 'r${r}_$c',
  ],
];

/// Três letras (k < 676). Nome sem dígito: `normalizeDescription` apagaria um código numérico e juntaria as 600 lojas.
String _letras(int k) =>
    String.fromCharCodes([65 + k ~/ 676, 65 + (k ~/ 26) % 26, 65 + k % 26]);

/// 4 alfanuméricos + 1 dígito (código de 5 caracteres com dígito).
String _codigo(Random rng) {
  final corpo = [
    for (var i = 0; i < 4; i++) _alnum[rng.nextInt(_alnum.length)],
  ].join();
  return '$corpo${rng.nextInt(10)}';
}

/// Dia 1..28 de um mês entre 2024-12 e (2024-12 + [maxOffset]).
DateTime _dia(Random rng, int maxOffset) {
  final ym = _inicio.addMonths(rng.nextInt(maxOffset + 1));
  return DateTime(ym.year, ym.month, 1 + rng.nextInt(28));
}

/// Base sintética de §5.32. Ordem de sorteio fixa: qualquer mudança muda os números.
List<Transaction> _baseSintetica() {
  final rng = Random(42);
  final brutas = [
    for (var k = 0; k < 600; k++) 'LOJA ${_letras(k)} ${_codigo(rng)}',
  ];
  final out = <Transaction>[];
  var grupo = 0;
  while (out.length < _total) {
    final k = rng.nextInt(brutas.length);
    final bruta = brutas[k];
    final planejado = rng.nextInt(20) == 0; // 5%
    final status = planejado
        ? TransactionStatus.planned
        : TransactionStatus.paid;
    final tags = rng.nextInt(10) < 3
        ? const ['viagem']
        : const <String>[]; // 30%

    // ~10% das transações em grupos de 3 parcelas (1/28 das unidades).
    if (out.length + 3 <= _total && rng.nextInt(28) == 0) {
      final importada = rng.nextInt(3) == 0; // 1/3 das despesas → 30% do total
      final modelo = Transaction(
        id: 'base_$grupo',
        type: TransactionType.expense,
        amountCents: 3000 + rng.nextInt(87000),
        date: _dia(rng, 21), // 2026-09 é o último mês que cabe as 3 parcelas
        description: importada ? 'Loja ${_letras(k)}' : bruta,
        categoryId: rng.nextInt(20) == 0
            ? null
            : _idsDespesa[rng.nextInt(_idsDespesa.length)],
        cardId: 'cartao_${1 + rng.nextInt(8)}',
        status: status,
        tags: tags,
      );
      final parcelas = buildInstallments(
        base: modelo,
        count: 3,
        groupId: 'g$grupo',
      );
      grupo++;
      // buildInstallments não copia importedDescription.
      out.addAll([
        for (final p in parcelas)
          importada ? p.copyWith(importedDescription: bruta) : p,
      ]);
      continue;
    }

    final id = 't${out.length}';
    final recorrente = rng.nextInt(9) == 0 ? 'rec_${rng.nextInt(20)}' : null;
    if (rng.nextInt(9) == 0) {
      // Receita em conta: 1/9 dos avulsos ≈ 10% do total.
      out.add(
        Transaction(
          id: id,
          type: TransactionType.income,
          amountCents: 100000 + rng.nextInt(400000),
          date: _dia(rng, 23),
          description: 'Recebimento ${rng.nextInt(10)}',
          categoryId: rng.nextBool() ? 'i0' : 'i1',
          accountId: 'conta_${1 + rng.nextInt(5)}',
          status: status,
          recurringId: recorrente,
          tags: tags,
        ),
      );
      continue;
    }

    final importada = rng.nextInt(3) == 0; // 1/3 das despesas → 30% do total
    final noCartao = rng.nextInt(10) < 7;
    out.add(
      Transaction(
        id: id,
        type: TransactionType.expense,
        amountCents: 500 + rng.nextInt(30000),
        date: _dia(rng, 23),
        description: importada ? 'Loja ${_letras(k)}' : bruta,
        categoryId: rng.nextInt(20) == 0
            ? null
            : _idsDespesa[rng.nextInt(_idsDespesa.length)],
        accountId: noCartao ? null : 'conta_${1 + rng.nextInt(5)}',
        cardId: noCartao ? 'cartao_${1 + rng.nextInt(8)}' : null,
        status: status,
        importedDescription: importada ? bruta : null,
        recurringId: recorrente,
        tags: tags,
      ),
    );
  }
  return out;
}

/// Cronometra [corpo] (uma chamada, sem aquecimento) e exige < 300 ms.
T _medir<T>(String rotulo, String nome, T Function() corpo) {
  final sw = Stopwatch()..start();
  final r = corpo();
  sw.stop();
  debugPrint(
    '[$rotulo] $nome: ${(sw.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms',
  );
  expect(sw.elapsedMilliseconds, lessThan(300), reason: nome);
  return r;
}

/// Roda todos os relatórios de §5.32 com [f] sobre [txs]. Devolve pivot e estabelecimentos para conferência.
({CategoryPivot pivot, List<MerchantTotal> merchants}) _medirTudo(
  List<Transaction> txs,
  ReportFilter f,
  CategoryTree tree,
  String rotulo,
) {
  final range = resolveReportRange(f, _hoje);
  final months = monthsOf(range);
  final from = range.from;
  final to = range.to;

  final (matriz, comparativo) = _medir(
    rotulo,
    'monthlyCategoryTotals + categoryComparison',
    () {
      final m = monthlyCategoryTotals(
        txs,
        f,
        from: from,
        to: to,
        tree: tree,
        today: _hoje,
      );
      return (
        m,
        categoryComparison(m, month: _fim, averageMonths: 3, tree: tree),
      );
    },
  );
  expect(comparativo.rows, isNotEmpty);

  final pivot = _medir(
    rotulo,
    'categoryPivot',
    () => categoryPivot(matriz, months: months, tree: tree),
  );

  _medir(rotulo, 'monthlyTrend + 2× movingAverage', () {
    final pontos = monthlyTrend(
      txs,
      f,
      months: months,
      tree: tree,
      today: _hoje,
    );
    movingAverage([for (final p in pontos) p.expenseCents], window: 3);
    movingAverage([for (final p in pontos) p.balanceCents], window: 3);
  });

  _medir(
    rotulo,
    'spendingHeatmap (731 dias)',
    () => spendingHeatmap(txs, f, from: _diaIni, to: _diaFim, tree: tree),
  );

  final merchants = _medir(
    rotulo,
    'topMerchants',
    () => topMerchants(txs, f, from: from, to: to, tree: tree, today: _hoje),
  );

  _medir(
    rotulo,
    'fixedVariableByMonth',
    () =>
        fixedVariableByMonth(txs, f, months: months, tree: tree, today: _hoje),
  );

  _medir(
    rotulo,
    'reportCsv(pivotCsvRows)',
    () => reportCsv(pivotCsvRows(pivot, tree: tree)),
  );

  _medir(
    rotulo,
    'reportCsv(merchantsCsvRows)',
    () => reportCsv(merchantsCsvRows(merchants, tree: tree)),
  );

  return (pivot: pivot, merchants: merchants);
}

void main() {
  final tree = CategoryTree(_categorias());
  final base = _baseSintetica();

  test('base: 20.000 transações em 24 meses com as proporções de §5.32', () {
    expect(base.length, _total);
    expect(
      base.every(
        (t) =>
            YearMonth.fromDate(t.date) >= _inicio &&
            YearMonth.fromDate(t.date) <= _fim,
      ),
      isTrue,
    );
    expect(base.map((t) => YearMonth.fromDate(t.date)).toSet().length, 24);

    double parte(bool Function(Transaction t) cond) =>
        base.where(cond).length / _total;

    expect(
      parte((t) => t.type == TransactionType.income),
      closeTo(0.10, 0.02),
      reason: 'receitas',
    );
    expect(
      parte((t) => t.isInstallment),
      closeTo(0.10, 0.02),
      reason: 'parcelas',
    );
    expect(
      parte((t) => t.recurringId != null),
      closeTo(0.10, 0.02),
      reason: 'recorrentes',
    );
    expect(
      parte((t) => t.importedDescription != null),
      closeTo(0.30, 0.02),
      reason: 'importedDescription',
    );
    expect(
      parte((t) => hasAnyTag(t, const {'VIAGEM'})),
      closeTo(0.30, 0.02),
      reason: 'tag viagem',
    );
    expect(
      parte((t) => t.isPlanned),
      closeTo(0.05, 0.02),
      reason: 'provisionados',
    );
    expect(base.map((t) => t.accountId).whereType<String>().toSet().length, 5);
    expect(base.map((t) => t.cardId).whereType<String>().toSet().length, 8);
  });

  test(
    'filtro (a): período sem escopo; sanidade do pivot e dos estabelecimentos',
    () {
      final filtro = ReportFilter(
        preset: ReportPeriodPreset.custom,
        customFrom: _inicio,
        customTo: _fim,
      );
      final r = _medirTudo(base, filtro, tree, 'a');

      final esperado = base
          .where(
            (t) =>
                t.type == TransactionType.expense &&
                !t.isPlanned &&
                !t.date.isAfter(_hoje),
          )
          .fold<int>(0, (soma, t) => soma + t.amountCents);
      expect(r.pivot.grandTotalCents, esperado);
      expect(r.merchants, isNotEmpty);
    },
  );

  test('filtro (b): cartões, categorias, tag e provisionados', () {
    final filtro = ReportFilter(
      preset: ReportPeriodPreset.custom,
      customFrom: _inicio,
      customTo: _fim,
      cardIds: {for (var i = 1; i <= 4; i++) 'cartao_$i'},
      categoryIds: {for (var r = 0; r < 5; r++) 'r$r'},
      tagKeys: const {'VIAGEM'},
      includePlanned: true,
    );
    _medirTudo(base, filtro, tree, 'b');
  });
}
