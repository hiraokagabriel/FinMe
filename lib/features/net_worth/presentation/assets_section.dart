import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/asset.dart';
import 'asset_dialogs.dart';

enum _AssetAction { update, history, edit, close, reopen, delete }

/// Seção "Ativos" da página Patrimônio. Simples: nome, tipo, valor e atualizar.
/// Ultra: data do valor, variação, menu completo, encerrados e total.
class AssetsSection extends StatefulWidget {
  const AssetsSection({super.key});

  @override
  State<AssetsSection> createState() => _AssetsSectionState();
}

class _AssetsSectionState extends State<AssetsSection> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.assets, s.settings]),
      builder: (context, _) {
        final settings = s.settings.value;
        final ultra = settings.mode == AppMode.ultra;
        final all = s.assets.all;
        final hasArchived = all.any((a) => a.archived);
        final assets =
            [
              for (final a in all)
                if ((ultra && _showArchived) || !a.archived) a,
            ]..sort((a, b) {
              final byValue = b.currentValueCents.compareTo(
                a.currentValueCents,
              );
              return byValue != 0 ? byValue : a.name.compareTo(b.name);
            });

        final Widget body;
        if (assets.isEmpty) {
          body = EmptyState(
            icon: Icons.home_work_outlined,
            message: all.isEmpty
                ? 'Nenhum ativo. Cadastre imóveis, veículos e investimentos '
                      'fora das contas para ver o patrimônio completo.'
                : 'Todos os ativos estão encerrados.',
            action: _newAssetButton(context),
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final a in assets)
                _AssetRow(
                  asset: a,
                  ultra: ultra,
                  onUpdate: () => showAssetValueDialog(context, a),
                  onAction: (action) => _onAction(context, s, a, action),
                ),
              if (ultra) _TotalRow(totalCents: _activeTotal(all)),
            ],
          );
        }

        return SectionCard(
          title: 'Ativos',
          trailing: _newAssetButton(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ultra && hasArchived) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    key: const Key('assets-show-archived'),
                    label: const Text('Mostrar encerrados'),
                    selected: _showArchived,
                    onSelected: (v) => setState(() => _showArchived = v),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              body,
            ],
          ),
        );
      },
    );
  }

  Widget _newAssetButton(BuildContext context) => TextButton.icon(
    onPressed: () => showAssetForm(context),
    icon: const Icon(Icons.add),
    label: const Text('Novo ativo'),
  );

  Future<void> _onAction(
    BuildContext context,
    AppServices s,
    Asset a,
    _AssetAction action,
  ) async {
    switch (action) {
      case _AssetAction.update:
        await showAssetValueDialog(context, a);
      case _AssetAction.history:
        await showAssetHistory(context, a);
      case _AssetAction.edit:
        await showAssetForm(context, initial: a);
      case _AssetAction.close:
        final ok = await confirmDialog(
          context,
          title: 'Encerrar ativo?',
          message:
              'O valor passa a R\$ 0,00 a partir de hoje. '
              'O histórico é mantido.',
          confirmLabel: 'Encerrar',
          destructive: true,
        );
        final current = s.assets.byId(a.id);
        if (ok && current != null) {
          await s.assets.upsert(
            closeAsset(current, date: s.ledger.today, snapshotId: newId()),
          );
        }
      case _AssetAction.reopen:
        final current = s.assets.byId(a.id);
        if (current != null) {
          await s.assets.upsert(current.copyWith(archived: false));
        }
      case _AssetAction.delete:
        final ok = await confirmDialog(
          context,
          title: 'Excluir ativo?',
          message:
              'O histórico de valores será apagado e o patrimônio dos '
              'meses passados muda.',
          confirmLabel: 'Excluir',
          destructive: true,
        );
        if (ok) {
          await s.assets.delete(a.id);
        }
    }
  }
}

/// Soma dos ativos não encerrados (encerrados não entram no total).
int _activeTotal(Iterable<Asset> assets) => assets
    .where((a) => !a.archived)
    .fold(0, (sum, a) => sum + a.currentValueCents);

IconData _kindIcon(AssetKind kind) => switch (kind) {
  AssetKind.investment => Icons.trending_up,
  AssetKind.realEstate => Icons.home_outlined,
  AssetKind.vehicle => Icons.directions_car_outlined,
  AssetKind.other => Icons.category_outlined,
};

/// Um ativo. Encerrado: nome e valor em `textSecondary` com badge 'Encerrado'.
class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.asset,
    required this.ultra,
    required this.onUpdate,
    required this.onAction,
  });

  final Asset asset;
  final bool ultra;
  final VoidCallback onUpdate;
  final ValueChanged<_AssetAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final a = asset;
    final latest = a.latest;
    final change = a.lastChangeCents;
    final nameStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: a.archived ? c.textSecondary : c.textPrimary,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Padding(
        key: Key('asset-${a.id}'),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            Icon(_kindIcon(a.kind), size: 18, color: c.textSecondary),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.name,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                      ),
                      if (a.archived) ...[
                        const SizedBox(width: AppSpace.sm),
                        StatusBadge(label: 'Encerrado', color: c.textSecondary),
                      ],
                    ],
                  ),
                  Text(assetKindLabel(a.kind), style: textTheme.bodySmall),
                  if (ultra && latest != null)
                    Text(
                      'Atualizado em ${formatDate(latest.date)}',
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: MoneyText(
                    a.currentValueCents,
                    key: ValueKey(a.currentValueCents),
                    style: nameStyle,
                  ),
                ),
                if (ultra && change != null)
                  MoneyText(
                    change,
                    signed: true,
                    colorBySign: true,
                    style: textTheme.bodySmall,
                  ),
              ],
            ),
            IconButton(
              key: Key('asset-update-${a.id}'),
              tooltip: 'Atualizar valor',
              icon: const Icon(Icons.update),
              onPressed: onUpdate,
            ),
            if (ultra)
              PopupMenuButton<_AssetAction>(
                key: Key('asset-menu-${a.id}'),
                tooltip: 'Ações do ativo',
                onSelected: onAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _AssetAction.update,
                    child: Text('Atualizar valor'),
                  ),
                  const PopupMenuItem(
                    value: _AssetAction.history,
                    child: Text('Histórico'),
                  ),
                  const PopupMenuItem(
                    value: _AssetAction.edit,
                    child: Text('Editar'),
                  ),
                  PopupMenuItem(
                    value: a.archived
                        ? _AssetAction.reopen
                        : _AssetAction.close,
                    child: Text(a.archived ? 'Reativar' : 'Encerrar'),
                  ),
                  const PopupMenuItem(
                    value: _AssetAction.delete,
                    child: Text('Excluir'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Rodapé Ultra: soma dos ativos não encerrados.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.totalCents});

  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Row(
        children: [
          Text('Total', style: style),
          const Spacer(),
          MoneyText(totalCents, style: style),
        ],
      ),
    );
  }
}
