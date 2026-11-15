import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'dashboard_sections.dart';
import 'dashboard_summary.dart';

/// Painel: KPIs, alerta de saldo negativo, faturas, vencimentos e gastos por categoria.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.ledger,
      builder: (context, _) {
        final ultra = s.settings.value.mode == AppMode.ultra;
        final summary = DashboardSummary.of(s.ledger, ultra: ultra);
        return Column(
          children: [
            const PageHeader(title: 'Visão geral'),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(
                      width < 600 ? AppSpace.lg : AppSpace.xl,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: _DashboardBody(
                          summary: summary,
                          ultra: ultra,
                          wide: width >= 1100,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Corpo rolável: largura ≥ 1100 usa duas colunas; senão, uma coluna.
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.summary,
    required this.ultra,
    required this.wide,
  });

  final DashboardSummary summary;
  final bool ultra;
  final bool wide;

  static const _gap = SizedBox(height: AppSpace.lg);

  @override
  Widget build(BuildContext context) {
    final invoices = InvoicesCard(rows: summary.invoices, ultra: ultra);
    final upcoming = UpcomingCard(items: summary.upcoming);
    final categories = CategoriesCard(rows: summary.categories, ultra: ultra);
    final negativeDate = summary.firstNegativeDate;
    final columns = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: invoices),
              const SizedBox(width: AppSpace.lg),
              Expanded(child: Column(children: [upcoming, _gap, categories])),
            ],
          )
        : Column(children: [invoices, _gap, upcoming, _gap, categories]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardKpiRow(summary: summary),
        if (negativeDate != null) ...[
          _gap,
          NegativeBalanceBanner(
            date: negativeDate,
            accounts: ultra ? summary.negativeAccounts : const [],
          ),
        ],
        _gap,
        columns,
      ],
    );
  }
}
