import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/money.dart';
import '../../forecast/domain/forecast.dart';
import '../../forecast/domain/spendable.dart';

/// Eventos listados por linha no detalhamento Ultra; o resto vira "e mais N".
const _maxEventLines = 8;

/// "Posso gastar hoje" (SPEC §5.23, §7.3 Fase 10): primeiro card do Painel.
/// A linha principal mostra o livre e o por dia; "Ver cálculo" abre as parcelas da fórmula.
class SpendableCard extends StatefulWidget {
  const SpendableCard({super.key, required this.data, required this.ultra});

  final SpendableToday data;
  final bool ultra;

  @override
  State<SpendableCard> createState() => _SpendableCardState();
}

class _SpendableCardState extends State<SpendableCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = widget.data;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('spendable-card'),
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Posso gastar hoje', style: textTheme.titleMedium),
          const SizedBox(height: AppSpace.sm),
          d.overcommitted ? _overcommitted(context) : _available(context),
          const SizedBox(height: AppSpace.xs),
          Text(_legend(d), style: textTheme.bodySmall),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('spendable-toggle'),
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? 'Ocultar cálculo' : 'Ver cálculo'),
            ),
          ),
          AnimatedSize(
            key: const ValueKey('spendable-detail'),
            duration: AppMotion.normal,
            curve: AppMotion.curve,
            alignment: Alignment.topCenter,
            child: _open
                ? _Breakdown(data: d, ultra: widget.ultra)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _available(BuildContext context) {
    final c = context.colors;
    final d = widget.data;
    final kpi = AppText.kpi(context);
    final secondary = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(fontSize: 14, color: c.textSecondary);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        MoneyText(d.freeCents, style: kpi),
        Text(' livres · ', style: secondary),
        MoneyText(d.perDayCents, style: kpi),
        Text('/dia até ${formatShortDate(d.untilDate)}', style: secondary),
      ],
    );
  }

  Widget _overcommitted(BuildContext context) {
    final c = context.colors;
    final d = widget.data;
    final body = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: c.danger);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sem folga até ${formatShortDate(d.untilDate)}',
          style: AppText.kpi(context).copyWith(color: c.danger),
        ),
        Row(
          children: [
            Text('Faltam', style: body),
            const SizedBox(width: AppSpace.xs),
            MoneyText(
              -d.freeCents,
              style: body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  String _legend(SpendableToday d) {
    final next = d.nextIncomeDate;
    if (next == null) {
      return 'Sem receita recorrente: considerando até o fim do mês (${_dias(d.days)})';
    }
    return 'Próxima receita: ${d.nextIncomeDescription ?? ''} em ${formatShortDate(next)} (${_dias(d.days)})';
  }
}

/// Detalhamento da fórmula: saldo − faturas − provisionados − reservas = livre ÷ dias.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.data, required this.ultra});

  final SpendableToday data;
  final bool ultra;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = data;
    final until = formatShortDate(d.untilDate);
    final textTheme = Theme.of(context).textTheme;
    final free = textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: d.freeCents <= 0 ? c.danger : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Line(label: 'Saldo das contas', cents: d.balanceCents),
        _Line(
          label: '− Faturas até $until (${d.invoiceEvents.length})',
          cents: d.invoicesCents,
        ),
        if (ultra) _Events(events: d.invoiceEvents),
        _Line(
          label: '− Provisionados até $until (${d.plannedEvents.length})',
          cents: d.plannedCents,
        ),
        if (ultra) _Events(events: d.plannedEvents),
        _Line(label: '− Reservado em metas', cents: d.reservedCents),
        const Divider(height: AppSpace.lg),
        _Line(label: '= Livre', cents: d.freeCents, style: free),
        _Line(label: '÷ ${_dias(d.days)}', cents: d.perDayCents),
      ],
    );
  }
}

/// Linha "rótulo ... valor" do detalhamento.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.cents, this.style});

  final String label;
  final int cents;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final body = style ?? Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: body)),
          MoneyText(cents, style: body),
        ],
      ),
    );
  }
}

/// Eventos de uma parcela (Ultra): data, descrição e valor de saída, em 12 px.
class _Events extends StatelessWidget {
  const _Events({required this.events});

  final List<ForecastEvent> events;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final shown = events.take(_maxEventLines);
    final extra = events.length - _maxEventLines;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.md, bottom: AppSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in shown)
            Row(
              children: [
                Text(formatShortDate(e.date), style: small),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    e.description,
                    style: small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                MoneyText(-e.amountCents, style: small),
              ],
            ),
          if (extra > 0) Text('e mais $extra', style: small),
        ],
      ),
    );
  }
}

/// "1 dia" / "20 dias".
String _dias(int n) => n == 1 ? '1 dia' : '$n dias';
