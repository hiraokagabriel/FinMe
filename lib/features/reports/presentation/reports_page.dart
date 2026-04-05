import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../categories/domain/category_entity.dart';
import '../../cards/domain/card_entity.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<TransactionEntity> _allTransactions = const [];
  List<CategoryEntity> _categories = const [];
  List<CardEntity> _cards = const [];
  bool _isLoading = true;
  bool _isExporting = false;

  // Filtros
  DateTime? _from;
  DateTime? _to;
  _FilterPreset _preset = _FilterPreset.thisMonth;

  @override
  void initState() {
    super.initState();
    _applyPreset(_FilterPreset.thisMonth);
    _load();
  }

  Future<void> _load() async {
    final locator = RepositoryLocator.instance;
    final txs = await locator.transactions.getAll();
    final cats = await locator.categories.getAll();
    final cds = await locator.cards.getAll();
    if (!mounted) return;
    setState(() {
      _allTransactions = txs;
      _categories = cats;
      _cards = cds;
      _isLoading = false;
    });
  }

  // Aplica preset de período
  void _applyPreset(_FilterPreset preset) {
    final now = DateTime.now();
    setState(() {
      _preset = preset;
      switch (preset) {
        case _FilterPreset.thisMonth:
          _from = DateTime(now.year, now.month, 1);
          _to = DateTime(now.year, now.month + 1, 0);
        case _FilterPreset.last30:
          _from = now.subtract(const Duration(days: 30));
          _to = now;
        case _FilterPreset.last90:
          _from = now.subtract(const Duration(days: 90));
          _to = now;
        case _FilterPreset.thisYear:
          _from = DateTime(now.year, 1, 1);
          _to = DateTime(now.year, 12, 31);
        case _FilterPreset.custom:
          // Mantém datas existentes
          break;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_from ?? now.subtract(const Duration(days: 30)))
        : (_to ?? now);
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (result == null) return;
    setState(() {
      _preset = _FilterPreset.custom;
      if (isFrom) {
        _from = result;
      } else {
        _to = result;
      }
    });
  }

  // Transações filtradas pelo período
  List<TransactionEntity> get _filtered {
    return _allTransactions.where((tx) {
      if (_from != null && tx.date.isBefore(_from!)) return false;
      if (_to != null && tx.date.isAfter(_to!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Totais do período
  (double, double) get _totals {
    double income = 0;
    double expense = 0;
    for (final tx in _filtered) {
      if (tx.isProvisioned) continue;
      if (tx.type == TransactionType.income) {
        income += tx.amount.amount;
      } else {
        expense += tx.amount.amount;
      }
    }
    return (income, expense);
  }

  // Gasto por categoria
  Map<String, double> get _byCategory {
    final map = <String, double>{};
    for (final tx in _filtered) {
      if (tx.isProvisioned || tx.type != TransactionType.expense) continue;
      if (tx.categoryId == null) continue;
      map[tx.categoryId!] = (map[tx.categoryId!] ?? 0) + tx.amount.amount;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  // Exporta CSV
  Future<void> _exportCsv() async {
    final txs = _filtered;
    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma transação no período')));
      return;
    }

    setState(() => _isExporting = true);

    try {
      final rows = <List<String>>[
        ['Data', 'Descrição', 'Tipo', 'Categoria', 'Cartão/Banco', 'Valor (R\$)', 'Provisionado'],
      ];

      final catMap = {for (final c in _categories) c.id: c.name};
      final cardMap = {for (final c in _cards) c.id: '${c.bankName} - ${c.name}'};

      for (final tx in txs) {
        rows.add([
          '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}',
          tx.description ?? '',
          tx.type == TransactionType.income ? 'Receita' : 'Despesa',
          tx.categoryId != null ? (catMap[tx.categoryId!] ?? tx.categoryId!) : '',
          tx.cardId != null ? (cardMap[tx.cardId!] ?? tx.cardId!) : '',
          tx.amount.amount.toStringAsFixed(2),
          tx.isProvisioned ? 'Sim' : 'Não',
        ]);
      }

      final csvContent = const ListToCsvConverter().convert(rows);
      final fileName =
          'finme_relatorio_${DateTime.now().millisecondsSinceEpoch}.csv';

      // Usa file_selector para o usuário escolher onde salvar (funciona em Windows/macOS/Linux)
      final FileSaveLocation? result = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );

      if (result == null) return; // cancelou

      final file = File(result.path);
      await file.writeAsString(csvContent);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exportado: ${result.path}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (income, expense) = _totals;
    final balance = income - expense;
    final byCat = _byCategory;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          TextButton.icon(
            onPressed: _isExporting ? null : _exportCsv,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            label: Text(_isExporting ? 'Exportando...' : 'Exportar CSV'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // ── Filtro de período ──────────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Período', style: AppText.sectionLabel),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _FilterPreset.values.map((p) {
                            final selected = _preset == p;
                            return ChoiceChip(
                              label: Text(p.label),
                              selected: selected,
                              onSelected: (_) {
                                if (p == _FilterPreset.custom) {
                                  setState(() =>
                                      _preset = _FilterPreset.custom);
                                } else {
                                  _applyPreset(p);
                                }
                              },
                              selectedColor: AppColors.primarySubtle,
                              labelStyle: TextStyle(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _DateTile(
                                label: 'De',
                                date: _from,
                                onTap: () => _pickDate(isFrom: true),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _DateTile(
                                label: 'Até',
                                date: _to,
                                onTap: () => _pickDate(isFrom: false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Totais do período ─────────────────────────────────────────────────
                Row(
                  children: [
                    _TotalChip(
                        label: 'Receitas',
                        value: income,
                        color: AppColors.limitLow),
                    const SizedBox(width: AppSpacing.md),
                    _TotalChip(
                        label: 'Despesas',
                        value: expense,
                        color: AppColors.danger),
                    const SizedBox(width: AppSpacing.md),
                    _TotalChip(
                        label: 'Saldo',
                        value: balance,
                        color: balance >= 0
                            ? AppColors.primary
                            : AppColors.danger),
                  ].map((w) => Expanded(child: w)).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Gastos por categoria ─────────────────────────────────────────────
                if (byCat.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Despesas por categoria',
                              style: AppText.sectionLabel),
                          const SizedBox(height: AppSpacing.md),
                          ...byCat.entries.map((e) {
                            final cat = _categories
                                .where((c) => c.id == e.key)
                                .firstOrNull;
                            final pct = expense > 0
                                ? e.value / expense
                                : 0.0;
                            final catColor = cat?.colorValue != null
                                ? Color(cat!.colorValue!)
                                : AppColors.primary;
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(cat?.name ?? e.key,
                                          style: AppText.body),
                                      Text(
                                        'R\$ ${e.value.toStringAsFixed(2)}  (${(pct * 100).toStringAsFixed(0)}%)',
                                        style: AppText.secondary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.chip),
                                    child: LinearProgressIndicator(
                                      value: pct.clamp(0.0, 1.0),
                                      minHeight: 5,
                                      backgroundColor:
                                          AppColors.limitTrack,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              catColor),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── Lista de transações do período ───────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Transações',
                                style: AppText.sectionLabel),
                            Text('${filtered.length} registros',
                                style: AppText.secondary),
                          ],
                        ),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.lg),
                            child: Center(
                              child: Text(
                                  'Nenhuma transação no período',
                                  style: AppText.secondary),
                            ),
                          )
                        else ...[
                          const SizedBox(height: AppSpacing.md),
                          ...filtered.take(50).map((tx) {
                            final cat = _categories
                                .where((c) => c.id == tx.categoryId)
                                .firstOrNull;
                            final isIncome =
                                tx.type == TransactionType.income;
                            final valueColor = isIncome
                                ? AppColors.limitLow
                                : AppColors.danger;
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            tx.description ?? 'Sem descrição',
                                            style: AppText.body),
                                        Text(
                                          '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}'  '${cat?.name ?? ''}',
                                          style: AppText.secondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isIncome ? '+' : '-'} R\$ ${tx.amount.amount.toStringAsFixed(2)}',
                                    style: AppText.amount.copyWith(
                                        color: valueColor,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (filtered.length > 50)
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: AppSpacing.sm),
                              child: Text(
                                'Mostrando 50 de ${filtered.length} — exporte o CSV para ver todos.',
                                style: AppText.secondary,
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Enum presets ───────────────────────────────────────────────────────────────

enum _FilterPreset {
  thisMonth,
  last30,
  last90,
  thisYear,
  custom;

  String get label => switch (this) {
        thisMonth => 'Este mês',
        last30 => 'Últimos 30 dias',
        last90 => 'Últimos 90 dias',
        thisYear => 'Este ano',
        custom => 'Personalizado',
      };
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  const _DateTile(
      {required this.label,
      required this.date,
      required this.onTap});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = date != null
        ? '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}'
        : 'Selecionar';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.secondary.copyWith(fontSize: 10)),
                Text(text, style: AppText.body),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  const _TotalChip(
      {required this.label,
      required this.value,
      required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.secondary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'R\$ ${value.toStringAsFixed(2)}',
              style: AppText.amount
                  .copyWith(color: color, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
