import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/layout.dart';
import '../domain/report_filter.dart';
import 'category_comparison_view.dart';
import 'fixed_variable_view.dart';
import 'heatmap_view.dart';
import 'merchants_view.dart';
import 'net_worth_report_view.dart';
import 'pivot_view.dart';
import 'report_filter_bar.dart';
import 'reports_controller.dart';
import 'trend_view.dart';

const _listWidth = 200.0;
const _tileHeight = 40.0;
const _csvGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);

/// Grava o CSV e devolve `false` quando o usuário cancela. Lança em caso de erro.
typedef SaveReportCsv = Future<bool> Function(String suggestedName, String csv);

/// Ícone de cada relatório (SPEC §7.3 Fase 12).
IconData reportKindIcon(ReportKind k) => switch (k) {
  ReportKind.categoryComparison => Icons.compare_arrows,
  ReportKind.trend => Icons.bar_chart,
  ReportKind.pivot => Icons.grid_on,
  ReportKind.heatmap => Icons.calendar_view_month,
  ReportKind.topMerchants => Icons.storefront_outlined,
  ReportKind.fixedVariable => Icons.pie_chart_outline,
  ReportKind.netWorth => Icons.account_balance_outlined,
};

Future<bool> _saveCsvFile(String suggestedName, String csv) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [_csvGroup],
  );
  if (location == null) {
    return false;
  }
  await File(location.path).writeAsString(csv);
  return true;
}

/// Página Relatórios (índice 10, SPEC §7.3 Fase 12): filtros fixos, lista lateral e a view do relatório atual.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.controller, this.saveCsv});

  final ReportsController controller;

  /// Nulo usa o diálogo de salvar do sistema; testes injetam um falso.
  final SaveReportCsv? saveCsv;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ultra = controller.ultra;
        final current = controller.current;
        final ignored = controller.ignoredFor(current);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Relatórios',
              actions: [
                OutlinedButton.icon(
                  key: const Key('report-export'),
                  onPressed: () => _export(context, current),
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar CSV'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xl,
                vertical: AppSpace.sm,
              ),
              child: ReportFilterBar(
                // Chave pelo preset: o dropdown usa initialValue e precisa ser recriado quando o preset muda.
                key: ValueKey(controller.filter.preset),
                filter: controller.filter,
                range: controller.range,
                ultra: ultra,
                onChanged: (f) => controller.filter = f,
                accounts: services.accounts.all,
                cards: services.cards.all,
                categoryTree: services.ledger.categoryTree,
                tags: services.ledger.allTags,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _listWidth,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.sm,
                      ),
                      itemCount: controller.available.length,
                      itemBuilder: (context, i) {
                        final kind = controller.available[i];
                        return _ReportTile(
                          kind: kind,
                          selected: kind == current,
                          onTap: () => controller.selected = kind,
                        );
                      },
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (ignored.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpace.lg,
                              AppSpace.md,
                              AppSpace.lg,
                              0,
                            ),
                            child: Text(
                              'Filtros ignorados neste relatório: ${ignored.join(', ')}',
                              key: const Key('report-ignored'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                            ),
                          ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: AppMotion.normal,
                            switchInCurve: AppMotion.curve,
                            child: KeyedSubtree(
                              key: ValueKey(current),
                              child: _report(current, services, ultra),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Dados vêm do controller (cache); a view só desenha.
  Widget _report(ReportKind k, AppServices s, bool ultra) {
    final tree = s.ledger.categoryTree;
    final hideValues = s.settings.value.hideValues;
    return switch (k) {
      ReportKind.categoryComparison => CategoryComparisonView(
        data: controller.comparison,
        tree: tree,
        ultra: ultra,
        flow: controller.effectiveFilter.flow,
        isCurrentMonth:
            controller.comparison.month == YearMonth.fromDate(s.ledger.today),
        onAverageMonthsChanged: (m) => controller.averageMonths = m,
      ),
      ReportKind.trend => TrendView(
        points: controller.trend,
        expenseAverage: controller.expenseAverage,
        balanceAverage: controller.balanceAverage,
        ultra: ultra,
        hideValues: hideValues,
      ),
      ReportKind.pivot => PivotView(pivot: controller.pivot, tree: tree),
      ReportKind.heatmap => HeatmapView(
        heatmap: controller.heatmap,
        hideValues: hideValues,
      ),
      ReportKind.topMerchants => MerchantsView(
        merchants: controller.merchants,
        tree: tree,
        ultra: ultra,
      ),
      ReportKind.fixedVariable => FixedVariableView(
        months: controller.fixedVariable,
        hideValues: hideValues,
      ),
      ReportKind.netWorth => NetWorthReportView(
        points: controller.netWorth,
        hideValues: hideValues,
      ),
    };
  }

  Future<void> _export(BuildContext context, ReportKind k) async {
    final messenger = ScaffoldMessenger.of(context);
    final save = saveCsv ?? _saveCsvFile;
    try {
      final saved = await save(
        controller.csvFileName(k),
        // BOM UTF-8 para o Excel reconhecer acentos.
        '﻿${controller.csvFor(k)}',
      );
      if (saved) {
        messenger.showSnackBar(
          const SnackBar(content: Text('CSV exportado (valores reais).')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível exportar o CSV.')),
      );
    }
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ReportKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
      child: InkWell(
        key: Key('report-tab-${kind.name}'),
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: _tileHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          decoration: BoxDecoration(
            color: selected ? colors.primarySubtle : null,
            borderRadius: AppRadius.cardBorder,
          ),
          child: Row(
            children: [
              Icon(
                reportKindIcon(kind),
                size: 18,
                color: selected ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  reportKindLabel(kind),
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
