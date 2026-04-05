import 'package:flutter/material.dart';

enum AccountType { checking, savings, cash, investment, other }

extension AccountTypeLabel on AccountType {
  String get label {
    switch (this) {
      case AccountType.checking:   return 'Conta Corrente';
      case AccountType.savings:    return 'Poupança';
      case AccountType.cash:       return 'Dinheiro';
      case AccountType.investment: return 'Investimento';
      case AccountType.other:      return 'Outro';
    }
  }

  IconData get icon {
    switch (this) {
      case AccountType.checking:   return Icons.account_balance_outlined;
      case AccountType.savings:    return Icons.savings_outlined;
      case AccountType.cash:       return Icons.payments_outlined;
      case AccountType.investment: return Icons.trending_up_outlined;
      case AccountType.other:      return Icons.account_balance_wallet_outlined;
    }
  }
}

class AccountEntity {
  final String id;
  final String name;
  final AccountType type;
  final double initialBalance;
  final int colorValue;
  final bool isDefault;

  const AccountEntity({
    required this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0.0,
    required this.colorValue,
    this.isDefault = false,
  });
}
