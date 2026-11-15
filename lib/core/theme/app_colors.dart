import 'package:flutter/material.dart';

/// Tokens de cor do FinMe. Widgets consomem via `context.colors`, nunca hex direto.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.sidebar,
    required this.primary,
    required this.primarySubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.chartBar,
    required this.warning,
    required this.danger,
    required this.success,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color sidebar;
  final Color primary;
  final Color primarySubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color chartBar;
  final Color warning;
  final Color danger;
  final Color success;
  final Color border;

  static const _lightTextSecondary = Color(0xFF5F6368);
  static const _darkTextSecondary = Color(0xFF9AA0A6);

  static final AppColors light = AppColors(
    background: const Color(0xFFF6F5F2),
    surface: const Color(0xFFFFFFFF),
    sidebar: const Color(0xFFECEAE5),
    primary: const Color(0xFF42A5F5),
    primarySubtle: const Color(0xFFD3EAFD),
    textPrimary: const Color(0xFF202124),
    textSecondary: _lightTextSecondary,
    chartBar: const Color(0xFF42A5F5),
    warning: const Color(0xFFFF9800),
    danger: const Color(0xFFE53935),
    success: const Color(0xFF43A047),
    border: _lightTextSecondary.withValues(alpha: 0.15),
  );

  static final AppColors dark = AppColors(
    background: const Color(0xFF161514),
    surface: const Color(0xFF1F1E1C),
    sidebar: const Color(0xFF2A2826),
    primary: const Color(0xFF81D4FA),
    primarySubtle: const Color(0xFF1A2D40),
    textPrimary: const Color(0xFFE8EAED),
    textSecondary: _darkTextSecondary,
    chartBar: const Color(0xFF81D4FA),
    warning: const Color(0xFFFFB74D),
    danger: const Color(0xFFEF5350),
    success: const Color(0xFF66BB6A),
    border: _darkTextSecondary.withValues(alpha: 0.15),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? sidebar,
    Color? primary,
    Color? primarySubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? chartBar,
    Color? warning,
    Color? danger,
    Color? success,
    Color? border,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      sidebar: sidebar ?? this.sidebar,
      primary: primary ?? this.primary,
      primarySubtle: primarySubtle ?? this.primarySubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      chartBar: chartBar ?? this.chartBar,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      border: border ?? this.border,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySubtle: Color.lerp(primarySubtle, other.primarySubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      chartBar: Color.lerp(chartBar, other.chartBar, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
