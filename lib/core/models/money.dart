class Money {
  final double amount;
  final String currency;

  const Money(this.amount, {this.currency = 'BRL'});

  Money operator +(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot add money with different currencies');
    }
    return Money(amount + other.amount, currency: currency);
  }

  Money operator - (Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot subtract money with different currencies');
    }
    return Money(amount - other.amount, currency: currency);
  }

  @override
  String toString() => '$currency ${amount.toStringAsFixed(2)}';
}
