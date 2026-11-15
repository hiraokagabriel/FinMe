import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/bootstrap.dart';
import '../../../app/seed.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Primeira execução: escolhe o modo, opcionalmente cria dados de exemplo e grava `onboardingDone`.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  AppMode _mode = AppMode.simple;
  bool _demo = true;
  bool _busy = false;

  Future<void> _start() async {
    final services = AppScope.of(context);
    setState(() => _busy = true);
    if (_demo) {
      await seedDemo(services);
      await materializeRecurring(services);
    }
    // Atualizar as configurações troca a `home` para a casca principal.
    await services.settings.update(
      (s) => s.copyWith(mode: _mode, onboardingDone: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bem-vindo ao FinMe', style: textTheme.titleLarge),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Veja com antecedência quanto vai sair da conta: faturas, boletos e recorrências em um só lugar.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                _ModeCard(
                  title: 'Simples',
                  description:
                      'Visão enxuta: dinheiro que sai da conta e valores das faturas.',
                  selected: _mode == AppMode.simple,
                  onTap: () => setState(() => _mode = AppMode.simple),
                ),
                const SizedBox(height: AppSpace.sm),
                _ModeCard(
                  title: 'Ultra',
                  description:
                      'Visão detalhada para muitos cartões e contas: limites, provisionados, gráficos e filtros.',
                  selected: _mode == AppMode.ultra,
                  onTap: () => setState(() => _mode = AppMode.ultra),
                ),
                const SizedBox(height: AppSpace.lg),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _demo,
                  onChanged: (v) => setState(() => _demo = v ?? false),
                  title: Text(
                    'Criar dados de exemplo',
                    style: textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    'Bancos fictícios, cartões, contas e transações para explorar o app.',
                    style: textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                FilledButton(
                  onPressed: _busy ? null : _start,
                  child: const Text('Começar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(
          color: selected ? colors.primary : colors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(description, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
