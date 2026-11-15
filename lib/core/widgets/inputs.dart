import 'package:flutter/material.dart';

import '../models/year_month.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

/// Seletor de mês: chevrons + "Novembro 2026".
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final YearMonth value;
  final ValueChanged<YearMonth> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(value.prev()),
        ),
        SizedBox(
          width: 160,
          child: Text(
            formatMonthLong(value),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(value.next()),
        ),
      ],
    );
  }
}

/// Campo de data clicável; abre o seletor nativo (2000..2100).
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Data',
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;

  static final _first = DateTime(2000);
  static final _last = DateTime(2100);

  @override
  Widget build(BuildContext context) {
    // showDatePicker exige initialDate dentro de [first, last].
    final initial = value.isBefore(_first)
        ? _first
        : (value.isAfter(_last) ? _last : value);
    return InkWell(
      borderRadius: AppRadius.cardBorder,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: _first,
          lastDate: _last,
        );
        if (picked != null && context.mounted) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(
            Icons.calendar_today,
            size: 18,
            color: context.colors.textSecondary,
          ),
        ),
        child: Text(formatDate(value)),
      ),
    );
  }
}

/// Diálogo de confirmação. Retorna `false` ao cancelar ou fechar.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: ctx.colors.danger,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
