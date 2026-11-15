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

/// Codepoints de ícones de categoria (`IconData.fontFamily` é MaterialIcons).
final List<int> kCategoryIcons = [
  Icons.restaurant.codePoint,
  Icons.shopping_cart.codePoint,
  Icons.directions_car.codePoint,
  Icons.home.codePoint,
  Icons.local_hospital.codePoint,
  Icons.school.codePoint,
  Icons.movie.codePoint,
  Icons.flight.codePoint,
  Icons.pets.codePoint,
  Icons.fitness_center.codePoint,
  Icons.receipt_long.codePoint,
  Icons.phone_android.codePoint,
  Icons.wifi.codePoint,
  Icons.bolt.codePoint,
  Icons.water_drop.codePoint,
  Icons.local_gas_station.codePoint,
  Icons.checkroom.codePoint,
  Icons.card_giftcard.codePoint,
  Icons.savings.codePoint,
  Icons.work.codePoint,
  Icons.attach_money.codePoint,
  Icons.trending_up.codePoint,
  Icons.subscriptions.codePoint,
  Icons.sports_esports.codePoint,
  Icons.local_cafe.codePoint,
  Icons.build.codePoint,
  Icons.child_care.codePoint,
  Icons.spa.codePoint,
  Icons.more_horiz.codePoint,
  Icons.category.codePoint,
];
