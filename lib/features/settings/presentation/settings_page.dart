import 'package:flutter/material.dart';

import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../categories/presentation/categories_page.dart';

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
          final isUltra = controller.mode == AppMode.ultra;
          return ListView(
            children: [
              // ---------- Modo de uso ----------
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
                  'Interface enxuta, foco em resumo rapido. Sem detalhes de cartao ou graficos avancados.',
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
                  'Visao completa com graficos por categoria e cartao, limite de credito, campos avancados e provisionamento.',
                ),
              ),
              // Banner informativo do modo atual
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: isUltra
                    ? _ModeBanner(
                        key: const ValueKey('ultra'),
                        icon: Icons.bolt,
                        color: Colors.deepPurple,
                        title: 'Modo ultra ativo',
                        message:
                            'Voce esta vendo informacoes completas: graficos por categoria e cartao, limite de credito e campos avancados nas transacoes.',
                      )
                    : _ModeBanner(
                        key: const ValueKey('simple'),
                        icon: Icons.spa_outlined,
                        color: Colors.teal,
                        title: 'Modo simples ativo',
                        message:
                            'Interface enxuta: apenas data na lista de transacoes. Campos de cartao e graficos ficam ocultos.',
                      ),
              ),
              const Divider(height: 32),
              // ---------- Categorias ----------
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Dados',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: const Text('Categorias'),
                subtitle: const Text('Gerenciar categorias de despesa e receita'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CategoriesPage(),
                    ),
                  );
                },
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
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
