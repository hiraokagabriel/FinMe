import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/forecast.dart';

/// KPIs do topo: saldo atual, menor saldo previsto e primeiro saldo negativo.
class ForecastSummary extends StatelessWidget {
  const ForecastSummary({super.key, required this.forecast});

  final Forecast forecast;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lowest = forecast.lowestBalanceCents;
    final first = forecast.firstNegativeDate;
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.md,
      children: [
        SizedBox(
          width: 200,
          child: KpiTile(
            label: 'Saldo atual',
            cents: forecast.currentTotalCents,
          ),
        ),
        SizedBox(
          width: 200,
          child: KpiTile(
            label: 'Menor saldo previsto',
            cents: lowest,
            color: lowest < 0 ? c.danger : null,
          ),
        ),
        SizedBox(
          width: 200,
          child: _TextKpi(
            label: 'Primeiro saldo negativo',
            value: first == null ? 'Nenhum' : formatDate(first),
          ),
        ),
      ],
    );
  }
}

/// Mesmo layout do [KpiTile], com valor textual (datas).
class _TextKpi extends StatelessWidget {
  const _TextKpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: textTheme.bodySmall),
            const SizedBox(height: AppSpace.xs),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Um card por mês do horizonte: entradas, saídas, faturas e saldo final.
class ForecastMonthCards extends StatelessWidget {
  const ForecastMonthCards({super.key, required this.months});

  final List<ForecastMonth> months;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.md,
      children: [for (final m in months) _MonthCard(month: m)],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month});

  final ForecastMonth month;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final negative = month.endBalanceCents < 0;
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMonthLong(month.month),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(height: AppSpace.lg),
              _Line(
                'Entradas',
                MoneyText(
                  month.incomeCents,
                  signed: true,
                  style: TextStyle(color: c.success),
                ),
              ),
              _Line('Saídas', MoneyText(month.expenseCents)),
              _Line('Faturas', MoneyText(month.invoiceCents)),
              const SizedBox(height: AppSpace.sm),
              _Line(
                'Saldo final',
                MoneyText(
                  month.endBalanceCents,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: negative ? c.danger : c.textPrimary,
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

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          value,
        ],
      ),
    );
  }
}
