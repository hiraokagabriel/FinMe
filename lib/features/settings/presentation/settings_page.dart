import 'package:flutter/material.dart';

import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/theme_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../categories/presentation/categories_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _currency;
  late String _dateFormat;

  static const _currencies = ['BRL', 'USD', 'EUR', 'GBP', 'JPY'];
  static const _dateFormats = ['dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'];

  @override
  void initState() {
    super.initState();
    final prefs = PreferencesService.instance;
    _currency   = prefs.currency;
    _dateFormat = prefs.dateFormat;
  }

  Future<void> _setCurrency(String value) async {
    await PreferencesService.instance.setCurrency(value);
    setState(() => _currency = value);
  }

  Future<void> _setDateFormat(String value) async {
    await PreferencesService.instance.setDateFormat(value);
    setState(() => _dateFormat = value);
  }

  @override
  Widget build(BuildContext context) {
    final modeController  = AppModeController.instance;
    final themeController = ThemeController.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: AnimatedBuilder(
        animation: Listenable.merge([modeController, themeController]),
        builder: (context, _) {
          final isUltra = modeController.mode == AppMode.ultra;
          final isDark  = themeController.isDark;

          return ListView(
            children: [
              // ── Aparência ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg,
                    AppSpacing.lg, AppSpacing.xs),
                child: Text('Aparência', style: AppText.sectionLabel),
              ),
              SwitchListTile(
                secondary: Icon(
                  isDark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
                title: const Text('Tema escuro'),
                subtitle: Text(
                  isDark ? 'Interface escura ativa' : 'Interface clara ativa',
                ),
                value: isDark,
                onChanged: themeController.setDark,
              ),
              const Divider(height: AppSpacing.h),

              // ── Preferências regionais ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                child: Text('Regional', style: AppText.sectionLabel),
              ),
              ListTile(
                leading: const Icon(Icons.attach_money_outlined),
                title: const Text('Moeda'),
                subtitle: Text(_currency),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _currency,
                    isDense: true,
                    items: _currencies
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: AppText.body),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _setCurrency(v);
                    },
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Formato de data'),
                subtitle: Text(_dateFormat),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dateFormat,
                    isDense: true,
                    items: _dateFormats
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f, style: AppText.body),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _setDateFormat(v);
                    },
                  ),
                ),
              ),
              const Divider(height: AppSpacing.h),

              // ── Modo de uso ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                child: Text('Modo de uso', style: AppText.sectionLabel),
              ),
              RadioListTile<AppMode>(
                value: AppMode.simple,
                groupValue: modeController.mode,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  if (v != null) modeController.setMode(v);
                },
                title: const Text('Modo Simples'),
                subtitle: const Text(
                  'Interface enxuta, foco em resumo rápido. Sem detalhes de cartão ou gráficos avançados.',
                ),
              ),
              RadioListTile<AppMode>(
                value: AppMode.ultra,
                groupValue: modeController.mode,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  if (v != null) modeController.setMode(v);
                },
                title: const Text('Modo Ultra'),
                subtitle: const Text(
                  'Visão completa com gráficos por categoria e cartão, limite de crédito, campos avançados e provisionamento.',
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: isUltra
                    ? _ModeBanner(
                        key: const ValueKey('ultra'),
                        icon: Icons.bolt,
                        accentColor: AppColors.primary,
                        title: 'Modo Ultra ativo',
                        message:
                            'Você está vendo informações completas: gráficos por categoria e cartão, limite de crédito e campos avançados nas transações.',
                      )
                    : _ModeBanner(
                        key: const ValueKey('simple'),
                        icon: Icons.spa_outlined,
                        accentColor: AppColors.limitLow,
                        title: 'Modo Simples ativo',
                        message:
                            'Interface enxuta: apenas data na lista de transações. Campos de cartão e gráficos ficam ocultos.',
                      ),
              ),
              const Divider(height: AppSpacing.h),

              // ── Dados ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                child: Text('Dados', style: AppText.sectionLabel),
              ),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: const Text('Categorias'),
                subtitle: const Text(
                    'Gerenciar categorias de despesa e receita'),
                trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CategoriesPage(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color    accentColor;
  final String   title;
  final String   message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm,
          AppSpacing.lg, AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.sectionLabel.copyWith(color: accentColor),
                ),
                const SizedBox(height: 3),
                Text(message, style: AppText.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
