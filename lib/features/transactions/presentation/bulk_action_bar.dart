import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';

/// Ação da barra. `onPressed` null = desabilitada; `destructive` = cor `danger`.
/// A página monta a lista; novas ações (ex.: Tags, Fase 10) entram sem mudar a barra.
class BulkAction {
  const BulkAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
}

/// Barra de ações sobre a seleção visível da tabela (Ultra). Só aparece com seleção não vazia.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.count,
    required this.actions,
    required this.onClear,
  });

  final int count;
  final List<BulkAction> actions;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: AppSpace.md, right: AppSpace.xs),
      decoration: BoxDecoration(
        color: colors.primarySubtle,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: AppMotion.fast,
            switchInCurve: AppMotion.curve,
            child: Text(
              count == 1 ? '1 selecionada' : '$count selecionadas',
              key: ValueKey(count),
              style: AppText.tabular(
                theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final action in actions)
                    if (!action.destructive) _button(action, colors),
                ],
              ),
            ),
          ),
          // Destrutivas ficam fixas à direita: nunca saem da área visível.
          for (final action in actions)
            if (action.destructive) _button(action, colors),
          IconButton(
            tooltip: 'Limpar seleção (Esc)',
            icon: const Icon(Icons.close, size: 18),
            color: colors.textSecondary,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }

  Widget _button(BulkAction action, AppColors colors) => TextButton.icon(
    onPressed: action.onPressed,
    icon: Icon(action.icon, size: 18),
    label: Text(action.label),
    style: TextButton.styleFrom(
      foregroundColor: action.destructive ? colors.danger : colors.textPrimary,
      disabledForegroundColor: colors.textSecondary,
    ),
  );
}
