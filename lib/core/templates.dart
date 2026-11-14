import 'strokes.dart';

enum GearKind { weapon, shield }

/// A ready-made weapon or shield. Bots wield them; unlocked ones become
/// blueprints the player can stamp into the editor and keep drawing on.
class GearTemplate {
  const GearTemplate(this.id, this.name, this.kind, this.build, {this.tall = false, this.starter = false});

  final String id;
  final String name;
  final GearKind kind;
  final Strokes Function() build;

  /// Tall shields cover the whole body; bots pick them against long weapons.
  final bool tall;

  /// Unlocked for the player from the start.
  final bool starter;

  Strokes get strokes => build();
}

// ---------------- weapons (origin at the grip, tip towards -y) ----------------

Strokes _kiem() => [seg(0, 14, 5, -130), seg(-18, -10, 21, -13)];
Strokes _giao() => [
      seg(-2, 18, 9, -182),
      [-2, -178, 10, -214, 22, -180, -2, -178],
    ];
Strokes _bua() => [
      seg(0, 22, 3, -118),
      [-28, -116, 34, -120, 36, -160, -26, -156, -28, -116],
    ];
Strokes _riu() => [
      seg(0, 22, 2, -132),
      [2, -130, 40, -146, 52, -102, 2, -96],
    ];
Strokes _chuyGai() => [
      seg(0, 20, 1, -92),
      circlePts(1, -114, 22, 18),
      seg(1, -136, 1, -152),
      seg(23, -114, 39, -114),
      seg(17, -130, 28, -142),
      seg(17, -98, 28, -86),
    ];
Strokes _daoCong() => [
      [0, 16, 4, -30, 10, -80, 20, -124, 34, -160],
      seg(-12, -6, 15, -10),
    ];
Strokes _dinhBa() => [
      seg(0, 18, 0, -168),
      seg(-22, -160, 22, -160),
      seg(-22, -160, -22, -198),
      seg(0, -168, 0, -208),
      seg(22, -160, 22, -198),
    ];
Strokes _thuocKe() => [
      rectPts(-5, 10, 5, -136),
      seg(5, -20, 1, -20),
      seg(5, -50, 1, -50),
      seg(5, -80, 1, -80),
      seg(5, -110, 1, -110),
    ];
Strokes _comPa() => [
      seg(0, 14, 0, -18),
      circlePts(0, -23, 5, 10),
      seg(-3, -28, -16, -134),
      seg(3, -28, 14, -134),
      closedPoly([10, -130, 17, -130, 13.5, -144]),
    ];
Strokes _eKe() => [
      seg(0, 14, 2, -40),
      closedPoly([2, -40, 2, -136, 48, -40]),
    ];
Strokes _butChi() => [
      rectPts(-6, 8, 6, -104),
      closedPoly([-6, -104, 6, -104, 0, -128]),
      seg(-6, -4, 6, -4),
    ];
Strokes _butLong() => [
      seg(0, 16, 2, -96),
      [2, -96, -8, -114, -6, -136, 2, -156, 10, -136, 12, -114, 2, -96],
    ];
Strokes _keo() => [
      circlePts(-8, 2, 6.5, 12),
      circlePts(9, 4, 6.5, 12),
      seg(-4, -5, 12, -118),
      seg(10, -4, -6, -118),
      circlePts(3, -34, 3, 8),
    ];
Strokes _liem() => [
      seg(0, 18, 0, -64),
      seg(0, -64, -2, -78),
      arcPts(24, -78, 26, 180, 350, 12),
      arcPts(24, -78, 19, 190, 330, 9),
    ];
Strokes _choi() => [
      seg(0, 20, 4, -116),
      seg(-6, -116, 14, -116),
      for (var k = -2; k <= 2; k++) seg(4, -118, 4.0 + 9 * k, -152.0 + 2 * k.abs()),
    ];
Strokes _quat() => [
      seg(0, 14, 0, -40),
      arcPts(0, -40, 58, 225, 315, 10),
      seg(0, -40, -41, -81),
      seg(0, -40, 0, -98),
      seg(0, -40, 41, -81),
    ];
Strokes _maiCheo() => [
      seg(0, 20, 2, -104),
      [-8, -104, 12, -104, 16, -146, 2, -184, -12, -146, -8, -104],
    ];
Strokes _gayBongChay() => [
      [-4, 16, 4, 16, 12, -118, 6, -132, -6, -132, -10, -118, -4, 16],
    ];
