import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fl_chart/fl_chart.dart';

import '../data/transactions_repository.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_type.dart';
import '../../categories/domain/category_entity.dart';
import '../../cards/domain/card_entity.dart';
import '../../cards/domain/statement_service.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import 'new_transaction_page.dart';

// ── Enums de filtro ──────────────────────────────────────────────────────────

enum _PeriodFilter { thisMonth, lastMonth, thisWeek, all }

enum _TypeFilter { all, income, expense, transfer }

/// Filtro pelo estado de realização da transação.
enum _StatusFilter { all, paid, unpaid, future }

enum _DeleteAction { none, single, group }

extension _PeriodFilterPersistence on _PeriodFilter {
  String get key => name;
  static _PeriodFilter fromKey(String key) =>
      _PeriodFilter.values.firstWhere((e) => e.name == key,
          orElse: () => _PeriodFilter.thisMonth);
}

String _periodLabel(_PeriodFilter f) {
  switch (f) {
    case _PeriodFilter.thisMonth:  return 'Este mês';
    case _PeriodFilter.lastMonth:  return 'Mês anterior';
    case _PeriodFilter.thisWeek:   return 'Esta semana';
    case _PeriodFilter.all:        return 'Tudo';
  }
}

(DateTime, DateTime) _periodRange(_PeriodFilter f) {
  final now = DateTime.now();
  switch (f) {
    case _PeriodFilter.thisMonth:
      return (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );
    case _PeriodFilter.lastMonth:
      return (
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month, 0, 23, 59, 59),
      );
    case _PeriodFilter.thisWeek:
      final start = now.subtract(Duration(days: now.weekday - 1));
      return (
        DateTime(start.year, start.month, start.day),
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    case _PeriodFilter.all:
      return (DateTime(2000), DateTime(2100));
  }
}

