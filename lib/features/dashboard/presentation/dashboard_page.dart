import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppModeController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final mode = controller.mode;
        final isUltra = mode == AppMode.ultra;
        final modeLabel = isUltra ? 'Modo Ultra' : 'Modo Simples';
        final modeColor = isUltra ? AppColors.primary : AppColors.textSecondary;

        return Scaffold(
          appBar: AppBar(
            title: const Text('FinMe'),
            actions: [
              IconButton(
                tooltip: 'Configurações',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.settings),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Badge do modo ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isUltra
                        ? AppColors.primarySubtle
                        : AppColors.sidebar,
                    borderRadius:
                        BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    modeLabel,
                    style: AppText.badge.copyWith(color: modeColor),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // ── Placeholder de conteúdo ───────────────────────
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bar_chart_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Dashboard em construção',
                          style: AppText.sectionLabel,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Os widgets financeiros aparecerão aqui.',
                          style: AppText.secondary,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Ações rápidas ────────────────────────────────
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRouter.transactions),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Transações'),
                      ),
                    ),
                    if (isUltra) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(AppRouter.cards),
                          icon: const Icon(Icons.credit_card_outlined),
                          label: const Text('Cartões'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }
}
