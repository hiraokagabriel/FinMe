import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/analysis/spending_alert.dart';
import '../../../core/analysis/spending_analyzer.dart';
import '../../../core/analysis/subscription_detector.dart';
import '../../../core/analysis/subscription_summary.dart';
import '../../../core/services/preferences_service.dart';
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

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  List<TransactionEntity> _allTransactions = const [];
  List<CategoryEntity> _categories = const [];
  List<CardEntity> _cards = const [];
  List<SubscriptionSummary> _subscriptions = const [];
  List<SpendingAlert> _alerts = const [];
  bool _isLoading = true;
  bool _isExporting = false;

  late TabController _tabController;

  // Filtros
  DateTime? _from;
  DateTime? _to;
  _FilterPreset _preset = _FilterPreset.thisMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final saved = PreferencesService.instance.reportsPeriod;
    final restoredPreset = _FilterPreset.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => _FilterPreset.thisMonth,
    );
    _applyPreset(restoredPreset);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final locator = RepositoryLocator.instance;
    final txs = await locator.transactions.getAll();
    final cats = await locator.categories.getAll();
    final cds = await locator.cards.getAll();
    if (!mounted) return;
    final subs = detectSubscriptions(txs);
    final alerts = analyzeSpending(txs);
    setState(() {
      _allTransactions = txs;
      _categories = cats;
      _cards = cds;
      _subscriptions = subs;
      _alerts = alerts;
      _isLoading = false;
    });
  }

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
          break;
      }
    });
    if (preset != _FilterPreset.custom) {
      PreferencesService.instance.setReportsPeriod(preset.name);
    }
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

  List<TransactionEntity> get _filtered {
    return _allTransactions.where((tx) {
      if (_from != null && tx.date.isBefore(_from!)) return false;
      if (_to != null &&
          tx.date.isAfter(_to!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

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
        [
          'Data',
          'Descrição',
          'Tipo',
          'Categoria',
          'Cartão/Banco',
          'Valor (R\$)',
          'Provisionado'
        ],
      ];
      final catMap = {for (final c in _categories) c.id: c.name};
      final cardMap = {
        for (final c in _cards) c.id: '${c.bankName} - ${c.name}'
      };
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
      final FileSaveLocation? result = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (result == null) return;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Resumo'),
            const Tab(text: 'Categorias'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Insights'),
                  if (_alerts.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _alerts.any((a) => a.severity == 3)
                            ? AppColors.danger
                            : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_alerts.length}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildResumoTab(),
                _buildCategoriasTab(),
                _buildInsightsTab(),
              ],
            ),
    );
  }

  // ── Aba Resumo ─────────────────────────────────────────────────────────────

  Widget _buildResumoTab() {
    final (income, expense) = _totals;
    final balance = income - expense;
    final filtered = _filtered;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
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
                      onSelected: (_) => p == _FilterPreset.custom
                          ? setState(() => _preset = _FilterPreset.custom)
                          : _applyPreset(p),
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
        Row(
          children: [
            _TotalChip(label: 'Receitas', value: income, color: AppColors.limitLow),
            const SizedBox(width: AppSpacing.md),
            _TotalChip(label: 'Despesas', value: expense, color: AppColors.danger),
            const SizedBox(width: AppSpacing.md),
            _TotalChip(
              label: 'Saldo',
              value: balance,
              color: balance >= 0 ? AppColors.primary : AppColors.danger,
            ),
          ].map((w) => Expanded(child: w)).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Transações', style: AppText.sectionLabel),
                    Text('${filtered.length} registros',
                        style: AppText.secondary),
                  ],
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(
                      child: Text('Nenhuma transação no período',
                          style: AppText.secondary),
                    ),
                  )
                else ...[
                  const SizedBox(height: AppSpacing.md),
                  ...filtered.take(50).map((tx) {
                    final cat = _categories
                        .where((c) => c.id == tx.categoryId)
                        .firstOrNull;
                    final isIncome = tx.type == TransactionType.income;
                    final valueColor =
                        isIncome ? AppColors.limitLow : AppColors.danger;
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tx.description ?? 'Sem descrição',
                                    style: AppText.body),
                                Text(
                                  '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}  ${cat?.name ?? ''}',
                                  style: AppText.secondary,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isIncome ? '+' : '-'} R\$ ${tx.amount.amount.toStringAsFixed(2)}',
                            style: AppText.amount
                                .copyWith(color: valueColor, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (filtered.length > 50)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
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
    );
  }

  // ── Aba Categorias ─────────────────────────────────────────────────────────

  Widget _buildCategoriasTab() {
    final byCat = _byCategory;
    final (_, expense) = _totals;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (byCat.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg * 2),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pie_chart_outline,
                      size: 36, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Sem despesas no período',
                      style: AppText.secondary),
                ],
              ),
            ),
          )
        else
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
                    final pct = expense > 0 ? e.value / expense : 0.0;
                    final catColor = cat?.colorValue != null
                        ? Color(cat!.colorValue!)
                        : AppColors.primary;
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            borderRadius:
                                BorderRadius.circular(AppRadius.chip),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: AppColors.limitTrack,
                              valueColor: AlwaysStoppedAnimation<Color>(
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
      ],
    );
  }

  // ── Aba Insights ───────────────────────────────────────────────────────────

  Widget _buildInsightsTab() {
    final subs = _subscriptions;
    final alerts = _alerts;
    final totalMonthly =
        subs.fold<double>(0, (sum, s) => sum + s.monthlyAmount);
    final totalAnnual = totalMonthly * 12;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── Alertas ──────────────────────────────────────────────────────
        if (alerts.isNotEmpty) ...[
          Text('Alertas', style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.md),
          ...alerts.map((alert) {
            final cat = alert.categoryId != null
                ? _categories
                    .where((c) => c.id == alert.categoryId)
                    .firstOrNull
                : null;
            return _AlertTile(alert: alert, category: cat);
          }),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── Assinaturas ───────────────────────────────────────────────────
        if (subs.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Custo mensal', style: AppText.secondary),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'R\$ ${totalMonthly.toStringAsFixed(2)}',
                          style: AppText.amount.copyWith(
                              color: AppColors.danger, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 36,
                      color: AppColors.divider),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Custo anual', style: AppText.secondary),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'R\$ ${totalAnnual.toStringAsFixed(2)}',
                            style: AppText.amount.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('Assinaturas detectadas', style: AppText.sectionLabel),
        const SizedBox(height: AppSpacing.md),
        if (subs.isEmpty)
          _InsightsEmptyState(
            icon: Icons.autorenew_outlined,
            message: 'Nenhuma assinatura detectada',
            hint:
                'Transações com padrão mensal repetido aparecerão aqui.',
          )
        else
          ...subs.map((s) => _SubscriptionTile(
                subscription: s,
                category: _categories
                    .where((c) => c.id == s.categoryId)
                    .firstOrNull,
              )),
      ],
    );
  }
}

