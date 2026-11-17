import 'package:flutter/material.dart';

import '../../../app/profile_registry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/bank_avatar.dart';
import '../domain/profile.dart';
import 'profile_dialogs.dart';

/// Escolha de perfil na abertura e ao trocar (SPEC §10.4). PIN pedido quando o perfil tem.
class ProfilePickerPage extends StatelessWidget {
  const ProfilePickerPage({
    super.key,
    required this.registry,
    required this.onOpen,
  });

  final ProfileRegistry registry;
  final ValueChanged<String> onOpen;

  Future<void> _open(BuildContext context, Profile p) async {
    if (p.hasPin) {
      final pin = await askPin(
        context,
        title: 'PIN de ${p.name}',
        confirmLabel: 'Abrir',
        check: (pin) => p.verifyPin(pin) ? null : 'PIN incorreto.',
      );
      if (pin == null) {
        return;
      }
    }
    onOpen(p.id);
  }

  Future<void> _create(BuildContext context) async {
    final name = await askProfileName(
      context,
      title: 'Novo perfil',
      confirmLabel: 'Criar',
    );
    if (name != null) {
      await registry.create(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListenableBuilder(
            listenable: registry,
            builder: (context, _) => ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppSpace.xl),
              children: [
                Text('Quem está usando?', style: AppText.screenTitle(context)),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Cada perfil tem contas, cartões e lançamentos próprios.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpace.lg),
                for (final p in registry.all)
                  ListTile(
                    key: ValueKey('profile-${p.id}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.cardBorder,
                    ),
                    leading: BankAvatar(bankName: p.name, size: 32),
                    title: Text(p.name),
                    trailing: p.hasPin
                        ? Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: colors.textSecondary,
                            semanticLabel: 'Protegido por PIN',
                          )
                        : null,
                    onTap: () => _open(context, p),
                  ),
                const SizedBox(height: AppSpace.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Novo perfil'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
