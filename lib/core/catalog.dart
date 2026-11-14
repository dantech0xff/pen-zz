import 'ink_fx.dart';

/// Wardrobe slots. `ink` colours the body; `inkW` and `inkS` colour weapon and shield.
enum Slot { hat, cape, glass, ink, inkW, inkS, fx, taunt }

class Item {
  const Item(
    this.id,
    this.name,
    this.price, {
    this.color,
    this.grad,
    this.rainbow = false,
    this.fx = InkFx.none,
    this.say,
  });

  final String id;
  final String name;
  final int price;

  /// Ink colour (0xRRGGBB); special inks also keep a representative colour for effects.
  final int? color;

  /// Gradient from grip to tip for special weapon inks.
  final List<int>? grad;
  final bool rainbow;

  /// Gameplay effect of a special weapon ink.
  final InkFx fx;

  /// Speech bubble of a taunt.
  final String? say;

  bool get special => grad != null || rainbow;
}

/// Weapon or shield ink that follows the body colour.
const String sameInk = 'theo-nguoi';
const Item sameInkItem = Item(sameInk, 'Theo màu người', 0);

const List<Item> hats = [
  Item('khong-mu', 'Không đội', 0),
  Item('non-la', 'Nón lá', 150),
  Item('luoi-trai', 'Mũ lưỡi trai', 150),
  Item('bao-hiem', 'Nón bảo hiểm', 250),
  Item('tai-meo', 'Tai mèo', 250),
  Item('mu-len', 'Mũ len', 300),
  Item('bang-do', 'Băng đô ninja', 350),
  Item('non-coi', 'Nón cối', 450),
  Item('tot-nghiep', 'Mũ tốt nghiệp', 600),
  Item('phu-thuy', 'Mũ phù thủy', 800),
  Item('cao-boi', 'Mũ cao bồi', 900),
  Item('tai-tho', 'Tai thỏ', 1000),
  Item('vong-hoa', 'Vòng hoa', 1200),
  Item('cuop-bien', 'Mũ cướp biển', 1500),
  Item('sung-quy', 'Sừng quỷ', 2200),
  Item('hao-quang', 'Hào quang', 3500),
  Item('vuong-mien', 'Vương miện', 5000),
];

const List<Item> capes = [
  Item('khong-choang', 'Không mặc', 0),
  Item('khan-do', 'Khăn quàng đỏ', 150),
  Item('phi-phong-do', 'Phi phong đỏ', 250),
  Item('khan-ran', 'Khăn rằn', 400),
  Item('ao-choang-den', 'Áo choàng đen', 500),
  Item('balo', 'Ba lô đi học', 600),
  Item('ao-choang-la', 'Áo choàng lá', 800),
  Item('ao-choang-sao', 'Áo choàng sao', 1000),
  Item('ao-choang-bang', 'Áo choàng băng', 1400),
  Item('ao-choang-lua', 'Áo choàng lửa', 1800),
  Item('canh-doi', 'Cánh dơi', 2600),
  Item('phi-phong-vang', 'Phi phong vàng', 3500),
  Item('canh-thien-than', 'Cánh thiên thần', 4500),
];

const List<Item> glasses = [
  Item('khong-kinh', 'Không đeo', 0),
  Item('kinh-can', 'Kính cận', 100),
  Item('kinh-ram', 'Kính râm', 200),
  Item('kinh-tim', 'Kính trái tim', 250),
  Item('kinh-boi', 'Kính bơi', 300),
  Item('kinh-tron-vang', 'Kính tròn gọng vàng', 500),
  Item('bit-mat', 'Bịt mắt cướp biển', 700),
  Item('kinh-3d', 'Kính 3D', 900),
  Item('kinh-sao', 'Kính ngôi sao', 1200),
  Item('mat-na', 'Mặt nạ dạ hội', 1600),
  Item('kinh-pixel', 'Kính pixel', 2500),
];

const List<Item> bodyInks = [
  Item('muc-xanh', 'Mực xanh', 0, color: 0x1D3AA8),
  Item('muc-den', 'Mực đen', 100, color: 0x252A37),
  Item('muc-xam', 'Mực xám', 150, color: 0x5F6673),
  Item('muc-tim', 'Mực tím', 150, color: 0x6A3DB8),
  Item('muc-luc', 'Mực lục', 150, color: 0x1B8452),
  Item('muc-ngoc', 'Mực ngọc', 200, color: 0x0B8189),
  Item('muc-cam', 'Mực cam', 200, color: 0xD9700F),
  Item('muc-hong', 'Mực hồng', 300, color: 0xD94F8A),
  Item('muc-nau', 'Mực nâu', 300, color: 0x7A4A2A),
  Item('muc-troi', 'Mực xanh trời', 400, color: 0x2D8FD5),
  Item('muc-man', 'Mực mận', 600, color: 0x8E2457),
  Item('nhu-vang', 'Nhũ vàng', 1500, color: 0xB58500),
  Item('muc-bac', 'Nhũ bạc', 2500, color: 0x7B8794),
];

