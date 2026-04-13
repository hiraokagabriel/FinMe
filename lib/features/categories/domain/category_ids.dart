/// IDs de categorias reservadas pelo sistema.
/// Nunca reutilizar nem deletar esses IDs.
abstract final class CategoryIds {
  /// Categoria gerada automaticamente ao pagar uma fatura de cartão.
  /// Não pode ser alterada pelo usuário em transações do tipo isBillPayment.
  static const String billPayment = 'cat_bill_payment';
}
