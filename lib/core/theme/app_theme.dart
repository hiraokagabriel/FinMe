import 'package:flutter/material.dart';

/// Tokens visuais do FinMe
/// Fonte da verdade: CLAUDE.md § Padrões visuais
/// NUNCA use valores hex diretamente nos widgets; importe este arquivo.
abstract final class AppColors {
  // ── Superfícies ──────────────────────────────────────────────
  static const Color background      = Color(0xFFF5F7FA);
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color sidebar         = Color(0xFFE9EDF2);

  // ── Superfícies — Modo Escuro ────────────────────────────────
  static const Color backgroundDark  = Color(0xFF121212);
  static const Color surfaceDark     = Color(0xFF1E1E1E);
  static const Color sidebarDark     = Color(0xFF2C2C2C);

  // ── Marca ────────────────────────────────────────────────────
  static const Color primary         = Color(0xFF42A5F5);
  static const Color primarySubtle   = Color(0xFFD3EAFD);

  // ── Marca — Modo Escuro ──────────────────────────────────────
  static const Color primaryDark        = Color(0xFF81D4FA);
  static const Color primarySubtleDark  = Color(0xFF1A2D40);

  // ── Conteúdo ─────────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFF202124);
  static const Color textSecondary   = Color(0xFF5F6368);

  // ── Conteúdo — Modo Escuro ───────────────────────────────────
  static const Color textPrimaryDark    = Color(0xFFE8EAED);
  static const Color textSecondaryDark  = Color(0xFF9AA0A6);

  // ── Gráfico ──────────────────────────────────────────────────
  static const Color chartBar        = Color(0xFF42A5F5);
  static const Color chartBarDark    = Color(0xFF81D4FA);

  // ── Status ───────────────────────────────────────────────────
  static const Color warning         = Color(0xFFFF9800);
  static const Color danger          = Color(0xFFE53935);

  // ── Status — Modo Escuro ─────────────────────────────────────
  static const Color warningDark     = Color(0xFFFFB74D);
  static const Color dangerDark      = Color(0xFFEF5350);

  // ── Utilitários internos ─────────────────────────────────────
  static const Color _divider        = Color(0x1F5F6368);
  static const Color _dividerDark    = Color(0x289AA0A6);
  static Color get divider => _divider;
  static Color get dividerDark => _dividerDark;

  // Barra de limite
  static const Color limitLow        = Color(0xFF43A047);
  static const Color limitMid        = Color(0xFFFF9800);
  static const Color limitHigh       = Color(0xFFE53935);
  static const Color limitTrack      = Color(0xFFE0E0E0);
  static const Color limitTrackDark  = Color(0xFF3A3A3A);
}

/// Raios de borda padrão
abstract final class AppRadius {
  static const double card    = 8;
  static const double chip    = 4;
  static const double full    = 999;
}

/// Espaçamentos (múltiplos de 4 px)
abstract final class AppSpacing {
  static const double xs  =  4;
  static const double sm  =  8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double h   = 32;
}

/// Estilos de texto reutilizáveis
abstract final class AppText {
  static const TextStyle screenTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle amount = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}

/// ThemeData do FinMe — Modo Claro
ThemeData finMeLightTheme() => _buildTheme(dark: false);

/// ThemeData do FinMe — Modo Escuro
ThemeData finMeDarkTheme() => _buildTheme(dark: true);

ThemeData _buildTheme({required bool dark}) {
  final bg        = dark ? AppColors.backgroundDark  : AppColors.background;
  final surface   = dark ? AppColors.surfaceDark     : AppColors.surface;
  final sidebar   = dark ? AppColors.sidebarDark     : AppColors.sidebar;
  final primary   = dark ? AppColors.primaryDark     : AppColors.primary;
  final subtle    = dark ? AppColors.primarySubtleDark : AppColors.primarySubtle;
  final txtPri    = dark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  final txtSec    = dark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  final divider   = dark ? AppColors.dividerDark     : AppColors.divider;
  final danger    = dark ? AppColors.dangerDark      : AppColors.danger;
  final warning   = dark ? AppColors.warningDark     : AppColors.warning;
  final limitTrack= dark ? AppColors.limitTrackDark  : AppColors.limitTrack;

  final scheme = dark
      ? ColorScheme.dark(
          primary:    primary,
          onPrimary:  AppColors.backgroundDark,
          secondary:  subtle,
          onSecondary: txtPri,
          surface:    surface,
          onSurface:  txtPri,
          error:      danger,
          onError:    AppColors.backgroundDark,
        )
      : ColorScheme.light(
          primary:    primary,
          onPrimary:  Colors.white,
          secondary:  subtle,
          onSecondary: txtPri,
          surface:    surface,
          onSurface:  txtPri,
          error:      danger,
          onError:    Colors.white,
        );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,

    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: txtPri,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      titleTextStyle: AppText.screenTitle.copyWith(color: txtPri),
      iconTheme: IconThemeData(color: txtPri),
    ),

    cardTheme: CardThemeData(
      color: surface,
      elevation: dark ? 0 : 1,
      shadowColor: const Color(0x145F6368),
      shape: RoundedRectangleBorder(
        borderRadius:
            const BorderRadius.all(Radius.circular(AppRadius.card)),
        side: BorderSide(color: divider, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    dividerTheme: DividerThemeData(
      color: divider,
      thickness: 1,
      space: 1,
    ),

    drawerTheme: DrawerThemeData(
      backgroundColor: sidebar,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: sidebar,
      selectedIconTheme: IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: txtSec),
      selectedLabelTextStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: primary),
      unselectedLabelTextStyle:
          TextStyle(fontSize: 12, color: txtSec),
      indicatorColor: subtle,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: dark ? AppColors.backgroundDark : Colors.white,
        textStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        side: BorderSide(color: primary),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: dark ? AppColors.backgroundDark : Colors.white,
      elevation: 2,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      labelStyle: TextStyle(fontSize: 14, color: txtSec),
      hintStyle: TextStyle(fontSize: 14, color: txtSec),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide(color: divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide(color: divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide(color: danger),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    ),

    textTheme: TextTheme(
      titleLarge:  AppText.screenTitle.copyWith(color: txtPri),
      titleMedium: AppText.sectionLabel.copyWith(color: txtPri),
      bodyLarge:   AppText.body.copyWith(color: txtPri),
      bodyMedium:  AppText.body.copyWith(color: txtPri),
      bodySmall:   AppText.secondary.copyWith(color: txtSec),
      labelSmall:  AppText.badge.copyWith(color: txtPri),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? AppColors.surfaceDark : AppColors.textPrimary,
      contentTextStyle: TextStyle(
          color: dark ? txtPri : Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card)),
      behavior: SnackBarBehavior.floating,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card)),
      titleTextStyle: AppText.screenTitle.copyWith(color: txtPri),
      contentTextStyle: AppText.body.copyWith(color: txtPri),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return txtSec;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return subtle;
        return sidebar;
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(
          dark ? AppColors.backgroundDark : Colors.white),
      side: BorderSide(color: divider, width: 1.5),
    ),

    listTileTheme: ListTileThemeData(
      tileColor: surface,
      iconColor: txtSec,
      titleTextStyle: AppText.body.copyWith(color: txtPri),
      subtitleTextStyle: AppText.secondary.copyWith(color: txtSec),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: limitTrack,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: divider),
      ),
      textStyle: AppText.body.copyWith(color: txtPri),
    ),
  );
}