/// Special inks for weapons only. All but the rainbow carry a gameplay effect.
const List<Item> weaponInks = [
  Item('muc-da', 'Mực đá', 1500, color: 0x6B6E78, grad: [0x3E3F45, 0x7D7F88, 0xB9BCC4], fx: InkFx.stone),
  Item('muc-gio', 'Mực gió', 1800, color: 0x2BB59A, grad: [0x0B8F7A, 0x5FD3B9, 0xC8FFF0], fx: InkFx.wind),
  Item('muc-bang', 'Mực băng', 2500, color: 0x3AA8E8, grad: [0x1565C0, 0x4FC3F7, 0xD9F4FF], fx: InkFx.ice),
  Item('muc-lua', 'Mực lửa', 2500, color: 0xE8541C, grad: [0xB3121F, 0xF2561D, 0xFFB400], fx: InkFx.fire),
  Item('muc-set', 'Mực sét', 3000, color: 0x4A7FF0, grad: [0x5B2BE0, 0x3FB8F0, 0xFFF176], fx: InkFx.shock),
  Item('muc-hut', 'Mực hút', 3500, color: 0x9B1D4F, grad: [0x4A0E2E, 0x9B1D4F, 0xE04F6F], fx: InkFx.leech),
  Item('muc-cau-vong', 'Mực cầu vồng', 6000, color: 0x7A4BD6, rainbow: true),
];

const List<Item> hitFxs = [
  Item('muc', 'Nét mực', 0),
  Item('lua', 'Lửa', 250),
  Item('set', 'Sấm sét', 300),
  Item('bong-bong', 'Bong bóng', 300),
  Item('cau-vong', 'Cầu vồng', 400),
  Item('hoa-dao', 'Hoa đào', 400),
  Item('trai-tim', 'Trái tim', 500),
  Item('ngoi-sao', 'Ngôi sao', 600),
  Item('tuyet', 'Bông tuyết', 700),
  Item('giay-vun', 'Giấy vụn', 800),
  Item('phao-hoa', 'Pháo hoa', 1000),
  Item('la-phong', 'Lá phong', 1100),
  Item('not-nhac', 'Nốt nhạc', 1300),
  Item('muc-tau', 'Mực tàu bắn tung', 1500),
  Item('dien-tu', 'Điểm ảnh', 1800),
  Item('chu-bop', 'Chữ tượng thanh', 2500),
];

const List<Item> taunts = [
  Item('vay-tay', 'Vẫy tay', 0, say: 'Hehe!'),
  Item('cui-chao', 'Cúi chào', 150, say: 'Cảm ơn đã chơi!'),
  Item('nhay', 'Nhảy múa', 200, say: 'Dễ ợt!'),
  Item('gong', 'Gồng cơ', 250, say: 'Ai nữa?'),
  Item('vo-tay', 'Vỗ tay', 300, say: 'Hay lắm!'),
  Item('xoay', 'Xoay bút', 400, say: 'Còn non lắm!'),
  Item('tra-da', 'Trà đá', 500, say: 'Làm ly trà đá đã.'),
  Item('chup-anh', 'Chụp ảnh', 800, say: 'Chụp tấm kỷ niệm!'),
  Item('ngoi-thien', 'Ngồi thiền', 1200, say: 'Tĩnh tâm…'),
  Item('ngu-gat', 'Ngủ gật', 1800, say: 'Zzz… buồn ngủ quá.'),
];

const Map<Slot, String> defaultEquip = {
  Slot.hat: 'khong-mu',
  Slot.cape: 'khong-choang',
  Slot.glass: 'khong-kinh',
  Slot.ink: 'muc-xanh',
  Slot.inkW: sameInk,
  Slot.inkS: sameInk,
  Slot.fx: 'muc',
  Slot.taunt: 'vay-tay',
};

final Map<String, Item> itemIndex = {
  for (final list in [hats, capes, glasses, bodyInks, weaponInks, hitFxs, taunts])
    for (final it in list) it.id: it,
};

Item? itemById(String id) => id == sameInk ? sameInkItem : itemIndex[id];

/// Items a slot can hold, in shop order.
List<Item> itemsFor(Slot slot) => switch (slot) {
  Slot.hat => hats,
  Slot.cape => capes,
  Slot.glass => glasses,
  Slot.ink => bodyInks,
  Slot.inkW => [sameInkItem, ...bodyInks, ...weaponInks],
  Slot.inkS => [sameInkItem, ...bodyInks],
  Slot.fx => hitFxs,
  Slot.taunt => taunts,
};

bool fitsSlot(Slot slot, String id) => itemsFor(slot).any((it) => it.id == id);

/// Body colour of an ink id, falling back to the default blue.
int inkColor(String id) => itemIndex[id]?.color ?? 0x1D3AA8;

/// Ink effect carried by a weapon-ink id.
InkFx inkFxOf(String inkW) => itemIndex[inkW]?.fx ?? InkFx.none;

String tauntSay(String id) => itemIndex[id]?.say ?? 'Hehe!';
