import 'package:finme/features/transactions/presentation/transaction_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const order = ['a', 'b', 'c', 'd', 'e'];

  test('toggle inverte o id e define a âncora', () {
    final on = TransactionSelection.empty.toggle('b');
    expect(on.ids, {'b'});
    expect(on.anchorId, 'b');

    final off = on.toggle('b');
    expect(off.ids, isEmpty);
    expect(off.anchorId, 'b');
  });

  test('extendTo marca o intervalo a partir da âncora', () {
    final s = TransactionSelection.empty.toggle('b').extendTo('d', order);
    expect(s.ids, {'b', 'c', 'd'});
    expect(s.anchorId, 'b');

    final back = s.extendTo('a', order);
    expect(back.ids, {'a', 'b', 'c', 'd'});
    expect(back.anchorId, 'b');
  });

  test('extendTo sem âncora válida vira toggle', () {
    final noAnchor = TransactionSelection.empty.extendTo('c', order);
    expect(noAnchor.ids, {'c'});
    expect(noAnchor.anchorId, 'c');

    final outside = const TransactionSelection(
      anchorId: 'z',
    ).extendTo('c', order);
    expect(outside.ids, {'c'});
    expect(outside.anchorId, 'c');
  });

  test('selectAll marca a ordem inteira e mantém a âncora', () {
    final s = TransactionSelection.empty.toggle('b').selectAll(order);
    expect(s.ids, order.toSet());
    expect(s.anchorId, 'b');
  });

  test('selectedIn segue a ordem de order', () {
    const s = TransactionSelection(ids: {'a', 'e'});
    expect(s.selectedIn(['e', 'a', 'x']), ['e', 'a']);
  });

  test('allState: vazio, nenhum, parcial, todos', () {
    expect(const TransactionSelection().allState([]), isFalse);
    expect(const TransactionSelection().allState(order), isFalse);
    expect(const TransactionSelection(ids: {'a', 'b'}).allState(order), isNull);
    expect(TransactionSelection(ids: order.toSet()).allState(order), isTrue);
    expect(
      const TransactionSelection(ids: {...order, 'x'}).allState(order),
      isTrue,
    );
  });
}
