import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/hive_init.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() {
    return _OnboardingPageState();
  }
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageCtrl = PageController();
  AppMode? _selectedMode;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToModeStep() {
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _selectMode(AppMode mode) {
    setState(() {
      _selectedMode = mode;
    });
  }

  Future<void> _finish() async {
    if (_selectedMode == null) return;
    await AppModeController.instance.setMode(_selectedMode!);
    await HiveInit.markOnboardingDone();
    if (mounted) {
      await Navigator.pushReplacementNamed(context, AppRouter.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          _SplashStep(onNext: _goToModeStep),
          _ModeStep(
            selectedMode: _selectedMode,
            onSelect: _selectMode,
            onFinish: _finish,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────── SPLASH ────────────────────────

class _SplashStep extends StatelessWidget {
  final VoidCallback onNext;

  const _SplashStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  'F',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'FinMe',
              style: AppText.screenTitle.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Controle financeiro para quem lida\ncom muitos cartões e contas.',
              textAlign: TextAlign.center,
              style: AppText.secondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                child: const Text('Começar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────── SELEÇÃO DE MODO ────────────────────────

class _ModeStep extends StatelessWidget {
  final AppMode? selectedMode;
  final ValueChanged<AppMode> onSelect;
  final VoidCallback onFinish;

  const _ModeStep({
    super.key,
    required this.selectedMode,
    required this.onSelect,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Como você quer usar o FinMe?',
              style: AppText.screenTitle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Você pode mudar isso depois nas configurações.',
              style: AppText.secondary,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _ModeCard(
              title: 'Modo Simples',
              description: 'Visão enxuta. Ideal para quem quer controlar gastos do dia a dia sem complicação.',
              icon: Icons.wb_sunny_outlined,
              selected: selectedMode == AppMode.simple,
              onTap: onSelect,
              mode: AppMode.simple,
            ),
            const SizedBox(height: AppSpacing.md),
            _ModeCard(
              title: 'Modo Ultra',
              description: 'Visão completa com gráficos, múltiplos cartões, provisionamentos e análises detalhadas.',
              icon: Icons.bolt_outlined,
              selected: selectedMode == AppMode.ultra,
              onTap: onSelect,
              mode: AppMode.ultra,
            ),
            const SizedBox(height: AppSpacing.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: selectedMode != null ? onFinish : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                child: const Text('Entrar no FinMe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────── CARD DE MODO ────────────────────────

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final ValueChanged<AppMode> onTap;
  final AppMode mode;

  const _ModeCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        onTap(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              size: 22,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(Icons.check_circle, size: 18, color: cs.primary),
              ),
          ],
        ),
      ),
    );
  }
}