Strokes _vot() => [
      seg(0, 16, 0, -60),
      ellipsePts(0, -92, 20, 30, 24),
      seg(-7, -120, -7, -64),
      seg(7, -120, 7, -64),
    ];
Strokes _saoTruc() => [
      rectPts(-3, 12, 3, -148),
      dotPt(0, -60),
      dotPt(0, -90),
      dotPt(0, -120),
    ];
Strokes _duiTrong() => [
      seg(0, 16, 2, -104),
      circlePts(2, -116, 11, 14),
    ];
Strokes _duiTrongTruong() => [
      seg(0, 18, 3, -118),
      circlePts(3, -136, 18, 18),
      seg(-6, -100, 12, -100),
    ];
Strokes _danGhita() => [
      seg(0, 12, 0, -62),
      circlePts(0, -80, 18, 18),
      circlePts(0, -114, 14, 16),
      circlePts(0, -82, 5, 10),
    ];
Strokes _kinhLup() => [
      seg(0, 16, 2, -62),
      circlePts(4, -92, 28, 22),
      arcPts(4, -92, 20, 200, 250, 5),
    ];
Strokes _chuotCap() => [
      [0, 14, 0, -20, 10, -40, -8, -60, 10, -80, -6, -100, 4, -116],
      ellipsePts(4, -136, 13, 19, 18),
      seg(4, -155, 4, -140),
    ];
Strokes _namCham() => [
      seg(0, 16, 0, -72),
      [-20, -150, -20, -92, ...arcPts(0, -92, 20, 180, 0, 10), 20, -92, 20, -150],
      seg(-28, -150, -12, -150),
      seg(12, -150, 28, -150),
    ];
Strokes _loXo() => [
      seg(0, 16, 0, -36),
      [0, -36, 12, -46, -12, -58, 12, -70, -12, -82, 12, -94, -12, -106, 0, -114],
      circlePts(0, -126, 12, 14),
    ];
Strokes _ongNghiem() => [
      seg(0, 16, 0, -44),
      [-10, -44, 10, -44, 10, -130, ...arcPts(0, -130, 10, 0, -180, 8), -10, -130, -10, -44],
      seg(-10, -86, 10, -86),
    ];
Strokes _daiDao() => [
      seg(0, 24, 2, -128),
      [2, -122, 28, -138, 38, -178, 20, -210, 4, -192, 2, -122],
    ];
Strokes _thuong() => [
      seg(-2, 20, 6, -166),
      [6, -166, -2, -174, 8, -208, 18, -172, 6, -166],
      seg(4, -160, -6, -146),
    ];
Strokes _co() => [
      seg(0, 20, 0, -176),
      [0, -176, 46, -160, 0, -144, 0, -176],
    ];
Strokes _xeng() => [
      seg(0, 18, 0, -96),
      [-14, -96, 14, -96, 14, -136, 0, -156, -14, -136, -14, -96],
    ];
Strokes _la() => [
      seg(0, 16, 0, -36),
      [0, -36, 16, -74, 15, -122, 0, -160, -15, -122, -16, -74, 0, -36],
      seg(0, -90, 10, -100),
      seg(0, -110, -10, -120),
    ];
Strokes _coVe() => [
      seg(0, 18, 2, -118),
      rectPts(-5, -118, 9, -132),
      [-6, -132, 10, -132, 14, -160, 2, -184, -10, -160, -6, -132],
    ];
Strokes _chuyPhanTu() => [
      seg(0, 20, 0, -80),
      circlePts(0, -96, 15, 14),
      circlePts(-22, -124, 10, 12),
      circlePts(22, -124, 10, 12),
      seg(-9, -108, -15, -116),
      seg(9, -108, 15, -116),
    ];

// ---------------- shields (origin at the raised shield hand) ----------------

Strokes _khienTron() => [circlePts(10, -4, 42, 22)];
Strokes _khienThap() => [
      [-6, -72, 24, -72, 24, 62, -6, 62, -6, -72],
    ];
Strokes _khienDieu() => [
      [9, -58, 32, -30, 10, 62, -12, -30, 9, -58],
    ];
Strokes _khienNho() => [circlePts(12, -8, 24, 16)];
Strokes _khienGai() => [
      circlePts(8, -4, 34, 20),
      seg(42, -4, 58, -4),
      seg(32, -26, 44, -38),
      seg(32, 18, 44, 30),
    ];
