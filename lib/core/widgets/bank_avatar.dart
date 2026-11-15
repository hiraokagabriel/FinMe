import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palettes.dart';
import '../theme/app_spacing.dart';

/// Iniciais do banco: 2+ palavras → 1ª letra das 2 primeiras; 1 palavra → 2 primeiras letras.
String bankInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  final words = trimmed.split(RegExp(r'\s+'));
  final letters = words.length >= 2
      ? '${words[0][0]}${words[1][0]}'
      : words[0].length > 2
      ? words[0].substring(0, 2)
      : words[0];
  return letters.toUpperCase();
}

/// Índice estável na paleta de entidades: mesmo nome (sem caixa/espaços nas pontas) → mesma cor.
int bankColorIndex(String name) {
  var hash = 0;
  for (final unit in name.trim().toLowerCase().codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash % kEntityColors.length;
}

/// Quadrado com as iniciais do banco, colorido pela paleta. Nome vazio → "?" neutro.
class BankAvatar extends StatelessWidget {
  const BankAvatar({super.key, required this.bankName, this.size = 24});

  final String bankName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEmpty = bankName.trim().isEmpty;
    final ink = isEmpty
        ? colors.textSecondary
        : Color(kEntityColors[bankColorIndex(bankName)]);
    final fill = isEmpty
        ? colors.textSecondary.withValues(alpha: 0.12)
        : ink.withValues(alpha: 0.18);

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: AppRadius.chipBorder,
        ),
        child: Center(
          child: Text(
            isEmpty ? '?' : bankInitials(bankName),
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}
