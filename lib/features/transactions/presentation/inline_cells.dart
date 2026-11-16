import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../categories/domain/transaction_category.dart';
import '../domain/transaction_bulk.dart';

/// Categoria editável direto na linha (Ultra). "Sem categoria" grava `null`.
class InlineCategoryCell extends StatelessWidget {
  const InlineCategoryCell({
    super.key,
    required this.categoryId,
    required this.options,
    required this.onChanged,
  });

  final String? categoryId;
  final List<TransactionCategory> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final known = options.any((o) => o.id == categoryId);
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: known ? categoryId : null,
        isDense: true,
        isExpanded: true,
        iconSize: 16,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Sem categoria'),
          ),
          for (final o in options)
            DropdownMenuItem<String?>(value: o.id, child: Text(o.name)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Valor editável direto na linha (Ultra). Clique abre o campo; Enter grava,
/// Esc ou perda de foco cancela. Valor inválido mantém o campo com borda de erro.
class InlineAmountCell extends StatefulWidget {
  const InlineAmountCell({
    super.key,
    required this.display,
    required this.amountCents,
    required this.onSubmit,
  });

  final Widget display;
  final int amountCents;
  final ValueChanged<int> onSubmit;

  @override
  State<InlineAmountCell> createState() => _InlineAmountCellState();
}

class _InlineAmountCellState extends State<InlineAmountCell> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      _cancel();
    }
  }

  void _start() {
    final initial = formatMoney(widget.amountCents).replaceFirst('R\$ ', '');
    _text.value = TextEditingValue(
      text: initial,
      selection: TextSelection(baseOffset: 0, extentOffset: initial.length),
    );
    setState(() {
      _editing = true;
      _invalid = false;
    });
  }

  void _cancel() {
    if (!_editing) {
      return;
    }
    setState(() {
      _editing = false;
      _invalid = false;
    });
  }

  /// Idempotente: Enter pode chegar por `onSubmitted` e pelo atalho; o segundo é no-op.
  void _commit() {
    if (!_editing) {
      return;
    }
    final cents = parseInlineAmount(_text.text);
    if (cents == null) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _editing = false;
      _invalid = false;
    });
    if (cents != widget.amountCents) {
      widget.onSubmit(cents);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return _field(context);
    }
    return Tooltip(
      message: 'Clique para editar o valor',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _start,
        child: widget.display,
      ),
    );
  }

  Widget _field(BuildContext context) {
    final c = context.colors;
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final border = OutlineInputBorder(
      borderRadius: AppRadius.chipBorder,
      borderSide: BorderSide(color: _invalid ? c.danger : c.primary),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
        const SingleActivator(LogicalKeyboardKey.enter): _commit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _commit,
      },
      child: TextField(
        key: const Key('inline-amount-field'),
        controller: _text,
        focusNode: _focus,
        autofocus: true,
        textAlign: TextAlign.right,
        style: AppText.tabular(base.copyWith(color: c.textPrimary)),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xs,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
        onSubmitted: (_) => _commit(),
        // No desktop o foco não sai sozinho ao clicar fora; cancela aqui.
        onTapOutside: (_) => _cancel(),
      ),
    );
  }
}
