import 'package:flutter/material.dart';
import '../domain/account_entity.dart';
import '../data/accounts_repository.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../transactions/domain/transaction_entity.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late AccountsRepository _repo;
  List<AccountEntity> _accounts = [];

  @override
  void initState() {
    super.initState();
    _repo = RepositoryLocator.instance.accounts;
    _load();
  }

  Future<void> _load() async {
    final accounts = await _repo.getAll();
    if (!mounted) return;
    setState(() => _accounts = accounts);
  }

  Future<void> _openForm({AccountEntity? editing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AccountForm(repo: _repo, editing: editing),
    );
    _load();
  }

  Future<void> _delete(AccountEntity account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta'),
        content: Text('Excluir "${account.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.delete(account.id);
      _load();
    }
  }

  Future<double> _computeBalance(AccountEntity account) async {
    final List<TransactionEntity> txs =
        await RepositoryLocator.instance.transactions.getAll();
    double balance = account.initialBalance;
    for (final tx in txs) {
      if (tx.accountId != account.id) continue;
      if (tx.type.index == 0) {
        balance += tx.amount.amount;
      } else {
        balance -= tx.amount.amount;
      }
    }
    return balance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova conta',
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _accounts.isEmpty
          ? AppEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Nenhuma conta cadastrada',
              message: 'Crie sua primeira conta para começar a registrar transações.',
              actionLabel: 'Criar conta',
              onAction: () => _openForm(),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final account = _accounts[index];
                final color = Color(account.colorValue);
                return FutureBuilder<double>(
                  future: _computeBalance(account),
                  builder: (context, snap) {
                    final balance = snap.data ?? account.initialBalance;
                    return Dismissible(
                      key: Key(account.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: cs.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await _delete(account);
                        return false;
                      },
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openForm(editing: account),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outline.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(account.type.icon, color: color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(account.name,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(fontWeight: FontWeight.w600)),
                                        if (account.isDefault) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: cs.primary.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text('principal',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: cs.primary,
                                                    fontWeight: FontWeight.w600)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(account.type.label,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: cs.onSurface.withOpacity(0.5))),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'R\$ ${balance.toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: balance >= 0 ? const Color(0xFF43A047) : cs.error,
                                    ),
                                  ),
                                  Text('saldo atual',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: cs.onSurface.withOpacity(0.4))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ────────────────────────────────────────────
// Bottom sheet: formulário de conta
// ────────────────────────────────────────────

class _AccountForm extends StatefulWidget {
  final AccountsRepository repo;
  final AccountEntity? editing;

  const _AccountForm({required this.repo, this.editing});

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  AccountType _type = AccountType.checking;
  Color _color = const Color(0xFF01696F);
  bool _isDefault = false;

  final List<Color> _palette = const [
    Color(0xFF01696F), Color(0xFF43A047), Color(0xFF1E88E5),
    Color(0xFFE53935), Color(0xFFD19900), Color(0xFF7B1FA2),
    Color(0xFFFF7043), Color(0xFF455A64),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      final e = widget.editing!;
      _nameController.text = e.name;
      _balanceController.text = e.initialBalance.toStringAsFixed(2);
      _type = e.type;
      _color = Color(e.colorValue);
      _isDefault = e.isDefault;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    final balance = double.tryParse(
            _balanceController.text.replaceAll(',', '.')) ??
        0.0;
    final entity = AccountEntity(
      id: widget.editing?.id ??
          'acc_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      type: _type,
      initialBalance: balance,
      colorValue: _color.value,
      isDefault: _isDefault,
    );
    await widget.repo.save(entity);
    if (_isDefault) await widget.repo.setDefault(entity.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.editing == null ? 'Nova Conta' : 'Editar Conta',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome da conta',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<AccountType>(
            value: _type,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: AccountType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(t.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(t.label),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _balanceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Saldo inicial (R\$)',
              border: OutlineInputBorder(),
              prefixText: 'R\$ ',
            ),
          ),
          const SizedBox(height: 14),
          Text('Cor', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _palette.map((c) {
              final selected = c.value == _color.value;
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: cs.onSurface, width: 2.5)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            title: const Text('Conta principal'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }
}
