import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Barra de consumo do limite. <70% primary, <90% warning, senão danger.
class LimitBar extends StatelessWidget {
  const LimitBar({
    super.key,
    required this.usedCents,
    required this.limitCents,
    this.height = 6,
  });

  final int usedCents;
  final int limitCents;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Razão sem limite: sem limite não há consumo (barra vazia).
    final ratio = limitCents <= 0 ? 0.0 : usedCents / limitCents;
    final color = ratio < 0.7
        ? c.primary
        : ratio < 0.9
        ? c.warning
        : c.danger;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0).toDouble(),
        minHeight: height,
        color: color,
        backgroundColor: c.border,
      ),
    );
  }
}

/// Pílula colorida com texto (fundo `color` α 0.12).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

/// Marca de item provisionado (ainda não efetivado).
class PlannedMarker extends StatelessWidget {
  const PlannedMarker({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Provisionado',
      child: Icon(Icons.schedule, size: size, color: context.colors.warning),
    );
  }
}
