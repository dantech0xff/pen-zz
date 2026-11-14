import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/app.dart';
import 'package:pen_zz/core/store_catalog.dart';
import 'package:pen_zz/state/game_controller.dart';
import 'package:pen_zz/state/monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_monetization.dart';

Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Starts the app with gear drawn, the tutorial done, and fake ads and store.
Future<(GameController, Monetization, FakeAds)> boot(WidgetTester tester, {Size size = const Size(360, 640)}) async {
  tester.view.physicalSize = size * 3;
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
  g.markTutorialDone();
  final store = FakeStore(), ads = FakeAds();
  final m = Monetization(game: g, ads: ads, store: store, clock: () => store.now);
  await tester.pumpWidget(PenApp(controller: g, monetization: m));
  await settle(tester);
  return (g, m, ads);
}

/// The buy button inside the store card titled [title].
Finder buyButtonOf(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
  matching: find.text('25.000 ₫'),
);

void main() {
  testWidgets('the lobby fits a small phone with the tallest banner', (tester) async {
    await boot(tester);
    expect(find.byKey(const Key('test-banner')), findsOneWidget);
    expect(find.text('Đánh màn 1'), findsOneWidget);
    expect(find.text('Tủ đồ'), findsOneWidget);
  });

  testWidgets('settings fit a small phone with restore and privacy options', (tester) async {
    final (_, _, ads) = await boot(tester);
    ads.privacy = true;
    await tester.tap(find.byTooltip('Cài đặt'));
    await settle(tester);
    expect(find.text('Khôi phục giao dịch'), findsOneWidget);
    expect(find.text('Tuỳ chọn quyền riêng tư cho quảng cáo'), findsOneWidget);
    await tester.ensureVisible(find.text('Xoá tiến trình'));
    await settle(tester);
    await tester.tap(find.text('Xoá tiến trình'));
    await settle(tester);
    expect(find.text('Xoá toàn bộ tiến trình?'), findsOneWidget);
  });

  testWidgets('buying "remove ads" takes the banner away', (tester) async {
    final (_, m, _) = await boot(tester);
    await m.buy(productById('pz_remove_ads')!);
    await settle(tester);
    expect(find.byKey(const Key('test-banner')), findsNothing);
  });

  testWidgets('the store gives free coins and sells coin packs', (tester) async {
    final (g, _, _) = await boot(tester);
    // On a small phone with a banner the lobby scrolls; bring the wardrobe button into view.
    await tester.ensureVisible(find.text('Tủ đồ'));
    await settle(tester);
    await tester.tap(find.text('Tủ đồ'));
    await settle(tester);
    await tester.tap(find.text('Cửa hàng'));
    await settle(tester);
    expect(find.text('Xu miễn phí'), findsOneWidget);
    expect(find.text('25.000 ₫'), findsWidgets);

    await tester.tap(find.text('Xem'));
    await settle(tester);
    expect(g.save.coins, AdRules.freeCoins(0));

    await tester.scrollUntilVisible(find.text('Túi xu'), 200, scrollable: find.byType(Scrollable).last);
    await settle(tester);
    await tester.tap(buyButtonOf('Túi xu'));
    await settle(tester);
    expect(g.save.coins, AdRules.freeCoins(0) + 1000);
    expect(find.text('Đã nhận 1.000 xu. Cảm ơn bạn!'), findsOneWidget);
  });

  testWidgets('an exclusive item in the wardrobe leads to its outfit in the store', (tester) async {
    await boot(tester, size: const Size(412, 860));
    await tester.tap(find.text('Tủ đồ'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Vương miện ngọc'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Vương miện ngọc'));
    await settle(tester);
    expect(find.text('Độc quyền'), findsWidgets);
    await tester.tap(find.text('Có trong Bộ Hoàng gia'));
    await settle(tester);
    expect(find.text('Bộ trang phục độc quyền'), findsOneWidget);
    expect(find.text('Bộ Hoàng gia'), findsOneWidget);
  });

  testWidgets('after a match a rewarded ad doubles the reward', (tester) async {
    final (g, _, _) = await boot(tester, size: const Size(412, 860));
    await tester.tap(find.text('Đánh màn 1'));
    await settle(tester);
    await tester.tap(find.text('Vào trận'));
    // The player stands still, so the match ends in the bot's favour (or by the shrinking floor).
    for (var i = 0; i < 4000 && find.text('Thua rồi').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Thua rồi'), findsOneWidget);
    final coins = g.save.coins;
    await tester.tap(find.text('Xem quảng cáo: nhân đôi xu và kinh nghiệm'));
    await settle(tester);
    expect(g.save.coins, greaterThan(coins));
    expect(find.textContaining('Đã nhân đôi'), findsOneWidget);
    expect(find.text('Xem quảng cáo: nhân đôi xu và kinh nghiệm'), findsNothing);
  });
}
