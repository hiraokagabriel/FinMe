import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/app_scope.dart';
import '../../../app/ledger.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/year_month.dart';
import '../../categories/domain/category_tree.dart';
import '../../net_worth/domain/net_worth.dart';
import '../../transactions/domain/tags.dart';
import '../domain/category_pivot.dart';
import '../domain/category_reports.dart';
import '../domain/merchant_report.dart';
import '../domain/monthly_flow.dart';
import '../domain/report_csv.dart';
import '../domain/report_filter.dart';
import '../domain/spending_heatmap.dart';

/// Teto do histórico de patrimônio do relatório (SPEC §9.9); o Ledger guarda só 24.
const int _netWorthReportMaxMonths = 120;

/// Cache dos relatórios por filtro (SPEC §6.4). Fica fora do Ledger: o filtro é estado de tela.
/// Zera o cache quando o Ledger notifica ou quando o filtro muda.
/// Filtro, relatório e média ficam no registro `reports` de `services.uiState` (SPEC §9.8).
class ReportsController extends ChangeNotifier {
  ReportsController(this.services) {
    services.ledger.addListener(_onLedgerChanged);
    _restore();
  }

  static const _id = 'reports';

  final AppServices services;

  ReportFilter _filter = ReportFilter();
  ReportKind _selected = ReportKind.trend;
  int _averageMonths = 3;

  // Cache. `_matrix` é compartilhada por comparativo e pivot.
  ReportRange? _range;
  MonthCategoryTotals? _matrix;
  CategoryComparison? _comparison;
  CategoryPivot? _pivot;
  List<TrendPoint>? _trend;
  List<int?>? _expenseAverage;
  List<int?>? _balanceAverage;
  SpendingHeatmap? _heatmap;
  List<MerchantTotal>? _merchants;
  List<FixedVariableMonth>? _fixedVariable;
  List<NetWorthPoint>? _netWorth;

  /// Lê o registro de tela. Ausente ou corrompido → padrões; ids removidos saem do filtro.
  void _restore() {
    final rows = services.uiState.loadAll().where((m) => m['id'] == _id);
    final saved = rows.isEmpty ? const <String, dynamic>{} : rows.first;
    final rawFilter = saved['filter'];
    _filter =
        ReportFilter.fromMap(
          rawFilter is Map<String, dynamic> ? rawFilter : const {},
        ).withKnownIds(
          accountIds: {for (final a in services.accounts.all) a.id},
          cardIds: {for (final c in services.cards.all) c.id},
          categoryIds: {for (final c in services.categories.all) c.id},
          tagKeys: {for (final t in services.ledger.allTags) tagKey(t)},
        );
    _selected =
        ReportKind.values.asNameMap()[saved['selected']] ?? ReportKind.trend;
    _averageMonths = saved['averageMonths'] == 6 ? 6 : 3;
  }

  /// Sem await: perder o estado de tela não é erro. Não toca `settings` nem o Ledger.
  void _save() {
    unawaited(
      services.uiState
          .put(_id, {
            'id': _id,
            'filter': _filter.toMap(),
            'selected': _selected.name,
            'averageMonths': _averageMonths,
          })
          .catchError(
            (Object e) => debugPrint('Relatórios: falha ao gravar estado: $e'),
          ),
    );
  }

  ReportFilter get filter => _filter;

  set filter(ReportFilter value) {
    if (value == _filter) {
      return;
    }
    _filter = value;
    _clearCache();
    _save();
    notifyListeners();
  }

  ReportKind get selected => _selected;

  set selected(ReportKind value) {
    if (value == _selected) {
      return;
    }
    _selected = value;
    _save();
    notifyListeners();
  }

  int get averageMonths => _averageMonths;

  /// Só 3 ou 6 meses; outro valor é ignorado. Zera só o comparativo.
  set averageMonths(int value) {
    if ((value != 3 && value != 6) || value == _averageMonths) {
      return;
    }
    _averageMonths = value;
    _comparison = null;
    _save();
    notifyListeners();
  }

  bool get ultra => services.settings.value.mode == AppMode.ultra;

  List<ReportKind> get available => ultra ? kUltraReports : kSimpleReports;

  ReportKind get current =>
      available.contains(_selected) ? _selected : available.first;

  ReportFilter get effectiveFilter => ultra ? _filter : _filter.periodOnly;

  ReportRange get range =>
      _range ??= resolveReportRange(effectiveFilter, services.ledger.today);

  CategoryTree get _tree => services.ledger.categoryTree;

