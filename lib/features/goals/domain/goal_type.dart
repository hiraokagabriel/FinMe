/// Tipo da meta financeira.
enum GoalType {
  /// Meta de economia: o usuário quer juntar um valor com algum intuito
  /// (ex: viagem, notebook, reserva de emergência).
  savingsGoal,

  /// Teto de gastos: define um limite máximo de gasto por categoria/mês.
  /// O valor gasto é calculado automaticamente pelas transações.
  spendingCeiling,
}
