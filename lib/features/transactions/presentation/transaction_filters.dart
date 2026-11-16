import 'package:flutter/material.dart';

import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../accounts/domain/account.dart';
import '../../cards/domain/payment_card.dart';
import '../../categories/domain/transaction_category.dart';
import '../domain/transaction.dart';

/// Filtros de tipo do modo Ultra. Seleção vazia = sem filtro de tipo; várias = OR.
enum TxKindFilter {
  expense,
  income,
  transfer,
  invoicePayment,
  boleto;

  String get label => switch (this) {
    TxKindFilter.expense => 'Despesa',
    TxKindFilter.income => 'Receita',
    TxKindFilter.transfer => 'Transferência',
    TxKindFilter.invoicePayment => 'Pagamento de fatura',
    TxKindFilter.boleto => 'Boleto',
  };
}

/// Provisionado de conta. Mesmo critério de `Ledger.upcoming`; cartão nunca é provisionado.
bool isProvisioned(Transaction t) => t.isPlanned && t.accountId != null;

String accountOptionLabel(Account a) => a.bankName.isEmpty
    ? 'Conta · ${a.name}'
    : 'Conta · ${a.name} · ${a.bankName}';

String cardOptionLabel(PaymentCard c) => 'Cartão · ${c.name} ••••${c.last4}';

/// Estado dos filtros. `origin` é `acc:<id>` ou `card:<id>`; null = todas.
class TransactionFilter {
  const TransactionFilter({
    this.origin,
    this.categoryId,
    this.kinds = const {},
    this.query = '',
    this.showPlanned = true,
  });

  final String? origin;
  final String? categoryId;
  final Set<TxKindFilter> kinds;
  final String query;
  final bool showPlanned;

  /// Funções anuláveis permitem zerar `origin` e `categoryId`.
  TransactionFilter copyWith({
    String? Function()? origin,
    String? Function()? categoryId,
    Set<TxKindFilter>? kinds,
    String? query,
    bool? showPlanned,
  }) => TransactionFilter(
    origin: origin == null ? this.origin : origin(),
    categoryId: categoryId == null ? this.categoryId : categoryId(),
    kinds: kinds ?? this.kinds,
    query: query ?? this.query,
    showPlanned: showPlanned ?? this.showPlanned,
  );

  /// Algum critério ativo além do mês (usado para decidir "Limpar filtros").
  bool get hasCriteria =>
      origin != null ||
      categoryId != null ||
      kinds.isNotEmpty ||
      query.trim().isNotEmpty ||
      !showPlanned;

