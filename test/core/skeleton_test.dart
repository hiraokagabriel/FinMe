import 'package:finme/app/boot_screen.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SkeletonBox tem o tamanho pedido', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SkeletonBox(width: 100, height: 12)),
      ),
    );
    expect(tester.getSize(find.byType(SkeletonBox)), const Size(100, 12));
  });

  testWidgets('SkeletonList(rows: 4) renderiza 4 blocos e anima sem exceção', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SkeletonList(rows: 4)),
      ),
    );
    expect(find.byType(SkeletonBox), findsNWidgets(4));
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);
  });

  testWidgets('BootScreen monta com SkeletonList', (tester) async {
    await tester.pumpWidget(const BootScreen());
    expect(find.byType(SkeletonList), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('BootScreen sem animações deixa a opacidade em 1', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(const BootScreen());
    final fade = tester.widget<FadeTransition>(
      find.byType(FadeTransition).first,
    );
    expect(fade.opacity.value, 1.0);
  });
}
