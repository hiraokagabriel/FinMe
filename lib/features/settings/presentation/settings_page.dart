import 'package:flutter/material.dart';

import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppModeController.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracoes'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Modo de uso',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              RadioListTile<AppMode>(
                value: AppMode.simple,
                groupValue: controller.mode,
                onChanged: (v) {
                  if (v != null) controller.setMode(v);
                },
                title: const Text('Modo simples'),
                subtitle: const Text(
                  'Interface enxuta, foco em resumo rapido e menos detalhes.',
                ),
              ),
              RadioListTile<AppMode>(
                value: AppMode.ultra,
                groupValue: controller.mode,
                onChanged: (v) {
                  if (v != null) controller.setMode(v);
                },
                title: const Text('Modo ultra'),
                subtitle: const Text(
                  'Mais telas e informacoes avancadas, incluindo grafico de limite, detalhes de cartoes e categorias.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