  MonthCategoryTotals get _monthlyTotals {
    final r = range;
    final back = r.to.addMonths(-6);
    final from = back < r.from ? back : r.from;
    return _matrix ??= monthlyCategoryTotals(
      services.transactions.all,
      effectiveFilter,
      from: from,
      to: r.to,
      tree: _tree,
      today: services.ledger.today,
    );
  }

  CategoryComparison get comparison => _comparison ??= categoryComparison(
    _monthlyTotals,
    month: range.to,
    averageMonths: ultra ? _averageMonths : 3,
    tree: _tree,
  );

  CategoryPivot get pivot => _pivot ??= categoryPivot(
    _monthlyTotals,
    months: monthsOf(range),
    tree: _tree,
  );

  List<TrendPoint> get trend => _trend ??= monthlyTrend(
    services.transactions.all,
    effectiveFilter,
    months: monthsOf(range),
    tree: _tree,
    today: services.ledger.today,
  );

  List<int?> get expenseAverage => _expenseAverage ??= movingAverage([
    for (final p in trend) p.expenseCents,
  ]);

  List<int?> get balanceAverage => _balanceAverage ??= movingAverage([
    for (final p in trend) p.balanceCents,
  ]);

  SpendingHeatmap get heatmap {
    final end = range.to.lastDay;
    final today = services.ledger.today;
    final to = effectiveFilter.includePlanned || !end.isAfter(today)
        ? end
        : today;
    return _heatmap ??= spendingHeatmap(
      services.transactions.all,
      effectiveFilter,
      from: range.from.firstDay,
      to: to,
      tree: _tree,
    );
  }

  List<MerchantTotal> get merchants => _merchants ??= topMerchants(
    services.transactions.all,
    effectiveFilter,
    from: range.from,
    to: range.to,
    tree: _tree,
    today: services.ledger.today,
  );

  List<FixedVariableMonth> get fixedVariable =>
      _fixedVariable ??= fixedVariableByMonth(
        services.transactions.all,
        effectiveFilter,
        months: monthsOf(range),
        tree: _tree,
        today: services.ledger.today,
      );

  /// Até 24 meses desde o início do período: recorte do Ledger. Mais longo: histórico próprio (SPEC §9.9).
  List<NetWorthPoint> get netWorth => _netWorth ??= _netWorthOf(range);

  List<NetWorthPoint> _netWorthOf(ReportRange r) {
    final today = services.ledger.today;
    final cur = YearMonth.fromDate(today);
    final span = (cur.year - r.from.year) * 12 + cur.month - r.from.month + 1;
    final history = span <= Ledger.netWorthMonths
        ? services.ledger.netWorthHistory
        : netWorthHistory(
            accounts: services.accounts.all,
            cards: services.cards.all,
            transactions: services.transactions.all,
            assets: services.assets.all,
            debts: services.debts.all,
            today: today,
            months: span < _netWorthReportMaxMonths
                ? span
                : _netWorthReportMaxMonths,
          );
    return [
      for (final p in history)
        if (p.month >= r.from && p.month <= r.to) p,
    ];
  }

  List<String> ignoredFor(ReportKind k) => ignoredFilters(k, effectiveFilter);

  String csvFor(ReportKind k) => reportCsv(switch (k) {
    ReportKind.categoryComparison => comparisonCsvRows(
      comparison,
      tree: _tree,
      includeChildren: ultra,
    ),
    ReportKind.trend => trendCsvRows(
      trend,
      expenseAverage: expenseAverage,
      balanceAverage: balanceAverage,
    ),
    ReportKind.pivot => pivotCsvRows(pivot, tree: _tree),
    ReportKind.heatmap => heatmapCsvRows(heatmap),
    ReportKind.topMerchants => merchantsCsvRows(merchants, tree: _tree),
    ReportKind.fixedVariable => fixedVariableCsvRows(fixedVariable),
    ReportKind.netWorth => netWorthCsvRows(netWorth),
  });

  String csvFileName(ReportKind k) {
    final slug = reportKindSlug(k);
    final r = range;
    return k == ReportKind.categoryComparison
        ? 'finme-$slug-${r.to.key}.csv'
        : 'finme-$slug-${r.from.key}_${r.to.key}.csv';
  }

  void _clearCache() {
    _range = null;
    _matrix = null;
    _comparison = null;
    _pivot = null;
    _trend = null;
    _expenseAverage = null;
    _balanceAverage = null;
    _heatmap = null;
    _merchants = null;
    _fixedVariable = null;
    _netWorth = null;
  }

  void _onLedgerChanged() {
    _clearCache();
    notifyListeners();
  }

  @override
  void dispose() {
    services.ledger.removeListener(_onLedgerChanged);
    super.dispose();
  }
}
