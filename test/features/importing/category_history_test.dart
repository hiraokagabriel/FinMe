import 'package:finme/features/importing/domain/category_history.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

int _seq = 0;

Transaction _tx(
  String description,
  String? categoryId, {
  DateTime? date,
  TransactionType type = TransactionType.expense,
  String? importedDescription,
}) {
  _seq++;
  return Transaction(
    id: 't$_seq',
    type: type,
    amountCents: 1000,
    date: date ?? DateTime(2026, 11, 1),
    description: description,
    categoryId: categoryId,
    importedDescription: importedDescription,
  );
}

/// Três letras de AAA em diante (base 26), para gerar chaves distintas.
String _letters(int i) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  return alphabet[i ~/ 676 % 26] + alphabet[i ~/ 26 % 26] + alphabet[i % 26];
}

void main() {
  test('categoria mais frequente vence com share', () {
    final h = CategoryHistory.build([
      _tx('PADARIA PAO BOM 01', 'cat_alim'),
      _tx('PADARIA PAO BOM 02', 'cat_alim'),
      _tx('PADARIA PAO BOM 03', 'cat_alim'),
      _tx('PADARIA PAO BOM 04', 'cat_merc'),
    ]);
    expect(h.exact('PADARIA PAO BOM'), (categoryId: 'cat_alim', share: 0.75));
  });

  test('empate 1x1 vence a categoria da transação mais recente', () {
    final h = CategoryHistory.build([
      _tx('PADARIA PAO BOM', 'cat_alim', date: DateTime(2026, 11, 1)),
      _tx('PADARIA PAO BOM', 'cat_merc', date: DateTime(2026, 11, 10)),
    ]);
    expect(h.exact('PADARIA PAO BOM'), (categoryId: 'cat_merc', share: 0.5));
  });

  test('transfer, pagamento de fatura e sem categoria são ignorados', () {
    final h = CategoryHistory.build([
      _tx('PADARIA PAO BOM', 'cat_x', type: TransactionType.transfer),
      _tx('PADARIA PAO BOM', 'cat_x', type: TransactionType.invoicePayment),
      _tx('PADARIA PAO BOM', null),
    ]);
    expect(h.exact('PADARIA PAO BOM'), isNull);
  });

  test('descrição só com dígitos não cria chave', () {
    final h = CategoryHistory.build([_tx('12/11 0123', 'cat_x')]);
    expect(h.exact(''), isNull);
    expect(h.similar('123'), isNull);
  });

  test('importedDescription tem preferência sobre description', () {
    final h = CategoryHistory.build([
      _tx(
        'PADARIA PAO BOM SHOP',
        'cat_alim',
        importedDescription: 'PADARIA PAO BOM 01',
      ),
    ]);
    expect(h.exact('PADARIA PAO BOM'), (categoryId: 'cat_alim', share: 1.0));
    expect(h.exact('PADARIA PAO BOM SHOP'), isNull);
  });

  test('similar acha chave parecida com score = Jaccard', () {
    final h = CategoryHistory.build([
      _tx('PADARIA PAO BOM 01', 'cat_alim'),
      _tx('PADARIA PAO BOM 02', 'cat_alim'),
      _tx('PADARIA PAO BOM 03', 'cat_merc'),
    ]);
    expect(h.similar('PADARIA PAO BOM FILIAL'), (
      categoryId: 'cat_alim',
      score: 0.75,
    ));
    expect(h.similar('OUTRA COISA'), isNull);
    expect(h.similar('PADARIA PAO BOM FILIAL', threshold: 0.8), isNull);
  });

  test('token comum a mais de 500 chaves é ignorado nos candidatos', () {
    final h = CategoryHistory.build([
      for (var i = 0; i <= 500; i++) _tx('LOJA ${_letters(i)}', 'cat_x'),
    ]);
    expect(h.similar('LOJA ZZZ'), isNull);
    expect(h.similar('LOJA AAA'), (categoryId: 'cat_x', score: 1.0));
  });

  test('CategoryHistory.empty não acha nada', () {
    expect(CategoryHistory.empty.exact('X'), isNull);
    expect(CategoryHistory.empty.similar('PADARIA PAO BOM'), isNull);
  });
}