// ── Page ─────────────────────────────────────────────────────────────────────

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final TransactionsRepository _transactionsRepository;
  List<TransactionEntity> _allTransactions = const [];
  List<TransactionEntity> _filtered        = const [];
  List<TransactionEntity> _provisioned     = const [];
  Map<String, CategoryEntity> _categoriesById = const {};
  Map<String, CardEntity>     _cardsById      = const {};
  bool _isLoading = true;

  late _PeriodFilter _period;
  String? _filterCategoryId;
  TransactionType? _filterType;
  _StatusFilter   _filterStatus = _StatusFilter.all;
  double? _minAmountFilter;
  double? _maxAmountFilter;
  double _maxAmountInData = 0;

  bool   _searchActive = false;
  String _searchQuery  = '';
  final _searchController = TextEditingController();
  final _searchFocus      = FocusNode();

  double _totalExpenses = 0;
  double _totalIncome   = 0;

  @override
  void initState() {
    super.initState();
    _transactionsRepository = RepositoryLocator.instance.transactions;
    final prefs = PreferencesService.instance;
    _period = _PeriodFilterPersistence.fromKey(prefs.transactionsPeriod);
    _filterCategoryId = prefs.transactionsCategoryId;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final locator        = RepositoryLocator.instance;
    final transactions   = await _transactionsRepository.getAll();
    final categoriesList = await locator.categories.getAll();
    final cardsList      = await locator.cards.getAll();

    double maxAmount = 0;
    for (final tx in transactions) {
      if (tx.isProvisioned) continue;
      final v = tx.amount.amount.abs();
      if (v > maxAmount) maxAmount = v;
    }

    setState(() {
      _allTransactions = transactions;
      _categoriesById  = {for (final c in categoriesList) c.id: c};
      _cardsById       = {for (final c in cardsList)      c.id: c};
      _maxAmountInData = maxAmount;
      _isLoading       = false;
    });
    _applyFilters();
  }

  // ── Helpers de grupo e parcelas ───────────────────────────────────────────

  List<TransactionEntity> _siblingsFor(TransactionEntity tx) {
    final groupId = tx.recurrenceSourceId ?? tx.id;
    return _allTransactions
        .where((t) =>
            t.recurrenceSourceId == groupId ||
            t.id == groupId)
        .toList();
  }

  String? _installmentLabel(TransactionEntity tx) {
    final total = tx.installmentCount;
    if (total == null || total <= 1) return null;

    final siblings = _siblingsFor(tx)
      ..sort((a, b) => a.date.compareTo(b.date));
    final index = siblings.indexWhere((t) => t.id == tx.id);
    if (index == -1) return null;

    final current = index + 1; // 1-based
    return '$current/$total';
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  void _applyFilters() {
    final (start, end) = _periodRange(_period);
    final query  = _searchQuery.toLowerCase().trim();
    final today  = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    // — Provisioned (não realizadas) filtradas por _statusFilter —
    List<TransactionEntity> provisioned = [];
    if (_filterStatus == _StatusFilter.all ||
        _filterStatus == _StatusFilter.unpaid ||
        _filterStatus == _StatusFilter.future) {
      provisioned = _allTransactions.where((tx) {
        if (!tx.isProvisioned) return false;
        final dueDate = tx.provisionedDueDate ?? tx.date;
        final dueDay  = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final isPast  = dueDay.compareTo(todayDay) <= 0;
        if (_filterStatus == _StatusFilter.unpaid  && !isPast) return false;
        if (_filterStatus == _StatusFilter.future  &&  isPast) return false;
        return true;
      }).toList()
        ..sort((a, b) {
          final da = a.provisionedDueDate ?? a.date;
          final db = b.provisionedDueDate ?? b.date;
          return da.compareTo(db);
        });
    }

    // — Realizadas filtradas por todos os critérios —
    List<TransactionEntity> result = [];
    if (_filterStatus == _StatusFilter.all ||
        _filterStatus == _StatusFilter.paid) {
      result = _allTransactions.where((tx) {
        if (tx.isProvisioned) return false;
        final inPeriod   = !tx.date.isBefore(start) && !tx.date.isAfter(end);
        final inCategory = _filterCategoryId == null ||
            tx.categoryId == _filterCategoryId;
        final inSearch   = query.isEmpty ||
            (tx.description?.toLowerCase().contains(query) ?? false);
        final inType     = _filterType == null || tx.type == _filterType;
        final amountAbs  = tx.amount.amount.abs();
        final inMin = _minAmountFilter == null || amountAbs >= _minAmountFilter!;
        final inMax = _maxAmountFilter == null || amountAbs <= _maxAmountFilter!;
        return inPeriod && inCategory && inSearch && inType && inMin && inMax;
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }

    double expenses = 0, income = 0;
    for (final tx in result) {
      if (tx.type == TransactionType.expense) {
        expenses += tx.amount.amount;
      } else if (tx.type == TransactionType.income) {
        income += tx.amount.amount;
      }
    }

    setState(() {
      _filtered      = result;
      _provisioned   = provisioned;
      _totalExpenses = expenses;
      _totalIncome   = income;
    });
  }

  void _setPeriod(_PeriodFilter f) {
    setState(() => _period = f);
    PreferencesService.instance.setTransactionsPeriod(f.key);
    _applyFilters();
  }

  void _setCategoryFilter(String? categoryId) {
    setState(() => _filterCategoryId = categoryId);
    PreferencesService.instance.setTransactionsCategoryId(categoryId);
    _applyFilters();
  }

  void _setTypeFilter(_TypeFilter filter) {
    setState(() {
      switch (filter) {
        case _TypeFilter.all:      _filterType = null; break;
        case _TypeFilter.income:   _filterType = TransactionType.income; break;
        case _TypeFilter.expense:  _filterType = TransactionType.expense; break;
        case _TypeFilter.transfer: _filterType = TransactionType.transfer; break;
      }
    });
    _applyFilters();
  }

  void _setStatusFilter(_StatusFilter s) {
    setState(() => _filterStatus = s);
    _applyFilters();
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchQuery = '';
        _searchController.clear();
        _applyFilters();
      } else {
        SchedulerBinding.instance
            .addPostFrameCallback((_) => _searchFocus.requestFocus());
      }
    });
  }

  int get _activeFilterCount {
    int count = 0;
    if (_period != _PeriodFilter.thisMonth) count++;
    if (_filterCategoryId != null) count++;
    if (_filterType != null) count++;
    if (_filterStatus != _StatusFilter.all) count++;
    if (_minAmountFilter != null || _maxAmountFilter != null) count++;
    if (_searchQuery.trim().isNotEmpty) count++;
    return count;
  }

  // ── Deleção e consolidação ────────────────────────────────────────────────

  Future<void> _deleteTransaction(TransactionEntity tx) async {
    await _transactionsRepository.remove(tx.id);

    if (tx.isBillPayment && tx.cardId != null) {
      await StatementService.instance.markPaid(
        tx.cardId!,
        tx.date.year,
        tx.date.month,
        paid: false,
      );
    }

    await _loadData();
    if (!mounted) return;

    if (tx.isBillPayment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Pagamento de fatura removido. A fatura foi reaberta.',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transação excluída')),
      );
    }
  }

  Future<_DeleteAction> _confirmDeleteWithGroup(TransactionEntity tx) async {
    final siblings = _siblingsFor(tx);
    final hasGroup = siblings.length > 1 && tx.installmentCount != null;

    if (!hasGroup && !tx.isBillPayment) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir transação'),
          content: Text(
            'Deseja excluir "${tx.description ?? 'Sem descrição'}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Excluir',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
      return ok == true ? _DeleteAction.single : _DeleteAction.none;
    }

    return showDialog<_DeleteAction>(
      context: context,
      builder: (context) {
        _DeleteAction selected = _DeleteAction.single;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Excluir transação'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"${tx.description ?? 'Sem descrição'}"'),
                  if (hasGroup) ...[
                    const SizedBox(height: 12),
                    const Text('O que você deseja excluir?'),
                    const SizedBox(height: 8),
                    RadioListTile<_DeleteAction>(
                      value: _DeleteAction.single,
                      groupValue: selected,
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => selected = v);
                      },
                      title: const Text('Somente esta parcela'),
                    ),
                    RadioListTile<_DeleteAction>(
                      value: _DeleteAction.group,
                      groupValue: selected,
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => selected = v);
                      },
                      title: Text(
                        'Toda a compra (${siblings.length} parcelas)',
                      ),
                    ),
                  ],
                  if (tx.isBillPayment) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta é um pagamento de fatura. Excluí-lo irá reabrir a fatura do cartão.',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_DeleteAction.none),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(selected),
                  child: Text('Excluir',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ],
            );
          },
        );
      },
    ).then((value) => value ?? _DeleteAction.none);
  }

  Future<bool> _handleDelete(TransactionEntity tx) async {
    final action = await _confirmDeleteWithGroup(tx);
    if (action == _DeleteAction.none) return false;

    if (action == _DeleteAction.single) {
      await _deleteTransaction(tx);
    } else {
      final siblings = _siblingsFor(tx);
      for (final t in siblings) {
        await _transactionsRepository.remove(t.id);
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Compra parcelada (${siblings.length} parcelas) excluída',
            ),
          ),
        );
      }
    }
    return true;
  }

  /// Converte uma transação provisionada em realizada (isProvisioned = false).
  /// Remove o registro antigo e insere o novo com a data de hoje.
  Future<void> _consolidatePayment(TransactionEntity tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar pagamento'),
        content: Text(
          'Marcar "${tx.description ?? 'Sem descrição'}" como pago?\n'
          'A transação será registrada com a data de hoje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final paid = TransactionEntity(
      id:                 DateTime.now().microsecondsSinceEpoch.toString(),
      amount:             tx.amount,
      date:               DateTime.now(),
      type:               tx.type,
      paymentMethod:      tx.paymentMethod,
      description:        tx.description,
      categoryId:         tx.categoryId,
      cardId:             tx.cardId,
      accountId:          tx.accountId,
      toAccountId:        tx.toAccountId,
      isBoleto:           tx.isBoleto,
      isProvisioned:      false,
      installmentCount:   tx.installmentCount,
      provisionedDueDate: tx.provisionedDueDate,
      recurrenceRule:     tx.recurrenceRule,
      recurrenceSourceId: tx.recurrenceSourceId,
      notes:              tx.notes,
      isBillPayment:      tx.isBillPayment,
    );

    await _transactionsRepository.remove(tx.id);
    await _transactionsRepository.add(paid);
    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${tx.description ?? 'Transação'} marcada como paga.',
        ),
        backgroundColor: AppColors.limitLow,
      ),
    );
  }

  // ── Forms ─────────────────────────────────────────────────────────────────

  Future<void> _openForm({TransactionEntity? initial}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NewTransactionPage(initialTransaction: initial),
      ),
    );
    if (ok == true) await _loadData();
  }

  // ── Helpers de display ────────────────────────────────────────────────────

  /// Retorna o nome da categoria para exibição, tratando bill-payment e
  /// categoryId vazio/null sem mostrar "Sem categoria" incorretamente.
  String _categoryLabel(TransactionEntity tx) {
    if (tx.isBillPayment) return 'Pagamento de fatura';
    final cat = _categoriesById[tx.categoryId];
    if (cat != null) return cat.name;
    return 'Sem categoria';
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    if (_searchActive) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _toggleSearch,
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          decoration: const InputDecoration(
            hintText: 'Buscar transação...',
            border: InputBorder.none,
          ),
          onChanged: (v) {
            setState(() => _searchQuery = v);
            _applyFilters();
          },
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
                _applyFilters();
              },
            ),
        ],
      );
    }

    return AppBar(
      title: const Text('Transações'),
      actions: [
        IconButton(
          tooltip: 'Buscar',
          icon: const Icon(Icons.search_outlined),
          onPressed: _toggleSearch,
        ),
        _FilterBadge(
          count: _activeFilterCount,
          child: IconButton(
            tooltip: 'Filtros',
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: _openFiltersBottomSheet,
          ),
        ),
      ],
    );
  }

  void _openFiltersBottomSheet() {
    final initialPeriod = _period;
    final initialType   = _filterType;
    final initialStatus = _filterStatus;
    final initialMin    = _minAmountFilter ?? 0;
    final initialMax    = _maxAmountFilter ?? _maxAmountInData;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        _PeriodFilter  modalPeriod = initialPeriod;
        TransactionType? modalType = initialType;
        _StatusFilter  modalStatus = initialStatus;
        double modalMin = initialMin;
        double modalMax = initialMax;

        _TypeFilter typeFromTx(TransactionType? txType) {
          if (txType == null) return _TypeFilter.all;
          switch (txType) {
            case TransactionType.income:   return _TypeFilter.income;
            case TransactionType.expense:  return _TypeFilter.expense;
            case TransactionType.transfer: return _TypeFilter.transfer;
          }
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedType   = typeFromTx(modalType);
            final hasAmountRange = _maxAmountInData > 0;

            return Padding(
              padding: EdgeInsets.only(
                left:   AppSpacing.lg,
                right:  AppSpacing.lg,
                top:    AppSpacing.lg,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Filtros', style: AppText.screenTitle),
                    const SizedBox(height: AppSpacing.lg),

                    // — Período —
                    Text('Período', style: AppText.sectionLabel),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _PeriodFilter.values.map((f) {
                        final selected = f == modalPeriod;
                        return ChoiceChip(
                          label: Text(_periodLabel(f)),
                          selected: selected,
                          selectedColor: AppColors.primarySubtle,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          onSelected: (_) =>
                              setModalState(() => modalPeriod = f),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // — Status —
                    Text('Status', style: AppText.sectionLabel),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _StatusFilter.all,
                        _StatusFilter.paid,
                        _StatusFilter.unpaid,
                        _StatusFilter.future,
                      ].map((s) {
                        final selected = s == modalStatus;
                        final label = switch (s) {
                          _StatusFilter.all    => 'Todos',
                          _StatusFilter.paid   => 'Pagos',
                          _StatusFilter.unpaid => 'Não pagos',
                          _StatusFilter.future => 'Futuros',
                        };
                        final color = switch (s) {
                          _StatusFilter.paid   => AppColors.limitLow,
                          _StatusFilter.unpaid => AppColors.danger,
                          _StatusFilter.future => AppColors.warning,
                          _StatusFilter.all    => AppColors.primary,
                        };
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          selectedColor: selected
                              ? color.withOpacity(0.14)
                              : AppColors.primarySubtle,
                          labelStyle: TextStyle(
                            color: selected
                                ? color
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          onSelected: (_) =>
                              setModalState(() => modalStatus = s),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // — Tipo —
                    Text('Tipo', style: AppText.sectionLabel),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: _TypeFilter.values.map((t) {
                        final selected = t == selectedType;
                        final label = switch (t) {
                          _TypeFilter.all      => 'Todos',
                          _TypeFilter.income   => 'Receitas',
                          _TypeFilter.expense  => 'Despesas',
                          _TypeFilter.transfer => 'Transferências',
                        };
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          selectedColor: AppColors.primarySubtle,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          onSelected: (_) {
                            setModalState(() {
                              switch (t) {
                                case _TypeFilter.all:
                                  modalType = null; break;
                                case _TypeFilter.income:
                                  modalType = TransactionType.income; break;
                                case _TypeFilter.expense:
                                  modalType = TransactionType.expense; break;
                                case _TypeFilter.transfer:
                                  modalType = TransactionType.transfer; break;
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // — Valor —
                    Text('Valor (R\$)', style: AppText.sectionLabel),
                    const SizedBox(height: AppSpacing.sm),
                    if (!hasAmountRange)
                      Text(
                        'Sem dados suficientes para limitar por valor.',
                        style: AppText.secondary,
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Mín: R\$ ${modalMin.toStringAsFixed(0)}',
                              style: AppText.secondary),
                          Text('Máx: R\$ ${modalMax.toStringAsFixed(0)}',
                              style: AppText.secondary),
                        ],
                      ),
                      RangeSlider(
                        values: RangeValues(modalMin, modalMax),
                        min: 0,
                        max: _maxAmountInData,
                        divisions: 20,
                        labels: RangeLabels(
                          'R\$ ${modalMin.toStringAsFixed(0)}',
                          'R\$ ${modalMax.toStringAsFixed(0)}',
                        ),
                        onChanged: (values) {
                          setModalState(() {
                            modalMin = values.start;
                            modalMax = values.end;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _period           = _PeriodFilter.thisMonth;
                              _filterType       = null;
                              _filterStatus     = _StatusFilter.all;
                              _filterCategoryId = null;
                              _minAmountFilter  = null;
                              _maxAmountFilter  = null;
                            });
                            _applyFilters();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Limpar tudo'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _period       = modalPeriod;
                              _filterType   = modalType;
                              _filterStatus = modalStatus;
                              if (hasAmountRange) {
                                _minAmountFilter =
                                    modalMin <= 0 ? null : modalMin;
                                _maxAmountFilter =
                                    modalMax >= _maxAmountInData
                                        ? null
                                        : modalMax;
                              }
                            });
                            PreferencesService.instance
                                .setTransactionsPeriod(_period.key);
                            _applyFilters();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Aplicar filtros'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Filtros inline ────────────────────────────────────────────────────────

  Widget _buildSimpleFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: _PeriodFilter.values.map((f) {
          final selected = f == _period;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
            child: FilterChip(
              label: Text(_periodLabel(f)),
              selected: selected,
              selectedColor: AppColors.primarySubtle,
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
              onSelected: (_) => _setPeriod(f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUltraFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          ..._PeriodFilter.values.map((f) {
            final selected = f == _period;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
              child: FilterChip(
                label: Text(_periodLabel(f)),
                selected: selected,
                selectedColor: AppColors.primarySubtle,
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
                onSelected: (_) => _setPeriod(f),
              ),
            );
          }),
          Container(
            width: 1,
            height: 24,
            color: AppColors.divider,
            margin:
                const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
            child: FilterChip(
              label: const Text('Todas'),
              selected: _filterCategoryId == null,
              selectedColor: AppColors.primarySubtle,
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _filterCategoryId == null
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
              onSelected: (_) => _setCategoryFilter(null),
            ),
          ),
          ..._categoriesById.values.map((cat) {
            final selected = _filterCategoryId == cat.id;
            final color = cat.colorValue != null
                ? Color(cat.colorValue!)
                : AppColors.textSecondary;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
              child: FilterChip(
                avatar: CircleAvatar(
                  backgroundColor: color.withOpacity(0.22),
                  child: Text(
                    cat.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 10, color: color),
                  ),
                ),
                label: Text(cat.name),
                selected: selected,
                selectedColor: AppColors.primarySubtle,
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
                onSelected: (_) =>
                    _setCategoryFilter(selected ? null : cat.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Status filter row (exibido em ambos os modos) ─────────────────────────

  Widget _buildStatusFilterRow() {
    const statusOptions = [
      (_StatusFilter.all,    'Todos',     null),
      (_StatusFilter.paid,   'Pagos',     AppColors.limitLow),
      (_StatusFilter.unpaid, 'Não pagos', AppColors.danger),
      (_StatusFilter.future, 'Futuros',   AppColors.warning),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: statusOptions.map((entry) {
          final (status, label, color) = entry;
          final selected = _filterStatus == status;
          final effectiveColor = color ?? AppColors.primary;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              selectedColor: effectiveColor.withOpacity(0.13),
              checkmarkColor: effectiveColor,
              labelStyle: TextStyle(
                color: selected ? effectiveColor : AppColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: selected
                  ? BorderSide(color: effectiveColor.withOpacity(0.4))
                  : null,
              onSelected: (_) => _setStatusFilter(status),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Resumo ────────────────────────────────────────────────────────────────

  Widget _buildSimpleSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
      child: _SummaryChip(
        label: 'Despesas no período',
        value: '- R\$ ${_totalExpenses.toStringAsFixed(2)}',
        color: AppColors.danger,
      ),
    );
  }

  Widget _buildUltraSummary() {
    final balance = _totalIncome - _totalExpenses;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryChip(
            label: 'Despesas',
            value: '- R\$ ${_totalExpenses.toStringAsFixed(2)}',
            color: AppColors.danger,
          ),
          _SummaryChip(
            label: 'Receitas',
            value: '+ R\$ ${_totalIncome.toStringAsFixed(2)}',
            color: AppColors.limitLow,
          ),
          _SummaryChip(
            label: 'Saldo',
            value: 'R\$ ${balance.toStringAsFixed(2)}',
            color: balance >= 0 ? AppColors.primary : AppColors.danger,
          ),
        ],
      ),
    );
  }

  // ── Gráficos ──────────────────────────────────────────────────────────────

  static const List<Color> _chartColors = [
    AppColors.primary,
    Color(0xFF7E57C2),
    Color(0xFF26A69A),
    AppColors.warning,
    Color(0xFFEC407A),
    Color(0xFF5C6BC0),
    AppColors.danger,
    AppColors.limitLow,
  ];

  Widget _buildPieCard({
    required String title,
    required List<MapEntry<String, double>> entries,
    required String Function(String key) labelOf,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.sectionLabel),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 38,
                        sections: [
                          for (int i = 0; i < entries.length; i++)
                            PieChartSectionData(
                              value: entries[i].value,
                              color: _chartColors[i % _chartColors.length],
                              title: '',
                              radius: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < entries.length; i++) ...[
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color:
                                    _chartColors[i % _chartColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs + 2),
                            Text(labelOf(entries[i].key),
                                style: AppText.secondary),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: AppSpacing.lg, bottom: AppSpacing.xs),
                          child: Text(
                            'R\$ ${entries[i].value.toStringAsFixed(2)}',
                            style: AppText.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesByCategoryChart() {
    final Map<String, double> byCategory = {};
    for (final tx in _filtered) {
      if (tx.type == TransactionType.expense) {
        final catId = tx.categoryId ?? '';
        byCategory[catId] = (byCategory[catId] ?? 0) + tx.amount.amount;
      }
    }
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _buildPieCard(
      title: 'Gastos por categoria',
      entries: entries,
      labelOf: (key) => _categoriesById[key]?.name ?? key,
    );
  }

  Widget _buildExpensesByCardChart() {
    final entries = _cardsById.values
        .map((c) {
          double total = 0;
          for (final tx in _filtered) {
            if (tx.type == TransactionType.expense && tx.cardId == c.id) {
              total += tx.amount.amount;
            }
          }
          return MapEntry(c.id, total);
        })
        .where((e) => e.value > 0)
        .toList();

    return _buildPieCard(
      title: 'Gastos por cartão',
      entries: entries,
      labelOf: (key) => _cardsById[key]?.name ?? key,
    );
  }

  // ── Seção A vencer / provisionadas ────────────────────────────────────────

  Widget _buildProvisionedSection() {
    if (_provisioned.isEmpty) return const SizedBox.shrink();

    final today    = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    // Título dinâmico conforme o filtro de status
    final sectionTitle = switch (_filterStatus) {
      _StatusFilter.future => 'FUTUROS',
      _StatusFilter.unpaid => 'NÃO PAGOS',
      _            => 'A VENCER',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.schedule_outlined,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                sectionTitle,
                style: AppText.badge.copyWith(
                  color: AppColors.warning,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        ..._provisioned.map((tx) {
          final dueDate = tx.provisionedDueDate ?? tx.date;
          final dueDay  =
              DateTime(dueDate.year, dueDate.month, dueDate.day);
          final daysLeft   = dueDay.difference(todayDay).inDays;
          final isOverdue  = daysLeft < 0;
          final isDueToday = daysLeft == 0;

          final dueDateText =
              '${dueDate.day.toString().padLeft(2, '0')}'
              '/${dueDate.month.toString().padLeft(2, '0')}'
              '/${dueDate.year}';

          final String daysLabel;
          if (isOverdue) {
            daysLabel =
                'Vencido há ${-daysLeft} dia${(-daysLeft) != 1 ? 's' : ''}';
          } else if (isDueToday) {
            daysLabel = 'Vence hoje';
          } else {
            daysLabel =
                'Vence em $daysLeft dia${daysLeft != 1 ? 's' : ''}';
          }

          final badgeColor = isOverdue
              ? AppColors.danger
              : (isDueToday ? AppColors.warning : AppColors.primary);

          final card            = tx.cardId != null ? _cardsById[tx.cardId!] : null;
          final installmentLabel = _installmentLabel(tx);
          final installmentText  =
              installmentLabel != null ? ' ($installmentLabel)' : '';

          final categoryLabel = _categoryLabel(tx);

          return Dismissible(
            key: ValueKey('prov_${tx.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _handleDelete(tx),
            onDismissed: (_) {},
            background: Container(
              color: AppColors.danger,
              alignment: Alignment.centerRight,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: ListTile(
              onTap: () => _openForm(initial: tx),
              leading: tx.isBillPayment
                  ? CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.primary.withOpacity(0.18),
                      child: Icon(Icons.credit_card_outlined,
                          size: 16, color: AppColors.primary),
                    )
                  : _CategoryDot(
                      category: _categoriesById[tx.categoryId]),
              title: Text(
                  '${tx.description ?? 'Sem descrição'}$installmentText'),
              subtitle: Text(
                '$categoryLabel'
                '${card != null ? ' · ${card.name}' : ''}'
                ' · $dueDateText',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '- R\$ ${tx.amount.amount.toStringAsFixed(2)}',
                        style: AppText.body.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs + 2,
                            vertical: AppSpacing.xs - 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text(
                          daysLabel,
                          style: AppText.badge.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    tooltip: 'Marcar como pago',
                    icon: Icon(Icons.check_circle_outline,
                        color: AppColors.limitLow, size: 22),
                    onPressed: () => _consolidatePayment(tx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          );
        }),
        const Divider(height: 1),
      ],
    );
  }

  // ── Lista de transações realizadas ────────────────────────────────────────

  List<_TransactionDayGroup> _groupByDay(List<TransactionEntity> txs) {
    final Map<String, List<TransactionEntity>> map = {};
    for (final tx in txs) {
      final key =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(tx);
    }
    return map.entries
        .map((e) => _TransactionDayGroup(dateKey: e.key, txs: e.value))
        .toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
  }

  Widget _buildTransactionList() {
    if (_filtered.isEmpty) {
      return const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nenhuma transação',
        message: 'Tente ajustar os filtros ou adicione uma nova transação.',
      );
    }

    final groups = _groupByDay(_filtered);
    final isUltra = AppModeController.instance.mode == AppMode.ultra;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      itemBuilder: (context, gi) {
        final group = groups[gi];
        final parts = group.dateKey.split('-');
        final day   = int.parse(parts[2]);
        final month = int.parse(parts[1]);
        final year  = int.parse(parts[0]);
        final date  = DateTime(year, month, day);

        final now       = DateTime.now();
        final today     = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        final String dateLabel;
        if (date == today) {
          dateLabel = 'Hoje';
        } else if (date == yesterday) {
          dateLabel = 'Ontem';
        } else {
          const months = [
            '', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
            'jul', 'ago', 'set', 'out', 'nov', 'dez',
          ];
          dateLabel = '$day ${months[month]}${year != now.year ? ' $year' : ''}';
        }

        final dayTotal = group.txs.fold<double>(0, (sum, tx) {
          if (tx.type == TransactionType.income)    return sum + tx.amount.amount;
          if (tx.type == TransactionType.expense)   return sum - tx.amount.amount;
          return sum;
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // — Cabeçalho do dia —
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateLabel.toUpperCase(),
                    style: AppText.badge.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${dayTotal >= 0 ? '+' : ''}R\$ ${dayTotal.toStringAsFixed(2)}',
                    style: AppText.badge.copyWith(
                      color: dayTotal >= 0
                          ? AppColors.limitLow
                          : AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // — Itens do dia —
            ...group.txs.map((tx) {
              final isTransfer = tx.type == TransactionType.transfer;
              final isIncome   = tx.type == TransactionType.income;
              final amountSign = isIncome ? '+' : '-';
              final amountColor = isTransfer
                  ? AppColors.primary
                  : (isIncome ? AppColors.limitLow : AppColors.danger);

              final card = tx.cardId != null ? _cardsById[tx.cardId!] : null;
              final installmentLabel = _installmentLabel(tx);
              final installmentText  =
                  installmentLabel != null ? ' ($installmentLabel)' : '';

              final categoryLabel = _categoryLabel(tx);

              String subtitle;
              if (isUltra) {
                subtitle =
                    '$categoryLabel${card != null ? ' · ${card.name}' : ''}';
              } else {
                subtitle = categoryLabel;
              }

              return Dismissible(
                key: ValueKey(tx.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _handleDelete(tx),
                onDismissed: (_) {},
                background: Container(
                  color: AppColors.danger,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child:
                      const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: ListTile(
                  onTap: () => _openForm(initial: tx),
                  leading: tx.isBillPayment
                      ? CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppColors.primary.withOpacity(0.18),
                          child: Icon(Icons.credit_card_outlined,
                              size: 16, color: AppColors.primary),
                        )
                      : _CategoryDot(
                          category: _categoriesById[tx.categoryId]),
                  title: Text(
                      '${tx.description ?? 'Sem descrição'}$installmentText'),
                  subtitle: Text(subtitle),
                  trailing: Text(
                    '$amountSign R\$ ${tx.amount.amount.toStringAsFixed(2)}',
                    style: AppText.body.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isUltra = AppModeController.instance.mode == AppMode.ultra;

    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // — Filtros de período —
                        if (isUltra)
                          _buildUltraFiltersRow()
                        else
                          _buildSimpleFiltersRow(),

                        // — Filtros de status —
                        _buildStatusFilterRow(),

                        // — Resumo —
                        if (isUltra)
                          _buildUltraSummary()
                        else
                          _buildSimpleSummary(),

                        // — Seção provisionadas —
                        _buildProvisionedSection(),

                        // — Gráficos (Ultra only) —
                        if (isUltra) ...[
                          _buildExpensesByCategoryChart(),
                          _buildExpensesByCardChart(),
                        ],

                        // — Lista de transações realizadas —
                        _buildTransactionList(),

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Nova transação',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _TransactionDayGroup {
  final String dateKey;
  final List<TransactionEntity> txs;
  const _TransactionDayGroup({required this.dateKey, required this.txs});
}

class _CategoryDot extends StatelessWidget {
  final CategoryEntity? category;
  const _CategoryDot({this.category});

  @override
  Widget build(BuildContext context) {
    final color = category?.colorValue != null
        ? Color(category!.colorValue!)
        : AppColors.textSecondary;
    final label = category != null ? category!.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(0.18),
      child: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.secondary.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: AppText.body
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _FilterBadge extends StatelessWidget {
  final int count;
  final Widget child;
  const _FilterBadge({required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
