import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/card_entity.dart';
import '../domain/statement_cycle.dart';
import '../domain/statement_service.dart';

class CardStatementsPage extends StatefulWidget {
  const CardStatementsPage({super.key, required this.card});
  final CardEntity card;

  @override
  State<CardStatementsPage> createState() => _CardStatementsPageState();
}

class _CardStatementsPageState extends State<CardStatementsPage> {
  final _service = StatementService.instance;

  List<StatementCycle> _cycles = const [];
  int _selectedIndex = 0; // 0 = mais recente
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final txs = await RepositoryLocator.instance.transactions.getAll();
    final cycles = await _service.cyclesForCard(widget.card, txs, count: 6);
    setState(() {
      _cycles = cycles;
      _isLoading = false;
    });
  }

  StatementCycle get _current => _cycles[_selectedIndex];

  void _prev() {
    if (_selectedIndex < _cycles.length - 1) {
      setState(() => _selectedIndex++);
    }
  }

  void _next() {
    if (_selectedIndex > 0) {
      setState(() => _selectedIndex--);
    }
  }

  Future<void> _togglePaid() async {
    final cycle = _current;
    final newPaid = !cycle.isPaid;
    await _service.markPaid(
      widget.card.id,
      cycle.cycleEnd.year,
      cycle.cycleEnd.month,
      paid: newPaid,
    );
    await _load();
    if (!mounted) return;
    final monthLabel = _monthName(cycle.cycleEnd.month);
    final year = cycle.cycleEnd.year;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newPaid
              ? 'Fatura de $monthLabel/$year marcada como paga'
              : 'Fatura de $monthLabel/$year desmarcada',
        ),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────

  static const _monthNames = [
    '', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  static const _monthNamesFull = [
    '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  String _monthName(int m) => _monthNames[m];

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${_monthNames[d.month]}';

  String _fmtMoney(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  // ── widgets ──────────────────────────────────────────────────────

  Widget _buildPicker() {
    final cycle = _current;
    final label =
        '${_monthNamesFull[cycle.cycleEnd.month]} ${cycle.cycleEnd.year}';
    final canPrev = _selectedIndex < _cycles.length - 1;
    final canNext = _selectedIndex > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: canPrev ? _prev : null,
            color: canPrev ? null : AppColors.textSecondary,
          ),
          Text(
            label,
            style: AppText.sectionLabel.copyWith(fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canNext ? _next : null,
            color: canNext ? null : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final cycle = _current;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final Color badgeColor;
    final String badgeLabel;
    if (cycle.isPaid) {
      badgeColor = AppColors.limitLow;
      badgeLabel = 'Paga';
    } else if (cycle.cycleEnd.isBefore(today)) {
      badgeColor = AppColors.danger;
      badgeLabel = 'Vencida';
    } else {
      badgeColor = AppColors.warning;
      badgeLabel = cycle.isOpen ? 'Aberta' : 'Aberta';
    }

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_fmt(cycle.cycleStart)}  →  ${_fmt(cycle.cycleEnd)}',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Venc. ${_fmt(cycle.dueDate)}',
                  style: AppText.secondary,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: badgeColor.withOpacity(0.4)),
            ),
            child: Text(
              badgeLabel,
              style: AppText.badge.copyWith(color: badgeColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(TransactionEntity tx, {required bool showDivider}) {
    final isProvisioned = tx.isProvisioned;
    final desc = tx.description?.isNotEmpty == true
        ? tx.description!
        : 'Sem descrição';
    final cat = tx.categoryId ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(
                  isProvisioned
                      ? Icons.schedule_outlined
                      : Icons.arrow_downward_rounded,
                  size: 14,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc,
                      style: AppText.body.copyWith(
                        fontStyle: isProvisioned
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cat.isNotEmpty)
                      Text(
                        cat,
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
                    _fmtMoney(tx.amount.amount),
                    style: AppText.amount.copyWith(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${tx.date.day.toString().padLeft(2, '0')}/${_monthNames[tx.date.month]}',
                    style: AppText.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider,
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
          ),
      ],
    );
  }

  Widget _buildFooter() {
    final cycle = _current;
    final isPartial = cycle.isOpen;
    final label = isPartial ? 'Total parcial' : 'Total da fatura';

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.sectionLabel),
              Text(
                _fmtMoney(cycle.total),
                style: AppText.amount.copyWith(
                  color: AppColors.danger,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: cycle.isPaid
                ? OutlinedButton.icon(
                    onPressed: _togglePaid,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Desmarcar como paga'),
                  )
                : ElevatedButton.icon(
                    onPressed: _togglePaid,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Marcar como paga'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.limitLow,
                      foregroundColor: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.card.name} — Faturas'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPicker(),
                _buildHeader(),
                Expanded(
                  child: _current.transactions.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Nenhuma transação',
                          message: 'Nenhuma despesa neste período.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                              top: AppSpacing.sm, bottom: AppSpacing.sm),
                          itemCount: _current.transactions.length,
                          itemBuilder: (context, i) {
                            final tx = _current.transactions[i];
                            final isLast =
                                i == _current.transactions.length - 1;
                            return _buildTransactionRow(tx,
                                showDivider: !isLast);
                          },
                        ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }
}
