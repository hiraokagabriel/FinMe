import 'package:flutter/material.dart';

import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/demo_seed_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/profile_service.dart';
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
  bool _switchingProfile = false;

  static const _currencies  = ['BRL', 'USD', 'EUR', 'GBP', 'JPY'];
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

  Future<void> _toggleDemo(bool enable) async {
    if (_switchingProfile) return;

    final title   = enable ? 'Ativar Modo Demo?'    : 'Desativar Modo Demo?';
    final content = enable
        ? 'Seus dados reais serão preservados. O app será recarregado com dados de exemplo cobrindo 12 meses.\n\nDesative o Modo Demo a qualquer momento para voltar aos seus dados.'
        : 'O app voltará para os seus dados reais. Os dados demo permanecem salvos e podem ser reativados.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),  child: Text(enable ? 'Ativar' : 'Desativar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _switchingProfile = true);
    try {
      final loginId = AuthService.instance.activeLoginId!;
      final target  = enable ? ProfileService.profileDemo : ProfileService.profileDefault;

      await ProfileService.instance.switchTo(loginId, target);
      if (enable) await DemoSeedService.instance.populate();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } finally {
      if (mounted) setState(() => _switchingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeController  = AppModeController.instance;
    final themeController = ThemeController.instance;
    final profileService  = ProfileService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: AnimatedBuilder(
        animation: Listenable.merge([modeController, themeController, profileService]),
        builder: (context, _) {
          final isUltra = modeController.mode == AppMode.ultra;
          final isDark  = themeController.isDark;
          final isDemo  = profileService.isDemoActive;

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
                child: Text('Aparência', style: AppText.sectionLabel),
              ),
              SwitchListTile(
                secondary: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                title: const Text('Tema escuro'),
                subtitle: Text(isDark ? 'Interface escura ativa' : 'Interface clara ativa'),
                value: isDark,
                onChanged: themeController.setDark,
              ),
              const Divider(height: AppSpacing.h),

              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
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
                    items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppText.body))).toList(),
                    onChanged: (v) { if (v != null) _setCurrency(v); },
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
                    items: _dateFormats.map((f) => DropdownMenuItem(value: f, child: Text(f, style: AppText.body))).toList(),
                    onChanged: (v) { if (v != null) _setDateFormat(v); },
                  ),
                ),
              ),
              const Divider(height: AppSpacing.h),

              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                child: Text('Modo de uso', style: AppText.sectionLabel),
              ),
              RadioListTile<AppMode>(
                value: AppMode.simple,
                groupValue: modeController.mode,
                activeColor: AppColors.primary,
                onChanged: (v) { if (v != null) modeController.setMode(v); },
                title: const Text('Modo Simples'),
                subtitle: const Text('Interface enxuta, foco em resumo rápido.'),
              ),
              RadioListTile<AppMode>(
                value: AppMode.ultra,
                groupValue: modeController.mode,
                activeColor: AppColors.primary,
                onChanged: (v) { if (v != null) modeController.setMode(v); },
                title: const Text('Modo Ultra'),
                subtitle: const Text('Visão completa com gráficos, limite de crédito e campos avançados.'),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: isUltra
                    ? _ModeBanner(key: const ValueKey('ultra'),  icon: Icons.bolt,        accentColor: AppColors.primary,  title: 'Modo Ultra ativo',   message: 'Gráficos por categoria e cartão, limite de crédito e campos avançados nas transações.')
                    : _ModeBanner(key: const ValueKey('simple'), icon: Icons.spa_outlined, accentColor: AppColors.limitLow, title: 'Modo Simples ativo', message: 'Interface enxuta: apenas data na lista de transações.'),
              ),
              const Divider(height: AppSpacing.h),

              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                child: Text('Dados', style: AppText.sectionLabel),
              ),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: const Text('Categorias'),
                subtitle: const Text('Gerenciar categorias de despesa e receita'),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CategoriesPage()),
                ),
              ),
              const Divider(height: AppSpacing.h),

              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                child: Text('Benchmark', style: AppText.sectionLabel),
              ),
              SwitchListTile(
                secondary: Icon(Icons.science_outlined, color: isDemo ? AppColors.warning : null),
                title: const Text('Modo Demo'),
                subtitle: const Text(
                  'Preenche o app com dados de exemplo de 12 meses. Seus dados reais são preservados.',
                ),
                value: isDemo,
                onChanged: _switchingProfile ? null : _toggleDemo,
                activeColor: AppColors.warning,
              ),
              if (isDemo)
                _ModeBanner(
                  icon: Icons.science_outlined,
                  accentColor: AppColors.warning,
                  title: 'Modo Demo ativo',
                  message: 'Você está visualizando dados fictícios. Todas as funções do app estão disponíveis. Desative para voltar aos seus dados reais.',
                ),
              if (_switchingProfile)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: AppSpacing.lg),
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
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
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
                Text(title,   style: AppText.sectionLabel.copyWith(color: accentColor)),
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