  bool matches(Transaction t) {
    if (!showPlanned && isProvisioned(t)) {
      return false;
    }
    if (categoryId != null && t.categoryId != categoryId) {
      return false;
    }
    final o = origin;
    if (o != null && !_matchesOrigin(o, t)) {
      return false;
    }
    if (kinds.isNotEmpty && !kinds.any((k) => _matchesKind(k, t))) {
      return false;
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    return t.description.toLowerCase().contains(q) ||
        (t.notes ?? '').toLowerCase().contains(q);
  }

  static bool _matchesOrigin(String origin, Transaction t) {
    if (origin.startsWith('acc:')) {
      return t.accountId == origin.substring(4);
    }
    return t.cardId == origin.substring(5);
  }

  static bool _matchesKind(TxKindFilter k, Transaction t) => switch (k) {
    TxKindFilter.expense => t.type == TransactionType.expense,
    TxKindFilter.income => t.type == TransactionType.income,
    TxKindFilter.transfer => t.type == TransactionType.transfer,
    TxKindFilter.invoicePayment => t.type == TransactionType.invoicePayment,
    TxKindFilter.boleto => t.isBoleto,
  };
}

/// Transações do mês que passam pelo filtro, da mais recente para a mais antiga.
List<Transaction> visibleTransactions(
  Iterable<Transaction> all,
  YearMonth month,
  TransactionFilter filter,
) {
  final list = [
    for (final t in all)
      if (month.contains(t.date) && filter.matches(t)) t,
  ];
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

enum TxSortColumn { date, description, origin, category, value }

typedef TxSort = ({TxSortColumn column, bool ascending});

const TxSort kDefaultTxSort = (column: TxSortColumn.date, ascending: false);

/// Mesma coluna inverte a ordem; coluna nova começa em A→Z para texto e em data/valor decrescente.
TxSort toggleTxSort(TxSort current, TxSortColumn column) {
  if (current.column == column) {
    return (column: column, ascending: !current.ascending);
  }
  final textual = switch (column) {
    TxSortColumn.description ||
    TxSortColumn.origin ||
    TxSortColumn.category => true,
    _ => false,
  };
  return (column: column, ascending: textual);
}

/// Nova lista ordenada pela coluna; empate desfeito por data desc e depois id asc.
List<Transaction> sortTransactions(
  List<Transaction> rows,
  TxSort sort, {
  required String Function(Transaction t) originName,
  required String Function(Transaction t) categoryName,
}) {
  // shortcut: compara lowercase sem colação de acento ("Água" fica depois de "Z"); trocar se incomodar.
  final keys = switch (sort.column) {
    TxSortColumn.description => {
      for (final t in rows) t.id: t.description.toLowerCase(),
    },
    TxSortColumn.origin => {
      for (final t in rows) t.id: originName(t).toLowerCase(),
    },
    TxSortColumn.category => {
      for (final t in rows) t.id: categoryName(t).toLowerCase(),
    },
    TxSortColumn.date || TxSortColumn.value => const <String, String>{},
  };
  int primary(Transaction a, Transaction b) => switch (sort.column) {
    TxSortColumn.date => a.date.compareTo(b.date),
    TxSortColumn.value => a.amountCents.compareTo(b.amountCents),
    _ => keys[a.id]!.compareTo(keys[b.id]!),
  };
  return [...rows]..sort((a, b) {
    final c = primary(a, b);
    if (c != 0) {
      return sort.ascending ? c : -c;
    }
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });
}

typedef TxTotals = ({int expenses, int provisioned, int income});

/// Despesas efetivas, provisionadas (saídas) e receitas efetivas de [rows].
TxTotals txTotals(Iterable<Transaction> rows) {
  var expenses = 0;
  var provisioned = 0;
  var income = 0;
  for (final t in rows) {
    if (t.type == TransactionType.expense) {
      if (isProvisioned(t)) {
        provisioned += t.amountCents;
      } else {
        expenses += t.amountCents;
      }
    } else if (t.type == TransactionType.income && !isProvisioned(t)) {
      income += t.amountCents;
    }
  }
  return (expenses: expenses, provisioned: provisioned, income: income);
}

/// Barra de filtros do modo Ultra: origem, categoria, tipo, busca e provisionados.
class TransactionFilterBar extends StatefulWidget {
  const TransactionFilterBar({
    super.key,
    required this.filter,
    required this.accounts,
    required this.cards,
    required this.categories,
    required this.onChanged,
    this.searchFocusNode,
  });

  final TransactionFilter filter;
  final List<Account> accounts;
  final List<PaymentCard> cards;
  final List<TransactionCategory> categories;
  final ValueChanged<TransactionFilter> onChanged;

  /// Foco do campo de busca; nulo → o próprio campo cria o seu.
  final FocusNode? searchFocusNode;

  @override
  State<TransactionFilterBar> createState() => _TransactionFilterBarState();
}

class _TransactionFilterBarState extends State<TransactionFilterBar> {
  late final TextEditingController _search = TextEditingController(
    text: widget.filter.query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filter;
    final cats = [...widget.categories]
      ..sort((a, b) => a.name.compareTo(b.name));
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: f.origin,
            decoration: const InputDecoration(
              labelText: 'Origem',
              isDense: true,
            ),
            items: _originItems(context),
            onChanged: (v) => widget.onChanged(f.copyWith(origin: () => v)),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: f.categoryId,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas as categorias'),
              ),
              for (final c in cats)
                DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => widget.onChanged(f.copyWith(categoryId: () => v)),
          ),
        ),
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: [
            for (final k in TxKindFilter.values)
              FilterChip(
                label: Text(k.label),
                selected: f.kinds.contains(k),
                onSelected: (on) {
                  final next = <TxKindFilter>{...f.kinds};
                  if (on) {
                    next.add(k);
                  } else {
                    next.remove(k);
                  }
                  widget.onChanged(f.copyWith(kinds: next));
                },
              ),
          ],
        ),
        SizedBox(
          width: 240,
          child: TextField(
            controller: _search,
            focusNode: widget.searchFocusNode,
            decoration: const InputDecoration(
              hintText: 'Buscar descrição ou notas',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => widget.onChanged(f.copyWith(query: v)),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: f.showPlanned,
              onChanged: (v) => widget.onChanged(f.copyWith(showPlanned: v)),
            ),
            const Text('Mostrar provisionados'),
          ],
        ),
      ],
    );
  }

  List<DropdownMenuItem<String?>> _originItems(BuildContext context) => [
    const DropdownMenuItem<String?>(
      value: null,
      child: Text('Todas as origens'),
    ),
    _groupHeader(context, 'Contas', 'grupo_contas'),
    for (final a in widget.accounts)
      DropdownMenuItem<String?>(
        value: 'acc:${a.id}',
        child: Text(accountOptionLabel(a)),
      ),
    _groupHeader(context, 'Cartões', 'grupo_cartoes'),
    for (final c in widget.cards)
      DropdownMenuItem<String?>(
        value: 'card:${c.id}',
        child: Text(cardOptionLabel(c)),
      ),
  ];

  /// Cabeçalho de grupo: item desabilitado, não selecionável.
  DropdownMenuItem<String?> _groupHeader(
    BuildContext context,
    String label,
    String value,
  ) => DropdownMenuItem<String?>(
    value: value,
    enabled: false,
    child: Text(
      label.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
    ),
  );
}
