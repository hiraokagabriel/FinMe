import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../domain/payment_hub_service.dart';
import '../domain/payment_item.dart';

class PaymentHubPage extends StatefulWidget {
  const PaymentHubPage({super.key});

  @override
  State<PaymentHubPage> createState() => _PaymentHubPageState();
}

class _PaymentHubPageState extends State<PaymentHubPage> {
  final _service = PaymentHubService.instance;

  List<PaymentItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await _service.load();
    setState(() {
      _items     = items;
      _isLoading = false;
    });
  }

  Future<void> _setWindow(int days) async {
    await _service.setWindowDays(days);
    await _load();
  }

  Future<void> _markAsPaid(PaymentItem item) async {
    await _service.markAsPaid(item);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${item.label}" marcado como pago')),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _formatMoney(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  // ─── Resumo ───────────────────────────────────────────────

  Widget _buildSummary() {
    final total = _items.fold(0.0, (s, i) => s + i.amount);
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total a pagar', style: AppText.secondary),
                const SizedBox(height: 2),
                Text(
                  _formatMoney(total),
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_items.length} item(s)', style: AppText.secondary),
              const SizedBox(height: 2),
              Text(
                'próximos ${_service.windowDays} dias',
                style: AppText.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Selector de janela ──────────────────────────────────────

  Widget _buildWindowSelector() {
    final current = _service.windowDays;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 7,  label: Text('7 dias')),
          ButtonSegment(value: 14, label: Text('14 dias')),
          ButtonSegment(value: 30, label: Text('30 dias')),
        ],
        selected: {current},
        onSelectionChanged: (s) => _setWindow(s.first),
      ),
    );
  }

  // ─── Tile de fatura de cartão ───────────────────────────────

  Widget _buildCardBillTile(PaymentItem item) {
    final now      = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final closing  = item.closingDate;
    final isUrgent = closing != null &&
        !closing.isBefore(today) &&
        closing.isBefore(today.add(const Duration(days: 3)));

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm / 2),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isUrgent
              ? AppColors.warning.withOpacity(0.5)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_outlined, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.label,
                  style: AppText.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    'Fecha em breve',
                    style: AppText.badge
                        .copyWith(color: AppColors.warning),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (closing != null)
                Text(
                  'Fecha ${_formatDate(closing)}',
                  style: AppText.secondary,
                ),
              if (closing != null)
                const SizedBox(width: AppSpacing.md),
              Text(
                'Vence ${_formatDate(item.dueDate)}',
                style: AppText.secondary,
              ),
              const Spacer(),
              Text(
                _formatMoney(item.amount),
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _markAsPaid(item),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Marcar como pago'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                textStyle: AppText.badge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tile de provisionado ───────────────────────────────────

  Widget _buildProvisionedTile(PaymentItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm / 2),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.label,
                  style: AppText.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _formatMoney(item.amount),
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                'Vence ${_formatDate(item.dueDate)}',
                style: AppText.secondary,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _markAsPaid(item),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Marcar como pago'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.success,
                  textStyle: AppText.badge,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bills       = _items.where((i) => i.type == PaymentItemType.cardBill).toList();
    final provisioned = _items.where((i) => i.type == PaymentItemType.provisioned).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Pagamentos'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Column(
                  children: [
                    _buildWindowSelector(),
                    Expanded(
                      child: AppEmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'Nada a pagar',
                        message:
                            'Você não tem pendentes nos próximos ${_service.windowDays} dias 🎉',
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _buildSummary(),
                    _buildWindowSelector(),
                    if (bills.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                        child: Text('Faturas de cartão',
                            style: AppText.sectionHeader),
                      ),
                      ...bills.map(_buildCardBillTile),
                    ],
                    if (provisioned.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                        child: Text('A pagar',
                            style: AppText.sectionHeader),
                      ),
                      ...provisioned.map(_buildProvisionedTile),
                    ],
                  ],
                ),
    );
  }
}
