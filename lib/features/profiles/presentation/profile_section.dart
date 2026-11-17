import 'package:flutter/material.dart';

import '../../../app/profile_registry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/bank_avatar.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import 'profile_dialogs.dart';

/// Ajustes → Perfil (SPEC §10.5). Some sem `ProfileScope` (testes do app sem gate).
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ProfileScope.maybeOf(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    final registry = scope.registry;
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final current = registry.byId(scope.activeId);
        if (current == null) {
          return const SizedBox.shrink();
        }
        final others = [
          for (final p in registry.all)
            if (p.id != current.id) p,
        ];
        final colors = context.colors;
        final messenger = ScaffoldMessenger.of(context);

        Future<bool> confirmCurrentPin() async {
          final pin = await askPin(
            context,
            title: 'PIN atual',
            check: (pin) => current.verifyPin(pin) ? null : 'PIN incorreto.',
          );
          return pin != null;
        }

        Future<void> rename() async {
          final name = await askProfileName(
            context,
            title: 'Renomear perfil',
            initial: current.name,
          );
          if (name != null) {
            await registry.rename(current.id, name);
          }
        }

        Future<void> setPin() async {
          if (current.hasPin && !await confirmCurrentPin()) {
            return;
          }
          if (!context.mounted) {
            return;
          }
          final pin = await askPin(context, title: 'Novo PIN');
          if (pin == null || !context.mounted) {
            return;
          }
          final again = await askPin(
            context,
            title: 'Repita o PIN',
            check: (p) => p == pin ? null : 'Os PINs não conferem.',
          );
          if (again == null) {
            return;
          }
          await registry.setPin(current.id, pin);
          messenger.showSnackBar(const SnackBar(content: Text('PIN salvo.')));
        }

        Future<void> removePin() async {
          if (!await confirmCurrentPin()) {
            return;
          }
          await registry.setPin(current.id, null);
          messenger.showSnackBar(
            const SnackBar(content: Text('PIN removido.')),
          );
        }

        Future<void> create() async {
          final name = await askProfileName(
            context,
            title: 'Novo perfil',
            confirmLabel: 'Criar',
          );
          if (name != null) {
            await registry.create(name);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Perfil "$name" criado. Abra-o por "Trocar perfil".',
                ),
              ),
            );
          }
        }

        Future<void> delete(String id, String name) async {
          final ok = await confirmDialog(
            context,
            title: 'Excluir o perfil "$name"?',
            message:
                'Todas as contas, cartões, lançamentos e demais dados deste perfil serão apagados. Esta ação não pode ser desfeita.',
            confirmLabel: 'Excluir',
            destructive: true,
          );
          if (!ok) {
            return;
          }
          try {
            await registry.delete(id, activeId: current.id);
          } catch (_) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Não foi possível excluir o perfil.'),
              ),
            );
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: SectionCard(
            title: 'Perfil',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BankAvatar(bankName: current.name, size: 32),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(current.name),
                          Text(
                            current.hasPin ? 'Protegido por PIN' : 'Sem PIN',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: rename,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Renomear'),
                    ),
                    OutlinedButton.icon(
                      onPressed: setPin,
                      icon: const Icon(Icons.lock_outline),
                      label: Text(
                        current.hasPin ? 'Alterar PIN' : 'Definir PIN',
                      ),
                    ),
                    if (current.hasPin)
                      OutlinedButton.icon(
                        onPressed: removePin,
                        icon: const Icon(Icons.lock_open_outlined),
                        label: const Text('Remover PIN'),
                      ),
                    OutlinedButton.icon(
                      onPressed: scope.switchProfile,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Trocar perfil'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'O PIN bloqueia a abertura do perfil no app; os arquivos de dados não são criptografados.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const Divider(height: AppSpace.xl),
                Text(
                  'Outros perfis',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpace.sm),
                if (others.isEmpty)
                  Text(
                    'Nenhum outro perfil.',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                for (final p in others)
                  ListTile(
                    key: ValueKey('settings-profile-${p.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: BankAvatar(bankName: p.name, size: 24),
                    title: Text(p.name),
                    trailing: IconButton(
                      tooltip: 'Excluir perfil',
                      color: colors.danger,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => delete(p.id, p.name),
                    ),
                  ),
                const SizedBox(height: AppSpace.sm),
                TextButton.icon(
                  onPressed: create,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Novo perfil'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
