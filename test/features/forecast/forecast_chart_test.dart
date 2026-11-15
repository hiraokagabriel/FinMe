import 'package:finme/features/forecast/domain/forecast.dart';
import 'package:finme/features/forecast/presentation/forecast_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<DailyBalance> series(List<int> balances) => [
    for (var i = 0; i < balances.length; i++)
      DailyBalance(
        date: DateTime(2026, 1, 1).add(Duration(days: i)),
        balanceCents: balances[i],
      ),
  ];

  test('sem amostragem até 400 pontos', () {
    final daily = series(List.filled(400, 100));
    expect(sampleIndices(daily), [for (var i = 0; i < 400; i++) i]);
  });

  test('acima de 400 pontos amostra e mantém o dia de menor saldo', () {
    final balances = List<int>.filled(730, 100);
    balances[501] = -900;
    final idx = sampleIndices(series(balances));
    expect(idx.length, lessThanOrEqualTo(401));
    expect(idx.first, 0);
    expect(idx, contains(501));
    expect(idx, orderedEquals([...idx]..sort()));
  });
}
