import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../utils/formatters.dart';

/// Valor monetário em centavos. Respeita `hideValues` (mostra "R$ ••••").
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.cents, {
    super.key,
    this.style,
    this.signed = false,
    this.colorBySign = false,
  });

  final int cents;
  final TextStyle? style;
  final bool signed;
  final bool colorBySign;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final c = context.colors;
        final signColor = !colorBySign || cents == 0
            ? null
            : cents > 0
            ? c.success
            : c.danger;
        final resolved = signColor == null
            ? style
            : (style ?? const TextStyle()).copyWith(color: signColor);
        return Text(
          formatMoney(cents, hidden: settings.value.hideValues, signed: signed),
          style: AppText.tabular(resolved ?? const TextStyle()),
        );
      },
    );
  }
}

/// Campo de valor em reais. Sem [validator], rejeita vazio, inválido e <= 0.
/// Com [validator], ele recebe o valor (null se inválido) e decide a mensagem.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.label = 'Valor',
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(int?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixText: 'R\$ '),
      validator: (text) {
        final cents = parseMoney(text ?? '');
        final custom = validator;
        if (custom != null) {
          return custom(cents);
        }
        return cents == null || cents <= 0 ? 'Informe um valor válido' : null;
      },
    );
  }
}

/// Indicador compacto: rótulo + valor grande (+ variação e legenda opcionais).
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.cents,
    this.color,
    this.caption,
    this.trend,
  });

  final String label;
  final int cents;
  final Color? color;
  final String? caption;
  final Widget? trend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final kpi = AppText.kpi(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: textTheme.bodySmall),
            const SizedBox(height: AppSpace.xs),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              // Padrão centraliza o Stack da troca; aqui o valor é alinhado à esquerda.
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: MoneyText(
                cents,
                key: ValueKey(cents),
                style: color == null ? kpi : kpi.copyWith(color: color),
              ),
            ),
            if (trend != null) ...[const SizedBox(height: AppSpace.xs), trend!],
            if (caption != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(caption!, style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
