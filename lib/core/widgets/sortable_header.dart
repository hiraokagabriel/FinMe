import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Cabeçalho de coluna. Sem `onTap` é só o rótulo (estilo antigo); com `onTap` ganha seta e toque.
/// Seta só na coluna ativa; girada quando descendente.
class SortableHeaderLabel extends StatelessWidget {
  const SortableHeaderLabel({
    super.key,
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback? onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (onTap == null) {
      final text = Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
            .copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
      );
      return alignEnd
          ? Align(alignment: Alignment.centerRight, child: text)
          : text;
    }
    final color = active ? c.textPrimary : c.textSecondary;
    final arrow = AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: AppMotion.fast,
      child: AnimatedRotation(
        turns: ascending ? 0 : 0.5,
        duration: AppMotion.fast,
        child: Icon(Icons.arrow_upward, size: 14, color: color),
      ),
    );
    final text = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
    // Em coluna alinhada à direita, a seta fica antes do texto para o texto encostar na borda.
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd
          ? [arrow, const SizedBox(width: AppSpace.xs), text]
          : [text, const SizedBox(width: AppSpace.xs), arrow],
    );
    final aligned = alignEnd
        ? Align(alignment: Alignment.centerRight, child: row)
        : row;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.chipBorder,
      child: aligned,
    );
  }
}
