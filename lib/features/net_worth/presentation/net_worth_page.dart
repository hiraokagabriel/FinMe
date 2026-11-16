import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/monthly_history.dart' show deltaRatio;
import '../../debts/presentation/debt_dialogs.dart';
import '../../debts/presentation/debts_section.dart';
import '../domain/net_worth.dart';
import 'asset_dialogs.dart';
import 'assets_section.dart';
import 'net_worth_chart.dart';

const _sparkMonths = 12;
const _kpiWidth = 320.0;
const _variationWidth = 140.0;

/// Página Patrimônio (índice 9, SPEC §7.3 Fase 11). Simples: KPI com linha de apoio, ativos e dívidas.
/// Ultra: KPI com variação e sparkline, evolução 12/24 meses e composição.
class NetWorthPage extends StatefulWidget {
  const NetWorthPage({super.key});

  @override
  State<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends State<NetWorthPage> {
  int _months = 12;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.ledger, s.settings]),
      builder: (context, _) {
        final ultra = s.settings.value.mode == AppMode.ultra;
        final hideValues = s.settings.value.hideValues;
        final history = s.ledger.netWorthHistory;
        final last = history.last;
        final prev = history.length > 1 ? history[history.length - 2] : last;
        final wide = MediaQuery.sizeOf(context).width >= 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Patrimônio',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => showDebtForm(context),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Nova dívida'),
                ),
                FilledButton.icon(
                  onPressed: () => showAssetForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo ativo'),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? AppSpace.xl : AppSpace.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Kpi(
                          last: last,
                          prev: prev,
                          points: history,
                          ultra: ultra,
                        ),
                        if (ultra) ...[
                          const SizedBox(height: AppSpace.lg),
                          SectionCard(
                            title: 'Evolução',
                            trailing: SegmentedButton<int>(
                              key: const Key('net-worth-range'),
                              segments: const <ButtonSegment<int>>[
                                ButtonSegment(
                                  value: 12,
                                  label: Text('12 meses'),
                                ),
                                ButtonSegment(
                                  value: 24,
                                  label: Text('24 meses'),
                                ),
                              ],
                              selected: {_months},
                              onSelectionChanged: (v) =>
                                  setState(() => _months = v.first),
                            ),
                            child: NetWorthChart(
                              points: history.sublist(
                                max(0, history.length - _months),
                              ),
                              hideValues: hideValues,
                            ),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          _Breakdown(last: last, prev: prev),
                        ],
                        const SizedBox(height: AppSpace.lg),
                        const AssetsSection(),
                        const SizedBox(height: AppSpace.lg),
                        const DebtsSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// KPI "Patrimônio líquido". Ultra: variação vs. mês anterior e sparkline. Simples: linha de apoio.
class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.last,
    required this.prev,
    required this.points,
    required this.ultra,
  });

  final NetWorthPoint last;
  final NetWorthPoint prev;
  final List<NetWorthPoint> points;
  final bool ultra;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final support = textTheme.bodySmall?.copyWith(color: c.textSecondary);
    final spark = points.sublist(max(0, points.length - _sparkMonths));

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: _kpiWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KpiTile(
              key: const Key('net-worth-kpi'),
              label: 'Patrimônio líquido',
              cents: last.netCents,
              color: last.netCents < 0 ? c.danger : null,
              trend: ultra
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpace.sm,
                          children: [
                            DeltaBadge(
                              ratio: deltaRatio(prev.netCents, last.netCents),
                            ),
                            MoneyText(
                              last.netCents - prev.netCents,
                              signed: true,
                              colorBySign: true,
                              style: support,
                            ),
                            Text(' vs. mês anterior', style: support),
                          ],
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Sparkline(values: [for (final p in spark) p.netCents]),
                      ],
                    )
                  : null,
            ),
            if (!ultra) ...[
              const SizedBox(height: AppSpace.sm),
              Wrap(
                children: [
                  Text('Contas ', style: support),
                  MoneyText(last.accountsCents, style: support),
                  Text(' · Ativos ', style: support),
                  MoneyText(last.assetsCents, style: support),
                  Text(' · A receber ', style: support),
                  MoneyText(last.receivableCents, style: support),
                  Text(' · Dívidas ', style: support),
                  MoneyText(last.liabilitiesCents, style: support),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Composição do patrimônio (Ultra). Passivos aparecem positivos; a variação é a contribuição ao líquido.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.last, required this.prev});

  final NetWorthPoint last;
  final NetWorthPoint prev;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final note = textTheme.bodySmall?.copyWith(color: c.textSecondary);
    return SectionCard(
      title: 'Composição',
      child: Column(
        key: const Key('net-worth-breakdown'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: _variationWidth,
                child: Text(
                  'vs. mês anterior',
                  textAlign: TextAlign.end,
                  style: note,
                ),
              ),
            ],
          ),
          _BreakRow(
            label: 'Contas',
            cents: last.accountsCents,
            variation: last.accountsCents - prev.accountsCents,
          ),
          _BreakRow(
            label: 'Ativos',
            cents: last.assetsCents,
            variation: last.assetsCents - prev.assetsCents,
          ),
          _BreakRow(
            label: 'A receber',
            cents: last.receivableCents,
            variation: last.receivableCents - prev.receivableCents,
          ),
          _BreakRow(
            label: '− A pagar (devo)',
            cents: last.payableCents,
            variation: prev.payableCents - last.payableCents,
          ),
          _BreakRow(
            label: '− Dívida de cartão',
            cents: last.cardDebtCents,
            variation: prev.cardDebtCents - last.cardDebtCents,
            note: 'Faturas em aberto e parcelas futuras já lançadas',
          ),
          const Divider(height: AppSpace.lg),
          _BreakRow(
            label: '= Patrimônio líquido',
            cents: last.netCents,
            variation: last.netCents - prev.netCents,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _BreakRow extends StatelessWidget {
  const _BreakRow({
    required this.label,
    required this.cents,
    required this.variation,
    this.note,
    this.bold = false,
  });

  final String label;
  final int cents;
  final int variation;
  final String? note;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (note != null)
                  Text(
                    note!,
                    style: textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          MoneyText(cents, style: style),
          SizedBox(
            width: _variationWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: MoneyText(variation, signed: true, colorBySign: true),
            ),
          ),
        ],
      ),
    );
  }
}
