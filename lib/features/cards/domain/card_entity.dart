import 'card_type.dart';

class CardEntity {
  final String id;
  final String name;
  final String bankName;
  final CardType type;
  final int dueDay; // dia de vencimento da fatura
  final double? limit;

  const CardEntity({
    required this.id,
    required this.name,
    required this.bankName,
    required this.type,
    required this.dueDay,
    this.limit,
  });
}
