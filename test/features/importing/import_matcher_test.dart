import 'package:finme/features/importing/domain/import_matcher.dart';
import 'package:finme/features/importing/domain/imported_line.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction tx(
  String id, {
  required int cents,
  required DateTime date,
  required String desc,
  String? acc,
  String? card,
  TransactionType type = TransactionType.expense,
  TransactionStatus status = TransactionStatus.paid,
  String? externalId,
  int? instIdx,
  int? instCount,
  String? groupId,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: date,
  description: desc,
  accountId: acc,
  cardId: card,
  status: status,
  externalId: externalId,
  installmentIndex: instIdx,
  installmentCount: instCount,
  installmentGroupId: groupId,
);

ImportedLine line(DateTime date, String desc, int cents, {String? fitid}) =>
    ImportedLine(
      row: 1,
      date: date,
      description: desc,
      amountCents: cents,
      fitid: fitid,
    );

final e1 = tx(
  'e1',
  cents: 10000,
  date: DateTime(2026, 11, 5),
  desc: 'IFOOD*RESTAURANTE X',
  card: 'C',
  externalId: 'F1',
);
final e2 = tx(
  'e2',
  cents: 35000,
  date: DateTime(2026, 11, 10),
  desc: 'Boleto condomínio',
  acc: 'A',
  status: TransactionStatus.planned,
);
final e3 = tx(
  'e3',
  cents: 15000,
  date: DateTime(2026, 12, 8),
  desc: 'LOJA EXEMPLO PARC 03/10',
  card: 'C',
  instIdx: 3,
  instCount: 10,
);
final e4 = tx(
  'e4',
  cents: 5990,
  date: DateTime(2026, 6, 1),
  desc: 'NETFLIX.COM',
  acc: 'A',
);

ImportMatcher base() => ImportMatcher([e1, e2, e3, e4]);

