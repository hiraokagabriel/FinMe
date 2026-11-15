import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../rules/presentation/rules_section.dart';
import '../domain/import_profile.dart';
import 'dictionary_section.dart';
import 'import_flow.dart';
import 'import_mapping_dialog.dart';

/// Página Importar (sidebar índice 5). Regras e dicionário só no Ultra.
class ImportPage extends StatelessWidget {
  const ImportPage({super.key, this.pickFile});

  /// Só para teste; repassado a [startImport].
  final Future<PickedImportFile?> Function()? pickFile;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      // Ledger entra no merge: nomes de conta e cartão do destino vêm dele.
      listenable: Listenable.merge([s.importProfiles, s.settings, s.ledger]),
      builder: (context, _) {
        final ultra = s.settings.value.mode == AppMode.ultra;
        final profiles = [...s.importProfiles.all]
          ..sort((a, b) => a.name.compareTo(b.name));
        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.xl),
          children: [
            PageHeader(
              title: 'Importar',
              actions: [
                FilledButton.icon(
                  onPressed: () => startImport(context, pickFile: pickFile),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar arquivo'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfilesCard(
                    profiles: profiles,
                    ultra: ultra,
                    pickFile: pickFile,
                  ),
                  if (ultra) ...[
                    const SizedBox(height: AppSpace.lg),
                    const RulesSection(),
                    const SizedBox(height: AppSpace.lg),
                    const DictionarySection(),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfilesCard extends StatelessWidget {
  const _ProfilesCard({
    required this.profiles,
    required this.ultra,
    required this.pickFile,
  });

  final List<ImportProfile> profiles;
  final bool ultra;
  final Future<PickedImportFile?> Function()? pickFile;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Perfis salvos',
      child: profiles.isEmpty
          ? EmptyState(
              icon: Icons.upload_file,
              message:
                  'Nenhum perfil salvo. Importe um CSV ou OFX e salve o mapeamento para reaplicar com 1 clique.',
              action: FilledButton.icon(
                onPressed: () => startImport(context, pickFile: pickFile),
                icon: const Icon(Icons.upload_file),
                label: const Text('Importar arquivo'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in profiles)
                  _ProfileRow(profile: p, ultra: ultra, pickFile: pickFile),
              ],
            ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.ultra,
    required this.pickFile,
  });

  final ImportProfile profile;
  final bool ultra;
  final Future<PickedImportFile?> Function()? pickFile;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.colors;
    final body = Theme.of(context).textTheme.bodyMedium;
    final account = profile.accountId == null
        ? null
        : s.ledger.accountsById[profile.accountId!];
    final card = profile.cardId == null
        ? null
        : s.ledger.cardsById[profile.cardId!];
    final bankName = account?.bankName ?? card?.bankName ?? '';
    final destination = account != null
        ? 'Conta · ${account.name}'
        : card != null
        ? 'Cartão · ${card.name}'
        : null;
    final formatLabel = profile.format == ImportFormat.csv ? 'CSV' : 'OFX';

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            if (ultra) ...[
              BankAvatar(bankName: bankName),
              const SizedBox(width: AppSpace.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: body?.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    destination ?? 'Destino removido',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: destination == null ? c.warning : c.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            StatusBadge(label: formatLabel, color: c.textSecondary),
            const SizedBox(width: AppSpace.sm),
            OutlinedButton(
              // Destino removido: importar gravaria lançamentos em conta/cartão inexistente.
              onPressed: destination == null
                  ? null
                  : () => startImport(
                      context,
                      profile: profile,
                      pickFile: pickFile,
                    ),
              child: const Text('Importar'),
            ),
            IconButton(
              tooltip: 'Editar perfil',
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _edit(context, s),
            ),
            IconButton(
              tooltip: 'Excluir perfil',
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _delete(context, s),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, AppServices s) async {
    final ImportSetup? result;
    if (profile.format == ImportFormat.csv) {
      result = await showImportMappingDialog(
        context,
        text: '',
        initial: profile,
      );
    } else {
      result = await showImportTargetDialog(
        context,
        suggestCard: profile.cardId != null,
        initial: profile,
      );
    }
    if (result == null || !context.mounted) {
      return;
    }
    await s.importProfiles.upsert(result.profile);
  }

  Future<void> _delete(BuildContext context, AppServices s) async {
    final ok = await confirmDialog(
      context,
      title: 'Excluir perfil?',
      message:
          'O perfil "${profile.name}" será removido. Lançamentos já importados não mudam.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok && context.mounted) {
      await s.importProfiles.delete(profile.id);
    }
  }
}
