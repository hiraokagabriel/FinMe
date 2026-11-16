import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Intents globais (SPEC §7.3, Produtividade). Cada tecla vira um intent; quem executa decide o efeito.

class OpenPaletteIntent extends Intent {
  const OpenPaletteIntent();
}

class NewTransactionIntent extends Intent {
  const NewTransactionIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class ImportFileIntent extends Intent {
  const ImportFileIntent();
}

class GoToPageIntent extends Intent {
  const GoToPageIntent(this.index);

  /// Página da sidebar, 0..8.
  final int index;
}

class SelectAllRowsIntent extends Intent {
  const SelectAllRowsIntent();
}

class ClearSelectionIntent extends Intent {
  const ClearSelectionIntent();
}

const List<LogicalKeyboardKey> _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

const List<LogicalKeyboardKey> _numpadKeys = [
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

/// Atalhos globais. `/` usa o caractere, então vale em qualquer layout (ABNT2/US).
final Map<ShortcutActivator, Intent> kAppShortcuts = {
  const SingleActivator(LogicalKeyboardKey.keyK, control: true):
      const OpenPaletteIntent(),
  const SingleActivator(LogicalKeyboardKey.keyI, control: true):
      const ImportFileIntent(),
  const SingleActivator(LogicalKeyboardKey.keyN): const NewTransactionIntent(),
  const CharacterActivator('/'): const FocusSearchIntent(),
  for (var i = 0; i < 9; i++) ...{
    SingleActivator(_digitKeys[i]): GoToPageIntent(i),
    SingleActivator(_numpadKeys[i]): GoToPageIntent(i),
  },
};

/// Atalhos de seleção de linhas (Ctrl+A, Esc), ativos só na página Transações.
final Map<ShortcutActivator, Intent> kSelectionShortcuts = {
  const SingleActivator(LogicalKeyboardKey.keyA, control: true):
      const SelectAllRowsIntent(),
  const SingleActivator(LogicalKeyboardKey.escape):
      const ClearSelectionIntent(),
};

/// Verdadeiro quando o foco primário está num campo de texto (EditableText).
bool isTextInputFocused() {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  if (context == null) {
    return false;
  }
  return context.widget is EditableText ||
      context.findAncestorStateOfType<EditableTextState>() != null;
}

/// Ação que some quando há digitação: sem a guarda, `N` ou `/` roubariam a tecla do campo.
class TypingGuardAction<T extends Intent> extends CallbackAction<T> {
  TypingGuardAction({required super.onInvoke});

  @override
  bool isEnabled(T intent) => !isTextInputFocused();
}