void main() {
  test('fitid igual ao de existente da mesma origem → fitidDuplicate', () {
    final m = base().match(
      line(DateTime(2026, 11, 5), 'IFOOD*RESTAURANTE X', -10000, fitid: 'F1'),
      cardId: 'C',
    );
    expect(m.flags, {ImportFlag.fitidDuplicate});
    expect(m.duplicateOf, e1);
  });

  test('segunda linha com o mesmo fitid não reconsome a existente', () {
    final matcher = base();
    final l = line(
      DateTime(2026, 11, 5),
      'IFOOD*RESTAURANTE X',
      -10000,
      fitid: 'F1',
    );
    matcher.match(l, cardId: 'C');
    final second = matcher.match(l, cardId: 'C');
    expect(second.flags.contains(ImportFlag.fitidDuplicate), isFalse);
    expect(second.duplicateOf, isNull);
  });

  test('mesma compra com 1 dia de diferença → probableDuplicate', () {
    final m = base().match(
      line(DateTime(2026, 11, 6), 'IFOOD *RESTAURANTE X 12/11', -10000),
      cardId: 'C',
    );
    expect(m.flags, {ImportFlag.probableDuplicate});
    expect(m.duplicateOf, e1);
  });

  test('mesma compra com 3 dias de diferença → só sameNameAmount', () {
    final m = base().match(
      line(DateTime(2026, 11, 8), 'IFOOD *RESTAURANTE X 12/11', -10000),
      cardId: 'C',
    );
    expect(m.flags, {ImportFlag.sameNameAmount});
    expect(m.duplicateOf, isNull);
  });

  test('provisionado a 3 dias casa sem flag (descrição não importa)', () {
    final m = base().match(
      line(DateTime(2026, 11, 13), 'PAGTO BOLETO 123', -35000),
      accountId: 'A',
    );
    expect(m.plannedMatch, e2);
    expect(m.flags, isEmpty);
  });

  test('provisionado a 6 dias não casa', () {
    final m = base().match(
      line(DateTime(2026, 11, 16), 'PAGTO BOLETO 123', -35000),
      accountId: 'A',
    );
    expect(m.plannedMatch, isNull);
    expect(m.flags, isEmpty);
  });

  test('provisionado empatado em distância: menor id vence', () {
    final p1 = tx(
      'p1',
      cents: 500,
      date: DateTime(2026, 11, 12),
      desc: 'X',
      acc: 'A',
      status: TransactionStatus.planned,
    );
    final p2 = tx(
      'p2',
      cents: 500,
      date: DateTime(2026, 11, 10),
      desc: 'Y',
      acc: 'A',
      status: TransactionStatus.planned,
    );
    final m = ImportMatcher([
      p2,
      p1,
    ]).match(line(DateTime(2026, 11, 11), 'Z', -500), accountId: 'A');
    expect(m.plannedMatch, p1);
  });

  test('parcela existente com mesmo índice/total → existingInstallment', () {
    final m = base().match(
      line(DateTime(2026, 11, 8), 'LOJA EXEMPLO PARC 03/10', -15000),
      cardId: 'C',
      installment: (index: 3, count: 10),
    );
    expect(m.flags, {ImportFlag.existingInstallment});
    expect(m.duplicateOf, e3);
  });

  test('mesmo nome e valor em outra conta → só sameNameAmount', () {
    final m = base().match(
      line(DateTime(2026, 11, 1), 'NETFLIX.COM', -5990),
      accountId: 'B',
    );
    expect(m.flags, {ImportFlag.sameNameAmount});
    expect(m.duplicateOf, isNull);
    expect(m.plannedMatch, isNull);
  });

  test('pagamento de fatura e recebimento → invoicePaymentLike', () {
    final m1 = base().match(
      line(DateTime(2026, 11, 1), 'PAGTO FATURA CARTAO', -20000),
      accountId: 'A',
    );
    final m2 = base().match(
      line(DateTime(2026, 11, 1), 'PAGAMENTO RECEBIDO', 20000),
      accountId: 'A',
    );
    expect(m1.flags, {ImportFlag.invoicePaymentLike});
    expect(m2.flags, {ImportFlag.invoicePaymentLike});
  });

  test('duas linhas iguais: a 1ª casa, a 2ª não reconsome e-1', () {
    final matcher = base();
    final l = line(DateTime(2026, 11, 6), 'IFOOD *RESTAURANTE X 12/11', -10000);
    final first = matcher.match(l, cardId: 'C');
    final second = matcher.match(l, cardId: 'C');
    expect(first.flags, {ImportFlag.probableDuplicate});
    expect(second.flags.contains(ImportFlag.probableDuplicate), isFalse);
    expect(second.duplicateOf, isNull);
  });

  test('receita de mesmo nome e valor não é probableDuplicate', () {
    final m = base().match(
      line(DateTime(2026, 11, 5), 'IFOOD*RESTAURANTE X', 10000),
      cardId: 'C',
    );
    expect(m.flags.contains(ImportFlag.probableDuplicate), isFalse);
    expect(m.flags, {ImportFlag.sameNameAmount});
  });

  test('parcela existente provisionada → plannedMatch sem flag', () {
    final p = tx(
      'p5',
      cents: 15000,
      date: DateTime(2026, 11, 10),
      desc: 'LOJA EXEMPLO PARC 05/10',
      card: 'C',
      status: TransactionStatus.planned,
      instIdx: 5,
      instCount: 10,
      groupId: 'g1',
    );
    final m = ImportMatcher([p]).match(
      line(DateTime(2026, 11, 10), 'LOJA EXEMPLO PARC 05/10', -15000),
      cardId: 'C',
      installment: (index: 5, count: 10),
    );
    expect(m.plannedMatch, p);
    expect(m.flags, isEmpty);
  });

  test(
    'compra avulsa antes da PARC 05/10 não consome a parcela provisionada',
    () {
      final p = tx(
        'p5',
        cents: 15000,
        date: DateTime(2026, 11, 10),
        desc: 'LOJA EXEMPLO PARC 05/10',
        card: 'C',
        status: TransactionStatus.planned,
        instIdx: 5,
        instCount: 10,
        groupId: 'g1',
      );
      final matcher = ImportMatcher([p]);
      final avulsa = matcher.match(
        line(DateTime(2026, 11, 9), 'OUTRA LOJA', -15000),
        cardId: 'C',
      );
      expect(avulsa.plannedMatch, isNull);
      expect(avulsa.flags, isEmpty);

      final parc = matcher.match(
        line(DateTime(2026, 11, 10), 'LOJA EXEMPLO PARC 05/10', -15000),
        cardId: 'C',
        installment: (index: 5, count: 10),
      );
      expect(parc.plannedMatch, p);
    },
  );

  test('provisionado de série não casa com linha sem parcela', () {
    final serie = tx(
      'g_5',
      cents: 15000,
      date: DateTime(2026, 11, 10),
      desc: 'LOJA EXEMPLO PARC 05/10',
      acc: 'A',
      status: TransactionStatus.planned,
      instIdx: 5,
      instCount: 10,
      groupId: 'g1',
    );
    final semParcela = ImportMatcher([serie]).match(
      line(DateTime(2026, 11, 10), 'PAGTO OUTRA', -15000),
      accountId: 'A',
    );
    expect(semParcela.plannedMatch, isNull);
  });

  test('transferência e pagamento de fatura existentes nunca casam', () {
    final tr = tx(
      't1',
      cents: 10000,
      date: DateTime(2026, 11, 5),
      desc: 'IFOOD*RESTAURANTE X',
      acc: 'A',
      type: TransactionType.transfer,
    );
    final ip = tx(
      't2',
      cents: 10000,
      date: DateTime(2026, 11, 5),
      desc: 'IFOOD*RESTAURANTE X',
      acc: 'A',
      type: TransactionType.invoicePayment,
    );
    final m = ImportMatcher([tr, ip]).match(
      line(DateTime(2026, 11, 5), 'IFOOD*RESTAURANTE X', -10000),
      accountId: 'A',
    );
    expect(m.flags, isEmpty);
    expect(m.duplicateOf, isNull);
  });
}
