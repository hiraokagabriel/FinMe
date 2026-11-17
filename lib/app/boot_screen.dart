import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/skeleton.dart';

/// Esqueleto do layout principal, exibido enquanto o `bootstrap()` carrega.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: Builder(
          builder: (context) => Row(
            children: [
              SizedBox(
                width: 220,
                child: ColoredBox(
                  color: context.colors.sidebar,
                  child: const SkeletonList(rows: 8),
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.xl),
                  child: SkeletonList(rows: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Falha ao abrir os dados (bootstrap). Não apaga nem recria boxes: só mostra o erro.
class BootErrorScreen extends StatelessWidget {
  const BootErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    // shortcut: ThemeMode.system ignora o tema salvo (ler exigiria abrir a box antes do bootstrap); aceitar o flash.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Não foi possível abrir os dados do FinMe.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    '$error',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  const Text(
                    'Se você tiver um backup (arquivo JSON), restaure-o pelo botão '
                    'Importar backup em Configurações.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