// ── Enum presets ───────────────────────────────────────────────────────────

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

// ── Widget de alerta ───────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.category});

  final SpendingAlert alert;
  final dynamic category; // CategoryEntity?

  @override
  Widget build(BuildContext context) {
    final Color accentColor = switch (alert.severity) {
      3 => AppColors.danger,
      2 => AppColors.warning,
      _ => AppColors.primary,
    };
    final IconData iconData = switch (alert.type) {
      SpendingAlertType.categoryDominant => Icons.donut_large_outlined,
      SpendingAlertType.monthlySpike => Icons.trending_up_outlined,
      SpendingAlertType.categorySpike => Icons.north_east_outlined,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Icon(iconData, size: 18, color: accentColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(alert.title,
                            style: AppText.body.copyWith(
                                fontWeight: FontWeight.w600)),
                      ),
                      if (category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primarySubtle,
                            borderRadius:
                                BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Text(
                            category!.name as String,
                            style: AppText.secondary
                                .copyWith(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(alert.description, style: AppText.secondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget assinatura ──────────────────────────────────────────────────────

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({
    required this.subscription,
    required this.category,
  });

  final SubscriptionSummary subscription;
  final dynamic category;

  static const _monthAbbr = [
    '',
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  @override
  Widget build(BuildContext context) {
    final d = subscription.lastDate;
    final lastDateStr =
        '${d.day.toString().padLeft(2, '0')} ${_monthAbbr[d.month]} ${d.year}';
    final freqLabel =
        subscription.frequency == 'yearly' ? 'Anual' : 'Mensal';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Icon(Icons.autorenew_outlined,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subscription.description,
                    style: AppText.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${category?.name ?? 'Sem categoria'} · $freqLabel · última em $lastDateStr',
                    style: AppText.secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'R\$ ${subscription.avgAmount.toStringAsFixed(2)}',
                  style: AppText.amount
                      .copyWith(color: AppColors.danger, fontSize: 13),
                ),
                Text(
                  subscription.frequency == 'yearly'
                      ? 'R\$ ${subscription.monthlyAmount.toStringAsFixed(2)}/mês'
                      : '${subscription.occurrences}x detectado',
                  style: AppText.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsEmptyState extends StatelessWidget {
  const _InsightsEmptyState({
    required this.icon,
    required this.message,
    required this.hint,
  });

  final IconData icon;
  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg * 2),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.sm),
            Text(
                message,
                style: AppText.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.xs),
            Text(hint,
                style: AppText.secondary,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  const _DateTile(
      {required this.label, required this.date, required this.onTap});
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
                Text(label,
                    style: AppText.secondary.copyWith(fontSize: 10)),
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
      {required this.label, required this.value, required this.color});
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
              style: AppText.amount.copyWith(color: color, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
