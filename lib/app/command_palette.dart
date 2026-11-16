import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/fuzzy.dart';

/// Item da paleta Ctrl+K. Contrato: docs/SPEC.md §7.3, "Produtividade (Fase 9)".
class PaletteEntry {
  const PaletteEntry({
    required this.label,
    required this.icon,
    required this.onRun,
    this.subtitle,
    this.shortcut,
    this.keywords = const [],
    this.trailing,
    this.group = 'Comandos',
  });

  final String label;
  final IconData icon;
  final VoidCallback onRun;
  final String? subtitle;
  final String? shortcut;
  final List<String> keywords;
  final Widget? trailing;
  final String group;
}

const _maxCommandResults = 8;
const _rowExtent = 44.0;
const _maxListHeight = 360.0;

/// Abre a paleta e roda o item escolhido só depois que ela saiu da tela.
/// Sem query, mostra todos os [commands]; com query, até 8 comandos rankeados por
/// [fuzzyRank] seguidos dos resultados de [search] (que já vêm ordenados).
Future<void> showCommandPalette(
  BuildContext context, {
  required List<PaletteEntry> commands,
  List<PaletteEntry> Function(String query)? search,
}) async {
  final navigator = Navigator.of(context);
  final route = DialogRoute<PaletteEntry>(
    context: context,
    barrierDismissible: true,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (_) => _CommandPalette(commands: commands, search: search),
  );
  final picked = await navigator.push(route);
  // `completed` só completa após a animação de saída: o Dialog já saiu da árvore.
  await route.completed;
  picked?.onRun();
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.commands, this.search});

  final List<PaletteEntry> commands;
  final List<PaletteEntry> Function(String query)? search;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  // Linhas visíveis: cabeçalho de grupo ou item (índice em _results). _rowOf[i] = linha do item i.
  final _rows = <_Row>[];
  final _rowOf = <int>[];
  List<PaletteEntry> _results = const [];
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    _setResults('');
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setResults(String text) {
    final q = text.trim();
    _results = q.isEmpty
        ? widget.commands
        : [
            ...fuzzyRank(
              widget.commands,
              q,
              (e) => [e.label, ...e.keywords],
              limit: _maxCommandResults,
            ),
            ...?widget.search?.call(q),
          ];
    _highlight = 0;
    _rows.clear();
    _rowOf.clear();
    String? group;
    for (var i = 0; i < _results.length; i++) {
      final g = _results[i].group;
      if (g != group) {
        group = g;
        _rows.add(_Row.header(g));
      }
      _rowOf.add(_rows.length);
      _rows.add(_Row.item(i));
    }
  }

  void _onChanged(String text) {
    setState(() => _setResults(text));
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _move(int delta) {
    if (_results.isEmpty) {
      return;
    }
    final next = (_highlight + delta).clamp(0, _results.length - 1).toInt();
    setState(() => _highlight = next);
    _reveal(next);
  }

  // Rola só o necessário para a linha do item ficar visível.
  void _reveal(int i) {
    if (!_scroll.hasClients) {
      return;
    }
    final pos = _scroll.position;
    final top = _rowOf[i] * _rowExtent;
    final bottom = top + _rowExtent;
    final target = top < pos.pixels
        ? top
        : bottom > pos.pixels + pos.viewportDimension
        ? bottom - pos.viewportDimension
        : null;
    if (target != null) {
      _scroll.animateTo(
        target,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
      );
    }
  }

  void _runHighlighted() {
    if (_results.isNotEmpty) {
      Navigator.of(context).pop(_results[_highlight]);
    }
  }

  void _run(int i) => Navigator.of(context).pop(_results[i]);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter): _runHighlighted,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _runHighlighted,
      },
      child: Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(40, 80, 40, 24),
        backgroundColor: c.surface,
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_input(c), _body(c), _footer(c)],
          ),
        ),
      ),
    );
  }

  Widget _input(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: TextField(
        key: const ValueKey('palette-input'),
        controller: _query,
        autofocus: true,
        onChanged: _onChanged,
        style: TextStyle(fontSize: 13, color: c.textPrimary),
        decoration: InputDecoration(
          hintText: 'Buscar comandos e transações',
          hintStyle: TextStyle(fontSize: 13, color: c.textSecondary),
          prefixIcon: Icon(Icons.search, size: 18, color: c.textSecondary),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        ),
      ),
    );
  }

  Widget _body(AppColors c) {
    final height = (_rows.length * _rowExtent)
        .clamp(_rowExtent, _maxListHeight)
        .toDouble();
    return SizedBox(
      height: height,
      child: _results.isEmpty
          ? Center(
              child: Text(
                'Nada encontrado',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            )
          : ListView.builder(
              controller: _scroll,
              itemExtent: _rowExtent,
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final row = _rows[i];
                if (row.index case final index?) {
                  return _item(c, index);
                }
                return _header(c, row.group ?? '');
              },
            ),
    );
  }

  Widget _header(AppColors c, String group) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpace.md, bottom: AppSpace.xs),
        child: Text(
          group,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _item(AppColors c, int i) {
    final entry = _results[i];
    final active = i == _highlight;
    return InkWell(
      key: ValueKey('palette-item-$i'),
      onTap: () => _run(i),
      child: Container(
        color: active ? c.primarySubtle : null,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        child: Row(
          children: [
            Icon(entry.icon, size: 18, color: c.textSecondary),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.textPrimary),
                  ),
                  if (entry.subtitle case final subtitle?)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                ],
              ),
            ),
            ?entry.trailing,
            if (entry.shortcut case final shortcut?) ...[
              const SizedBox(width: AppSpace.sm),
              _ShortcutChip(shortcut),
            ],
          ],
        ),
      ),
    );
  }

  Widget _footer(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      child: Text(
        '↑↓ navegar · Enter executar · Esc fechar',
        style: TextStyle(fontSize: 12, color: c.textSecondary),
      ),
    );
  }
}

class _Row {
  const _Row.header(this.group) : index = null;
  const _Row.item(this.index) : group = null;

  final String? group;
  final int? index;
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: AppRadius.chipBorder,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: c.textSecondary,
        ),
      ),
    );
  }
}
