import 'package:flutter/material.dart';

import '../core/models/app_settings.dart';
import '../core/theme/app_palettes.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/money.dart';
import '../features/transactions/domain/transaction.dart';
import 'command_palette.dart';
import 'ledger.dart';

/// Página na paleta: rótulo e ícone (mesmos de `_navItems` do shell).
typedef PageInfo = ({String label, IconData icon});

/// Comandos globais, na ordem do SPEC §7.3: 'Ir para' por página, depois as ações.
List<PaletteEntry> buildAppCommands({
  required AppSettings settings,
  required List<PageInfo> pages,
  required ValueChanged<int> onGoTo,
  required VoidCallback onNewTransaction,
  required VoidCallback onImport,
  required VoidCallback onNewRecurring,
  required VoidCallback onToggleMode,
  required VoidCallback onToggleTheme,
  required VoidCallback onToggleHideValues,
}) {
  final ultra = settings.mode == AppMode.ultra;
  final hidden = settings.hideValues;
  return [
    for (var i = 0; i < pages.length; i++)
      PaletteEntry(
        label: 'Ir para ${pages[i].label}',
        icon: pages[i].icon,
        // Atalhos 1..9 só existem para as 9 primeiras páginas.
        shortcut: i < 9 ? '${i + 1}' : null,
        keywords: [pages[i].label],
        onRun: () => onGoTo(i),
      ),
    PaletteEntry(
      label: 'Nova transação',
      icon: Icons.add,
      shortcut: 'N',
      keywords: const ['lançar', 'despesa', 'receita', 'adicionar'],
      onRun: onNewTransaction,
    ),
    PaletteEntry(
      label: 'Importar arquivo',
      icon: Icons.upload_file,
      shortcut: 'Ctrl+I',
      keywords: const ['csv', 'ofx', 'extrato'],
      onRun: onImport,
    ),
    PaletteEntry(
      label: 'Nova recorrência',
      icon: Icons.autorenew,
      keywords: const ['assinatura', 'fixo'],
      onRun: onNewRecurring,
    ),
    PaletteEntry(
      label: ultra ? 'Mudar para Modo Simples' : 'Mudar para Modo Ultra',
      icon: Icons.tune,
      keywords: const ['modo', 'simples', 'ultra'],
      onRun: onToggleMode,
    ),
    PaletteEntry(
      label: 'Alternar tema claro/escuro',
      icon: Icons.brightness_6_outlined,
      keywords: const ['tema', 'escuro', 'claro'],
      onRun: onToggleTheme,
    ),
    PaletteEntry(
      label: hidden ? 'Mostrar valores' : 'Ocultar valores',
      icon: hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      keywords: const ['privacidade', 'esconder'],
      onRun: onToggleHideValues,
    ),
  ];
}

/// Uma entrada por transação de [found] (já filtrada e ordenada pelo chamador).
List<PaletteEntry> transactionEntries(
  List<Transaction> found, {
  required Ledger ledger,
  required ValueChanged<Transaction> onOpen,
}) => [for (final t in found) _transactionEntry(t, ledger, onOpen)];

PaletteEntry _transactionEntry(
  Transaction t,
  Ledger ledger,
  ValueChanged<Transaction> onOpen,
) {
  final category = ledger.categoriesById[t.categoryId];
  final place =
      ledger.cardsById[t.cardId]?.name ??
      ledger.accountsById[t.accountId]?.name;
  final installment = t.isInstallment
      ? ' ${t.installmentIndex}/${t.installmentCount}'
      : '';
  return PaletteEntry(
    label: '${t.description}$installment',
    subtitle: [formatDate(t.date), ?place, ?category?.name].join(' · '),
    icon: category == null
        ? Icons.label_outline
        : categoryIcon(category.iconCodePoint),
    group: 'Transações',
    trailing: _amount(t),
    onRun: () => onOpen(t),
  );
}

/// Mesmo sinal da linha de Transações: despesa e pagamento negativos, receita positiva, transferência sem sinal.
Widget _amount(Transaction t) => switch (t.type) {
  TransactionType.expense || TransactionType.invoicePayment => MoneyText(
    -t.amountCents,
    signed: true,
    colorBySign: true,
  ),
  TransactionType.income => MoneyText(
    t.amountCents,
    signed: true,
    colorBySign: true,
  ),
  TransactionType.transfer => MoneyText(t.amountCents),
};

/// Entrada de busca que abre Transações do mês filtradas por [query] (a página recebe `initialQuery`).
PaletteEntry filterTransactionsEntry(
  String query, {
  required VoidCallback onRun,
}) => PaletteEntry(
  label: 'Filtrar Transações do mês por “$query”',
  icon: Icons.filter_list,
  group: 'Transações',
  onRun: onRun,
);
