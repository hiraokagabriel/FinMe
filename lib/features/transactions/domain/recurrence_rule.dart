/// Regra de recorrência de uma transação.
enum RecurrenceRule {
  none,
  daily,
  weekly,
  monthly,
  yearly;

  String get label => switch (this) {
        none    => 'Não repetir',
        daily   => 'Todo dia',
        weekly  => 'Toda semana',
        monthly => 'Todo mês',
        yearly  => 'Todo ano',
      };

  /// Próxima data após [from] respeitando a regra.
  DateTime next(DateTime from) => switch (this) {
        none    => from,
        daily   => from.add(const Duration(days: 1)),
        weekly  => from.add(const Duration(days: 7)),
        monthly => DateTime(from.year, from.month + 1, from.day),
        yearly  => DateTime(from.year + 1, from.month, from.day),
      };
}
