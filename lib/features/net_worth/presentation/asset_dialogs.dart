import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/asset.dart';

/// Ativo excluído com o diálogo aberto: o `upsert` o recriaria, então não grava e avisa.
Asset? _liveAsset(BuildContext context, AppServices services, String id) {
  final asset = services.assets.byId(id);
  if (asset == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Este ativo foi excluído.')));
  }
  return asset;
}

TextStyle? _supportStyle(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);

/// Form de ativo. Criação grava o valor inicial; edição muda só nome e tipo.
/// Devolve o ativo salvo, ou null ao cancelar.
Future<Asset?> showAssetForm(BuildContext context, {Asset? initial}) {
  final services = AppScope.of(context);
  return showDialog<Asset>(
    context: context,
    builder: (_) => _AssetFormDialog(services: services, initial: initial),
  );
}

class _AssetFormDialog extends StatefulWidget {
  const _AssetFormDialog({required this.services, this.initial});

  final AppServices services;
  final Asset? initial;

  @override
  State<_AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<_AssetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  final _value = TextEditingController();
  late AssetKind _kind = widget.initial?.kind ?? AssetKind.investment;
  late DateTime _date = widget.services.ledger.today;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  String? _valueError(int? cents) => cents == null
      ? 'Informe o valor'
      : assetSnapshotError(
          valueCents: cents,
          date: _date,
          today: widget.services.ledger.today,
        );

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final initial = widget.initial;
    final name = _name.text.trim();
    final Asset asset;
    if (initial == null) {
      final cents = parseMoney(_value.text);
      if (cents == null) {
        return;
      }
      asset = Asset(
        id: newId(),
        name: name,
        kind: _kind,
        snapshots: [AssetSnapshot(id: newId(), date: _date, valueCents: cents)],
      );
    } else {
      final current = _liveAsset(context, widget.services, initial.id);
      if (current == null) {
        return;
      }
      asset = current.copyWith(name: name, kind: _kind);
    }
    setState(() => _saving = true);
    try {
      await widget.services.assets.upsert(asset);
      if (mounted) {
        Navigator.of(context).pop(asset);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.initial == null;
    return AlertDialog(
      scrollable: true,
      title: Text(creating ? 'Novo ativo' : 'Editar ativo'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<AssetKind>(
                key: const Key('asset-kind'),
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final k in AssetKind.values)
                    DropdownMenuItem(value: k, child: Text(assetKindLabel(k))),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
              if (creating) ...[
                const SizedBox(height: AppSpace.md),
                MoneyField(
                  controller: _value,
                  label: 'Valor atual',
                  validator: _valueError,
                ),
                const SizedBox(height: AppSpace.md),
                DateField(
                  value: _date,
                  label: 'Data do valor',
                  onChanged: (d) => setState(() => _date = d),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Novo valor numa data. Mesma data substitui o snapshot anterior. Não cria transação.
Future<void> showAssetValueDialog(BuildContext context, Asset asset) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _AssetValueDialog(services: services, asset: asset),
  );
}

class _AssetValueDialog extends StatefulWidget {
  const _AssetValueDialog({required this.services, required this.asset});

  final AppServices services;
  final Asset asset;

  @override
  State<_AssetValueDialog> createState() => _AssetValueDialogState();
}

class _AssetValueDialogState extends State<_AssetValueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date = widget.services.ledger.today;
  bool _saving = false;

  /// Versão atual do ativo (pode ter mudado com a dialog aberta).
  Asset get _current =>
      widget.services.assets.byId(widget.asset.id) ?? widget.asset;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _valueError(int? cents) => cents == null
      ? 'Informe o valor'
      : assetSnapshotError(
          valueCents: cents,
          date: _date,
          today: widget.services.ledger.today,
        );

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final cents = parseMoney(_value.text);
    if (cents == null) {
      return;
    }
    final current = _liveAsset(context, widget.services, widget.asset.id);
    if (current == null) {
      return;
    }
    final note = _note.text.trim();
    // Valor > 0 reabre ativo encerrado (encerrar grava valor 0 e archived).
    final reopen = cents > 0 && current.archived;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final updated = current.withSnapshot(
        AssetSnapshot(
          id: newId(),
          date: _date,
          valueCents: cents,
          note: note.isEmpty ? null : note,
        ),
      );
      await widget.services.assets.upsert(
        reopen ? updated.copyWith(archived: false) : updated,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (reopen) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Ativo reativado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final latest = current.latest;
    final replaces = current.snapshots.any(
      (s) => dateKey(s.date) == dateKey(_date),
    );
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text('Atualizar valor · ${current.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Theme(
          // Erro do domínio (ex.: data no futuro) em danger, como no campo de alvo das metas.
          data: theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              errorStyle: TextStyle(color: context.colors.danger),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  latest == null
                      ? 'Sem valor cadastrado'
                      : 'Valor atual: ${formatMoney(latest.valueCents, hidden: widget.services.settings.value.hideValues)} '
                            'em ${formatDate(latest.date)}',
                  style: _supportStyle(context),
                ),
                const SizedBox(height: AppSpace.md),
                MoneyField(
                  controller: _value,
                  label: 'Novo valor',
                  validator: _valueError,
                ),
                const SizedBox(height: AppSpace.md),
                DateField(
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
                if (replaces)
                  Text(
                    'Substitui o valor de ${formatDate(_date)}',
                    style: _supportStyle(context),
                  ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Snapshots do mais recente para o mais antigo, com a variação. Excluir o único valor é bloqueado.
Future<void> showAssetHistory(BuildContext context, Asset asset) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _AssetHistoryDialog(services: services, asset: asset),
  );
}

class _AssetHistoryDialog extends StatelessWidget {
  const _AssetHistoryDialog({required this.services, required this.asset});

  final AppServices services;
  final Asset asset;

  Future<void> _delete(BuildContext context, String snapshotId) async {
    final current = _liveAsset(context, services, asset.id);
    if (current == null) {
      return;
    }
    final error = removeSnapshotError(current, snapshotId);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await services.assets.upsert(current.withoutSnapshot(snapshotId));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.assets,
      builder: (context, _) {
        final current = services.assets.byId(asset.id) ?? asset;
        final rows = current.snapshots.reversed.toList();
        return AlertDialog(
          scrollable: true,
          title: Text('Histórico · ${current.name}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, s) in rows.indexed)
                  _SnapshotRow(
                    snapshot: s,
                    // O último da lista (o mais antigo) não tem variação.
                    change: i + 1 < rows.length
                        ? s.valueCents - rows[i + 1].valueCents
                        : null,
                    onDelete: () => _delete(context, s.id),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    required this.snapshot,
    required this.change,
    required this.onDelete,
  });

  final AssetSnapshot snapshot;
  final int? change;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(formatDate(s.date), style: _supportStyle(context)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoneyText(s.valueCents),
                if (s.note != null)
                  Text(s.note!, style: _supportStyle(context)),
              ],
            ),
          ),
          if (change != null)
            MoneyText(change!, signed: true, colorBySign: true),
          IconButton(
            tooltip: 'Excluir valor',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
