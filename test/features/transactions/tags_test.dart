import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/tags.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction tx(String id, {List<String> tags = const [], int cents = 3000}) =>
    Transaction(
      id: id,
      type: TransactionType.expense,
      amountCents: cents,
      date: DateTime(2026, 11, 15),
      description: 'Compra',
      accountId: 'acc',
      tags: tags,
    );

void main() {
  group('normalização', () {
    test('normalizeTag', () {
      expect(normalizeTag('  #viagem '), 'viagem');
      expect(normalizeTag('##a,b'), 'ab');
      expect(normalizeTag('  '), isNull);
      expect(normalizeTag('Viagem   SP'), 'Viagem SP');
    });

    test('tagKey ignora caixa e acento', () {
      expect(tagKey('viagem'), 'VIAGEM');
      expect(tagKey('Viagem'), 'VIAGEM');
      expect(tagKey('VIÁGEM'), 'VIAGEM');
    });

    test('normalizeTags remove duplicatas por chave, mantém 1ª grafia', () {
      expect(normalizeTags(['Viagem', 'viagem', ' VIÁGEM', 'trabalho', '']), [
        'Viagem',
        'trabalho',
      ]);
    });

    test('parseTagInput separa por vírgula e ponto e vírgula', () {
      expect(parseTagInput('viagem, trabalho;  #casa ,'), [
        'viagem',
        'trabalho',
        'casa',
      ]);
    });
  });

  group('Transaction.tags', () {
    test('construtor normaliza e fica imutável', () {
      final t = tx('1', tags: [' #Viagem', 'viagem', 'casa']);
      expect(t.tags, ['Viagem', 'casa']);
      expect(() => t.tags.add('x'), throwsUnsupportedError);
    });

    test('fromMap sem chave, nula, não-lista e com itens inválidos', () {
      Transaction read(Object? tags) =>
          Transaction.fromMap({...tx('1').toMap(), 'tags': tags});
      expect(read(null).tags, isEmpty);
      expect(read('x').tags, isEmpty);
      expect(read(['a', 1, null]).tags, ['a']);
      final semChave = tx('1').toMap()..remove('tags');
      expect(Transaction.fromMap(semChave).tags, isEmpty);
    });

    test('toMap omite tags vazias e round-trip preserva tags', () {
      expect(tx('1').toMap().containsKey('tags'), isFalse);
      final t = tx('1', tags: ['viagem', 'casa']);
      expect(t.toMap()['tags'], ['viagem', 'casa']);
      expect(Transaction.fromMap(t.toMap()), t);
    });

    test('== depende da ordem; mesmas tags dão mesmo hashCode', () {
      final ab = tx('1', tags: ['a', 'b']);
      final ba = tx('1', tags: ['b', 'a']);
      final ab2 = tx('1', tags: ['a', 'b']);
      expect(ab == ba, isFalse);
      expect(ab == ab2, isTrue);
      expect(ab.hashCode, ab2.hashCode);
    });

    test('copyWith mantém tags; copyWith(tags: []) limpa', () {
      final t = tx('1', tags: ['x']);
      expect(t.copyWith(description: 'novo').tags, ['x']);
      expect(t.copyWith(tags: []).tags, isEmpty);
    });
  });

  group('funções em lote', () {
    test('bulkAddTags só altera quem ganha tag nova', () {
      final a = tx('a', tags: ['x']);
      final b = tx('b');
      final out = bulkAddTags([a, b], ['X', 'y']);
      expect(out.map((t) => t.id), ['a', 'b']);
      expect(out[0].tags, ['x', 'y']);
      expect(out[1].tags, ['X', 'y']);
      expect(
        bulkAddTags(
          [
            tx('c', tags: ['x']),
          ],
          ['X'],
        ),
        isEmpty,
      );
    });

    test('bulkRemoveTags remove por chave e só de quem perde', () {
      final a = tx('a', tags: ['x', 'y']);
      final b = tx('b');
      final out = bulkRemoveTags([a, b], ['X']);
      expect(out.map((t) => t.id), ['a']);
      expect(out.single.tags, ['y']);
    });

    test('hasAnyTag com chaves vazias é true', () {
      final t = tx('1', tags: ['Viagem']);
      expect(hasAnyTag(t, {}), isTrue);
      expect(hasAnyTag(t, {'VIAGEM'}), isTrue);
      expect(hasAnyTag(t, {'CASA'}), isFalse);
    });

    test('tagUsage: grafia da 1ª ocorrência, count desc, depois chave asc', () {
      final usage = tagUsage([
        tx('1', tags: ['Viagem']),
        tx('2', tags: ['viagem', 'casa']),
        tx('3', tags: ['Casa']),
      ]);
      expect(usage, [(tag: 'casa', count: 2), (tag: 'Viagem', count: 2)]);
    });
  });

  test('buildInstallments propaga tags para todas as parcelas', () {
    final parcelas = buildInstallments(
      base: tx('base', tags: ['x'], cents: 9000),
      count: 3,
      groupId: 'g',
    );
    expect(parcelas.length, 3);
    for (final p in parcelas) {
      expect(p.tags, ['x']);
    }
  });
}
