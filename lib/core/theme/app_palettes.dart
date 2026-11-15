import 'package:flutter/material.dart';

/// Cores fixas de identificação (contas, cartões, categorias). Única exceção a hex fixo fora de app_colors.dart.
const List<int> kEntityColors = [
  0xFF1E88E5, // azul
  0xFF43A047, // verde
  0xFFFB8C00, // laranja
  0xFF8E24AA, // roxo
  0xFFE53935, // vermelho
  0xFF00897B, // teal
  0xFF3949AB, // índigo
  0xFFD81B60, // rosa
  0xFF6D4C41, // marrom
  0xFF546E7A, // cinza-azulado
];

/// Ícones de categoria. A ordem é o índice usado pelo seed (`kCategoryIcons[i]`).
const List<IconData> kCategoryIconData = [
  Icons.restaurant,
  Icons.shopping_cart,
  Icons.directions_car,
  Icons.home,
  Icons.local_hospital,
  Icons.school,
  Icons.movie,
  Icons.flight,
  Icons.pets,
  Icons.fitness_center,
  Icons.receipt_long,
  Icons.phone_android,
  Icons.wifi,
  Icons.bolt,
  Icons.water_drop,
  Icons.local_gas_station,
  Icons.checkroom,
  Icons.card_giftcard,
  Icons.savings,
  Icons.work,
  Icons.attach_money,
  Icons.trending_up,
  Icons.subscriptions,
  Icons.sports_esports,
  Icons.local_cafe,
  Icons.build,
  Icons.child_care,
  Icons.spa,
  Icons.more_horiz,
  Icons.category,
];

/// Codepoints salvos em `TransactionCategory.iconCodePoint`.
final List<int> kCategoryIcons = [
  for (final icon in kCategoryIconData) icon.codePoint,
];

final Map<int, IconData> _iconByCodePoint = {
  for (final icon in kCategoryIconData) icon.codePoint: icon,
};

/// Ícone de um codepoint salvo. Desconhecido (ex.: backup de outra versão) cai em `label_outline`.
IconData categoryIcon(int codePoint) =>
    _iconByCodePoint[codePoint] ?? Icons.label_outline;
