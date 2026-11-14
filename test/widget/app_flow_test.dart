import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/app.dart';
import 'package:pen_zz/state/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The lobby hero animates forever, so frames are pumped explicitly instead of settling.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Walks the first-time flow: lobby, drawing a weapon and a shield, pre-match, then the battle.
void main() {
  testWidgets('first-time flow reaches the battle', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final g = GameController();
    await g.load();
    await tester.pumpWidget(PenApp(controller: g));
    await settle(tester);

    expect(find.text('Bút Chiến'), findsOneWidget);
    await tester.tap(find.text('Vẽ đồ đầu tiên'));
    await settle(tester);
    expect(find.text('Vẽ vũ khí'), findsOneWidget);

    final canvas = find.byKey(const ValueKey('draw-canvas'));
    Offset handAt() {
      final box = tester.getRect(canvas);
      final k = box.width / 380;
      return box.topLeft + Offset((110 + 29.6) * k, (356 - 76.5) * k);
    }

    // Draw a sword straight up from the hand.
    await tester.dragFrom(handAt(), const Offset(4, -130));
    await settle(tester);
    expect(g.save.w, isEmpty, reason: 'gear is only saved at the end');
    await tester.tap(find.text('Tiếp: vẽ khiên'));
    await settle(tester);
    expect(find.text('Vẽ khiên'), findsOneWidget);

    // A short shield stroke near the shield hand.
    await tester.dragFrom(handAt() + const Offset(-8, 0), const Offset(0, 70));
    await settle(tester);
    await tester.tap(find.text('Xong, vào màn 1'));
    await settle(tester);
    expect(g.save.w, isNotEmpty);
    expect(find.text('Vào trận'), findsOneWidget);

    await tester.tap(find.text('Vào trận'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cách chơi'), findsOneWidget);
    await tester.tap(find.text('Đã hiểu, vào trận'));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('ĐÁNH'), findsOneWidget);
    expect(find.text('Hiệp 1'), findsOneWidget);
  });

  testWidgets('wardrobe, upgrades and practice open from the lobby', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final g = GameController();
    await g.load();
    g.saveGear(
      [
        [0, 10, 3, -120],
      ],
      [
        [10, -40, 10, 40],
      ],
    );
    g.save.coins = 1000;
    await tester.pumpWidget(PenApp(controller: g));
    await settle(tester);

    await tester.tap(find.text('Tủ đồ'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Mũ'), findsWidgets);
    await tester.tap(find.text('Nón lá'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Mua · 150 xu'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(g.save.coins, 850);
    expect(g.owns('non-la'), isTrue);

    NavScope.read(tester.element(find.text('Tủ đồ').first)).home();
    await settle(tester);
    await tester.tap(find.text('Luyện tập'));
    await settle(tester);
    expect(find.text('Đấu bot luyện tập'), findsOneWidget);
  });
}