Strokes _khienTay() => [
      closedPoly([-8, -46, 26, -46, 32, -40, 32, 40, 26, 46, -8, 46, -14, 40, -14, -40]),
      seg(-14, -10, 32, -10),
    ];
Strokes _khienSach() => [
      rectPts(-10, -60, 26, 54),
      seg(4, -40, 18, -40),
      seg(4, -32, 16, -32),
    ];
Strokes _khienVo() => [
      rectPts(-14, -50, 34, 46),
      seg(-6, -20, 28, -20),
    ];
Strokes _khienLucGiac() => [
      [for (var i = 0; i <= 6; i++) ..._hexPt(10, -4, 44, i % 6)],
      [for (var i = 0; i <= 6; i++) ..._hexPt(10, -4, 10, i % 6)],
    ];
List<double> _hexPt(double cx, double cy, double r, int i) {
  const c = [1.0, 0.5, -0.5, -1.0, -0.5, 0.5];
  const s = [0.0, 0.8660254, 0.8660254, 0.0, -0.8660254, -0.8660254];
  return [cx + c[i] * r, cy + s[i] * r];
}

Strokes _khienDia() => [circlePts(10, -4, 40, 22), circlePts(10, -4, 8, 10)];
Strokes _khienDiaCau() => [circlePts(10, -4, 40, 22), seg(-30, -4, 50, -4)];
Strokes _khienLa() => [
      [10, -66, 30, -40, 34, 0, 22, 40, 10, 62, -2, 40, -14, 0, -10, -40, 10, -66],
      seg(10, -30, 10, 20),
    ];
Strokes _khienBangMau() => [
      ellipsePts(10, -4, 40, 32, 24),
      circlePts(-6, -16, 5, 10),
      circlePts(14, -22, 5, 10),
      circlePts(30, -8, 5, 10),
    ];
Strokes _khienManHinh() => [
      rectPts(-16, -44, 38, 22),
      seg(11, 22, 11, 34),
      seg(0, 34, 22, 34),
    ];
Strokes _khienTrong() => [circlePts(10, -4, 38, 22), seg(-14, -28, 34, 20)];
Strokes _khienSao() => [starPts(10, -6, 46, 20, 5)];
Strokes _khienTim() => [
      [10, 40, -22, 6, -26, -18, -14, -34, 2, -32, 10, -20, 18, -32, 34, -34, 46, -18, 42, 6, 10, 40],
    ];
Strokes _khienMaiRua() => [
      ellipsePts(10, -4, 34, 48, 24),
      [for (var i = 0; i <= 6; i++) ..._hexPt(10, -4, 12, i % 6)],
    ];
Strokes _khienNapNoi() => [
      arcPts(10, 10, 40, 180, 360, 14),
      seg(-34, 10, 54, 10),
      circlePts(10, -34, 6, 10),
    ];

