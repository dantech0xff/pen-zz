import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/catalog.dart';
import 'package:pen_zz/core/gear.dart';
import 'package:pen_zz/core/save_data.dart';

void main() {
  test('save survives a JSON round trip', () {
    final s = SaveData()
      ..coins = 1234
      ..xp = 55
      ..lvl = 7
      ..free = 2
      ..pts = Points(pow: 3, def: 4, spd: 5)
      ..stage = 17
      ..w = [
        [0, 10, 3.25, -120],
      ]
      ..s = [
        [10, -40, 30, 20, 10, 40],
      ];
    s.stars[0] = 7;
    s.stars[16] = 3;
    s.owned.add('non-la');
    s.eq[Slot.hat] = 'non-la';
    s.blueprints.add('com-pa');
    final back = SaveData.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect(back.coins, 1234);
    expect(back.lvl, 7);
    expect(back.pts.def, 4);
    expect(back.stage, 17);
    expect(back.stars[0], 7);
    expect(back.totalStars, 3 + 2);
    expect(back.eq[Slot.hat], 'non-la');
    expect(back.blueprints, contains('com-pa'));
    expect(back.w.first[2], closeTo(3.3, 1e-9));
  });

  test('broken saves fall back to safe defaults', () {
    final s = SaveData.fromJson({
      'coins': -5,
      'lvl': 'x',
      'eq': {'hat': 'vuong-mien'},
      'w': [
        [1, 2, 99999, 4],
      ],
      'stars': [9, 2],
    });
    expect(s.coins, 0);
    expect(s.lvl, 1);
    expect(s.eq[Slot.hat], 'khong-mu', reason: 'cannot equip an item that is not owned');
    expect(s.w, isEmpty);
    expect(s.stars[0], 7);
    expect(SaveData.fromJson(null).coins, 0);
  });
}
