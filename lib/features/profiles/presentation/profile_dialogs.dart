import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../domain/pin_hash.dart';

/// Pede um PIN. [check] valida a entrada (null = aceita); a mensagem volta como erro do campo.
Future<String?> askPin(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Confirmar',
  String? Function(String pin)? check,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _PinDialog(title: title, confirmLabel: confirmLabel, check: check),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({
    required this.title,
    required this.confirmLabel,
    required this.check,
  });

  final String title;
  final String confirmLabel;
  final String? Function(String pin)? check;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _ctrl.text;
    final error = !isValidPin(pin)
        ? 'Use de 4 a 8 dígitos.'
        : widget.check?.call(pin);
    if (error != null) {
      setState(() => _error = error);
      _ctrl.clear();
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 280,
        child: TextField(
          key: const ValueKey('pin-field'),
          controller: _ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: 'PIN', errorText: _error),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Pede um nome de perfil não vazio.
Future<String?> askProfileName(
  BuildContext context, {
  required String title,
  String initial = '',
  String confirmLabel = 'Salvar',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _NameDialog(title: title, initial: initial, confirmLabel: confirmLabel),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String confirmLabel;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe um nome.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: TextField(
          key: const ValueKey('profile-name-field'),
          controller: _ctrl,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'Nome do perfil',
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.lg,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
