import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/hive_init.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0 = splash, 1 = modo
  AppMode? _selectedMode;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _goToModeStep() {
    _fadeCtrl.reverse().then((_) {
      setState(() => _step = 1);
      _fadeCtrl.forward();
    });
  }

  Future<void> _finish() async {
    if (_selectedMode == null) return;
    await AppModeController.instance.setMode(_selectedMode!);
    await HiveInit.markOnboardingDone();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _step == 0 ? _buildSplash(theme, cs) : _buildModeStep(theme, cs),
      ),
    );
  }

  // ───────────────────────────── SPLASH ─────────────────────────────

  Widget _buildSplash(ThemeData theme, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
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
            const SizedBox(height: 24),
            Text(
              'FinMe',
              style: AppText.title.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Controle financeiro para quem lida\ncom muitos cartões e contas.',
              textAlign: TextAlign.center,
              style: AppText.secondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _goToModeStep,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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

  // ───────────────────────────── MODO ─────────────────────────────

  Widget _buildModeStep(ThemeData theme, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como você quer usar o FinMe?',
              style: AppText.title.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Você pode mudar isso depois nas configurações.',
              style: AppText.secondary,
            ),
            const SizedBox(height: 24),
            _ModeCard(
              title: 'Modo Simples',
              description:
                  'Visão enxuta. Ideal para quem quer controlar gastos do dia a dia sem complicação.',
              icon: Icons.wb_sunny_outlined,
              selected: _selectedMode == AppMode.simple,
              onTap: () => setState(() => _selectedMode = AppMode.simple),
            ),
            const SizedBox(height: 12),
            _ModeCard(
              title: 'Modo Ultra',
              description:
                  'Visão completa com gráficos, múltiplos cartões, provisionamentos e análises detalhadas.',
              icon: Icons.bolt_outlined,
              selected: _selectedMode == AppMode.ultra,
              onTap: () => setState(() => _selectedMode = AppMode.ultra),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedMode != null ? _finish : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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

// ─────────────────────────── CARD DE MODO ────────────────────────────

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, size: 18, color: cs.primary),
              ),
          ],
        ),
      ),
    );
  }
}
