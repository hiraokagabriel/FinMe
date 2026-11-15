import '../utils/enum_utils.dart';

enum AppMode { simple, ultra }

enum ThemePreference { system, light, dark }

/// Configurações globais do app. Campos ausentes ou inválidos em [fromMap]
/// caem nos padrões; enums desconhecidos usam o primeiro valor.
class AppSettings {
  static const defaultForecastMonths = 6;
  static const minForecastMonths = 3;
  static const maxForecastMonths = 24;

  AppSettings({
    this.mode = AppMode.simple,
    this.theme = ThemePreference.system,
    this.hideValues = false,
    int forecastMonths = defaultForecastMonths,
    this.onboardingDone = false,
  }) : forecastMonths = forecastMonths
           .clamp(minForecastMonths, maxForecastMonths)
           .toInt();

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final months = map['forecastMonths'];
    return AppSettings(
      mode: enumByName(AppMode.values, map['mode']),
      theme: enumByName(ThemePreference.values, map['theme']),
      hideValues: map['hideValues'] == true,
      forecastMonths: months is num && months.isFinite
          ? months.toInt()
          : defaultForecastMonths,
      onboardingDone: map['onboardingDone'] == true,
    );
  }

  final AppMode mode;
  final ThemePreference theme;
  final bool hideValues;
  final int forecastMonths;
  final bool onboardingDone;

  AppSettings copyWith({
    AppMode? mode,
    ThemePreference? theme,
    bool? hideValues,
    int? forecastMonths,
    bool? onboardingDone,
  }) {
    return AppSettings(
      mode: mode ?? this.mode,
      theme: theme ?? this.theme,
      hideValues: hideValues ?? this.hideValues,
      forecastMonths: forecastMonths ?? this.forecastMonths,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  Map<String, dynamic> toMap() => {
    'mode': mode.name,
    'theme': theme.name,
    'hideValues': hideValues,
    'forecastMonths': forecastMonths,
    'onboardingDone': onboardingDone,
  };
}