const List<GearTemplate> weaponTemplates = [
  GearTemplate('kiem', 'Kiếm', GearKind.weapon, _kiem, starter: true),
  GearTemplate('giao', 'Giáo', GearKind.weapon, _giao, starter: true),
  GearTemplate('bua', 'Búa', GearKind.weapon, _bua),
  GearTemplate('riu', 'Rìu', GearKind.weapon, _riu),
  GearTemplate('chuy-gai', 'Chùy gai', GearKind.weapon, _chuyGai),
  GearTemplate('dao-cong', 'Đao cong', GearKind.weapon, _daoCong),
  GearTemplate('dinh-ba', 'Đinh ba', GearKind.weapon, _dinhBa),
  GearTemplate('thuoc-ke', 'Thước kẻ', GearKind.weapon, _thuocKe),
  GearTemplate('com-pa', 'Com-pa', GearKind.weapon, _comPa),
  GearTemplate('e-ke', 'Ê-ke', GearKind.weapon, _eKe),
  GearTemplate('but-chi', 'Bút chì', GearKind.weapon, _butChi),
  GearTemplate('but-long', 'Bút lông', GearKind.weapon, _butLong),
  GearTemplate('keo', 'Kéo', GearKind.weapon, _keo),
  GearTemplate('liem', 'Liềm', GearKind.weapon, _liem),
  GearTemplate('choi', 'Chổi', GearKind.weapon, _choi),
  GearTemplate('quat', 'Quạt', GearKind.weapon, _quat),
  GearTemplate('mai-cheo', 'Mái chèo', GearKind.weapon, _maiCheo),
  GearTemplate('gay-bong-chay', 'Gậy bóng chày', GearKind.weapon, _gayBongChay),
  GearTemplate('vot', 'Vợt cầu lông', GearKind.weapon, _vot),
  GearTemplate('sao-truc', 'Sáo trúc', GearKind.weapon, _saoTruc),
  GearTemplate('dui-trong', 'Dùi trống', GearKind.weapon, _duiTrong),
  GearTemplate('dui-trong-truong', 'Dùi trống trường', GearKind.weapon, _duiTrongTruong),
  GearTemplate('dan-ghita', 'Đàn ghi-ta', GearKind.weapon, _danGhita),
  GearTemplate('kinh-lup', 'Kính lúp', GearKind.weapon, _kinhLup),
  GearTemplate('chuot-cap', 'Chuột cáp', GearKind.weapon, _chuotCap),
  GearTemplate('nam-cham', 'Nam châm', GearKind.weapon, _namCham),
  GearTemplate('lo-xo', 'Lò xo', GearKind.weapon, _loXo),
  GearTemplate('ong-nghiem', 'Ống nghiệm', GearKind.weapon, _ongNghiem),
  GearTemplate('dai-dao', 'Đại đao', GearKind.weapon, _daiDao),
  GearTemplate('thuong', 'Thương', GearKind.weapon, _thuong),
  GearTemplate('co', 'Cờ hiệu', GearKind.weapon, _co),
  GearTemplate('xeng', 'Xẻng', GearKind.weapon, _xeng),
  GearTemplate('la', 'Lá kiếm', GearKind.weapon, _la),
  GearTemplate('co-ve', 'Cọ vẽ khổng lồ', GearKind.weapon, _coVe),
  GearTemplate('chuy-phan-tu', 'Chùy phân tử', GearKind.weapon, _chuyPhanTu),
];

const List<GearTemplate> shieldTemplates = [
  GearTemplate('khien-tron', 'Khiên tròn', GearKind.shield, _khienTron, starter: true),
  GearTemplate('khien-thap', 'Khiên tháp', GearKind.shield, _khienThap, tall: true, starter: true),
  GearTemplate('khien-dieu', 'Khiên diều', GearKind.shield, _khienDieu, tall: true),
  GearTemplate('khien-nho', 'Khiên nhỏ', GearKind.shield, _khienNho),
  GearTemplate('khien-gai', 'Khiên gai', GearKind.shield, _khienGai),
  GearTemplate('khien-tay', 'Khiên cục tẩy', GearKind.shield, _khienTay),
  GearTemplate('khien-sach', 'Khiên quyển sách', GearKind.shield, _khienSach, tall: true),
  GearTemplate('khien-vo', 'Khiên quyển vở', GearKind.shield, _khienVo),
  GearTemplate('khien-luc-giac', 'Khiên lục giác', GearKind.shield, _khienLucGiac),
  GearTemplate('khien-dia', 'Khiên đĩa quang', GearKind.shield, _khienDia),
  GearTemplate('khien-dia-cau', 'Khiên địa cầu', GearKind.shield, _khienDiaCau),
  GearTemplate('khien-la', 'Khiên lá sen', GearKind.shield, _khienLa, tall: true),
  GearTemplate('khien-bang-mau', 'Khiên bảng màu', GearKind.shield, _khienBangMau),
  GearTemplate('khien-man-hinh', 'Khiên màn hình', GearKind.shield, _khienManHinh),
  GearTemplate('khien-trong', 'Khiên mặt trống', GearKind.shield, _khienTrong),
  GearTemplate('khien-sao', 'Khiên ngôi sao', GearKind.shield, _khienSao),
  GearTemplate('khien-tim', 'Khiên trái tim', GearKind.shield, _khienTim),
  GearTemplate('khien-mai-rua', 'Khiên mai rùa', GearKind.shield, _khienMaiRua, tall: true),
  GearTemplate('khien-nap-noi', 'Khiên nắp nồi', GearKind.shield, _khienNapNoi),
];

final Map<String, GearTemplate> templatesById = {
  for (final t in weaponTemplates) t.id: t,
  for (final t in shieldTemplates) t.id: t,
};

GearTemplate templateOf(String id) => templatesById[id] ?? weaponTemplates.first;
