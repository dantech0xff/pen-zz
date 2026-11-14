import 'arenas.dart';
import 'battle/battle.dart';
import 'mathx.dart';

/// A notebook (chapter) of ten levels on its own arena, with a mini-boss at level 5
/// and a boss at level 10. Beating them unlocks their shield and weapon blueprints.
class ChapterDef {
  const ChapterDef({
    required this.name,
    required this.arenaId,
    required this.miniBoss,
    required this.boss,
    required this.miniShield,
    required this.bossWeapon,
    required this.weapons,
    required this.shields,
    required this.bots,
    required this.color,
    this.botPower = 1,
  });

  final String name;
  final String arenaId;
  final String miniBoss;
  final String boss;
  final String miniShield;
  final String bossWeapon;
  final List<String> weapons;
  final List<String> shields;
  final List<String> bots;
  final int color;

  /// Scales bot upgrade points so the difficulty climbs evenly despite harsher arena rules.
  final double botPower;

  ArenaDef get arena => arenaOf(arenaId);
}

const List<ChapterDef> chapters = [
  ChapterDef(
    name: 'Vở Toán',
    arenaId: 'o-li',
    miniBoss: 'Trùm Phấn Trắng',
    boss: 'Trùm Bảng Đen',
    miniShield: 'khien-tay',
    bossWeapon: 'com-pa',
    weapons: ['kiem', 'bua', 'thuoc-ke', 'e-ke'],
    shields: ['khien-tron', 'khien-nho', 'khien-thap', 'khien-tay'],
    bots: ['Thước Kẻ', 'Ê-ke', 'Máy Tính', 'Bút Chì Gãy', 'Cục Tẩy', 'Thước Đo Độ', 'Bảng Cửu Chương'],
    color: 0x1D3AA8,
  ),
  ChapterDef(
    name: 'Vở Văn',
    arenaId: 'dong-ke',
    miniBoss: 'Trùm Sổ Đầu Bài',
    boss: 'Trùm Bút Mực Tím',
    miniShield: 'khien-sach',
    bossWeapon: 'but-long',
    weapons: ['kiem', 'but-chi', 'giao', 'dao-cong'],
    shields: ['khien-tron', 'khien-dieu', 'khien-nho', 'khien-sach'],
    bots: ['Bút Mực', 'Lọ Mực', 'Giấy Nháp', 'Dấu Phẩy', 'Dấu Chấm Than', 'Thơ Lục Bát', 'Bút Bi'],
    color: 0x6A3DB8,
  ),
  ChapterDef(
    name: 'Vở Tiếng Anh',
    arenaId: 'chinh-ta',
    miniBoss: 'Trùm Từ Mới',
    boss: 'Trùm Ngữ Pháp',
    miniShield: 'khien-vo',
    bossWeapon: 'co',
    weapons: ['giao', 'thuong', 'kiem', 'riu'],
    shields: ['khien-tron', 'khien-thap', 'khien-gai', 'khien-vo'],
    bots: ['Từ Điển', 'Chữ A', 'Chữ Z', 'Phát Âm', 'Bút Dạ Quang', 'Thẻ Từ Vựng', 'Câu Bị Động'],
    color: 0x0B8189,
    botPower: 1.15,
  ),
  ChapterDef(
    name: 'Vở Lý',
    arenaId: 'quat-tran',
    miniBoss: 'Trùm Đĩa Quang',
    boss: 'Trùm Nam Châm',
    miniShield: 'khien-dia',
    bossWeapon: 'nam-cham',
    weapons: ['bua', 'lo-xo', 'chuy-gai', 'dui-trong'],
    shields: ['khien-tron', 'khien-gai', 'khien-nap-noi', 'khien-dia'],
    bots: ['Lò Xo', 'Ròng Rọc', 'Con Lắc', 'Bóng Đèn', 'Pin Con Thỏ', 'Đòn Bẩy', 'Lăng Kính'],
    color: 0x2F5D8A,
    botPower: 1.0,
  ),
  ChapterDef(
    name: 'Vở Hóa',
    arenaId: 'thi-nghiem',
    miniBoss: 'Trùm Vòng Benzen',
    boss: 'Trùm Phân Tử',
    miniShield: 'khien-luc-giac',
    bossWeapon: 'chuy-phan-tu',
    weapons: ['ong-nghiem', 'chuy-gai', 'kiem', 'dao-cong'],
    shields: ['khien-tron', 'khien-nho', 'khien-dieu', 'khien-luc-giac'],
    bots: ['Ống Nghiệm', 'Bình Cầu', 'Đèn Cồn', 'Giấy Quỳ', 'Kẹp Gỗ', 'Cái Phễu', 'Bảng Tuần Hoàn'],
    color: 0x1B8452,
    botPower: 0.8,
  ),
  ChapterDef(
    name: 'Vở Sử',
    arenaId: 'thanh-co',
    miniBoss: 'Trùm Rùa Vàng',
    boss: 'Trùm Đại Đao',
    miniShield: 'khien-mai-rua',
    bossWeapon: 'dai-dao',
    weapons: ['kiem', 'giao', 'riu', 'dinh-ba'],
    shields: ['khien-thap', 'khien-dieu', 'khien-gai', 'khien-mai-rua'],
    bots: ['Trống Đồng', 'Cuộn Chiếu Chỉ', 'Ấn Kiếm', 'Thành Đá', 'Cung Tên', 'Mũ Trụ', 'Cờ Lau'],
    color: 0x7A4A2A,
    botPower: 1.05,
  ),
  ChapterDef(
    name: 'Vở Địa',
    arenaId: 'ban-do',
    miniBoss: 'Trùm Địa Cầu',
    boss: 'Trùm Mái Chèo',
    miniShield: 'khien-dia-cau',
    bossWeapon: 'mai-cheo',
    weapons: ['xeng', 'co', 'giao', 'thuong'],
    shields: ['khien-tron', 'khien-thap', 'khien-la', 'khien-dia-cau'],
    bots: ['La Bàn', 'Bản Đồ', 'Kinh Tuyến', 'Vĩ Tuyến', 'Núi Lửa', 'Gió Mùa', 'Quả Địa Cầu'],
    color: 0x5C6B2E,
    botPower: 0.8,
  ),
  ChapterDef(
    name: 'Vở Sinh',
    arenaId: 'vuon-truong',
    miniBoss: 'Trùm Lá Sen',
    boss: 'Trùm Lá Kiếm',
    miniShield: 'khien-la',
    bossWeapon: 'la',
    weapons: ['liem', 'kinh-lup', 'choi', 'dao-cong'],
    shields: ['khien-dieu', 'khien-tron', 'khien-tim', 'khien-la'],
    bots: ['Kính Lúp', 'Hạt Đậu', 'Con Sâu', 'Tế Bào', 'Bông Hoa', 'Ếch Con', 'Cây Xương Rồng'],
    color: 0x2F7A2F,
    botPower: 1.1,
  ),
  ChapterDef(
    name: 'Vở Mỹ thuật',
    arenaId: 'gia-ve',
    miniBoss: 'Trùm Bảng Màu',
    boss: 'Trùm Cọ Khổng Lồ',
    miniShield: 'khien-bang-mau',
    bossWeapon: 'co-ve',
    weapons: ['but-chi', 'but-long', 'keo', 'quat'],
    shields: ['khien-tim', 'khien-tron', 'khien-nho', 'khien-bang-mau'],
    bots: ['Bút Sáp', 'Màu Nước', 'Giá Vẽ', 'Đất Nặn', 'Khung Tranh', 'Hộp Màu', 'Tẩy Chì'],
    color: 0xC2185B,
    botPower: 0.85,
  ),
  ChapterDef(
    name: 'Vở Thể dục',
    arenaId: 'san-truong',
    miniBoss: 'Trùm Huy Chương',
    boss: 'Trùm Vợt Cầu',
    miniShield: 'khien-sao',
    bossWeapon: 'vot',
    weapons: ['gay-bong-chay', 'choi', 'mai-cheo', 'thuong'],
    shields: ['khien-tron', 'khien-nap-noi', 'khien-thap', 'khien-sao'],
    bots: ['Quả Bóng', 'Cái Còi', 'Dây Nhảy', 'Quả Cầu', 'Đồng Hồ Bấm Giờ', 'Xà Đơn', 'Cột Cờ'],
    color: 0x2E6B3A,
    botPower: 1.1,
  ),
  ChapterDef(
    name: 'Vở Tin học',
    arenaId: 'man-hinh',
    miniBoss: 'Trùm Màn Hình Xanh',
    boss: 'Trùm Chuột Cáp',
    miniShield: 'khien-man-hinh',
    bossWeapon: 'chuot-cap',
    weapons: ['keo', 'thuoc-ke', 'dao-cong', 'lo-xo'],
    shields: ['khien-luc-giac', 'khien-dia', 'khien-nho', 'khien-man-hinh'],
    bots: ['Bàn Phím', 'Ổ Cứng', 'Con Trỏ', 'Wifi Yếu', 'Pin Laptop', 'Dấu Chấm Phẩy', 'Lỗi 404'],
    color: 0x2D4FB8,
    botPower: 0.9,
  ),
  ChapterDef(
    name: 'Vở Âm nhạc',
    arenaId: 'khuong-nhac',
    miniBoss: 'Trùm Mặt Trống',
    boss: 'Trùm Trống Trường',
    miniShield: 'khien-trong',
    bossWeapon: 'dui-trong-truong',
    weapons: ['sao-truc', 'dui-trong', 'dan-ghita', 'quat'],
    shields: ['khien-dia', 'khien-tron', 'khien-sao', 'khien-trong'],
    bots: ['Sáo Trúc', 'Trống Con', 'Đàn Bầu', 'Nốt Đô', 'Kèn Tây', 'Song Loan', 'Đàn Tranh'],
    color: 0x6A3DB8,
    botPower: 0.95,
  ),
];

const int levelsPerChapter = 10;
const int levelCount = 120;

enum GoalKind { hits, blocks, parries, headHits, lowDamage, fastWin, noShield }

/// Third-star challenge of a level.
class StarGoal {
  const StarGoal(this.kind, this.value);

  final GoalKind kind;
  final int value;

  String get text => switch (kind) {
    GoalKind.hits => 'Trúng ít nhất $value đòn',
    GoalKind.blocks => 'Chặn ít nhất $value đòn',
    GoalKind.parries => 'Đỡ chuẩn ít nhất $value lần',
    GoalKind.headHits => 'Trúng đầu ít nhất $value lần',
    GoalKind.lowDamage => 'Kết thúc trận với % dưới $value%',
    GoalKind.fastWin => 'Thắng trong $value giây',
    GoalKind.noShield => 'Thắng mà không giơ khiên',
  };

  bool met(MatchStats st) => switch (kind) {
    GoalKind.hits => st.hits >= value,
    GoalKind.blocks => st.blocks >= value,
    GoalKind.parries => st.parries >= value,
    GoalKind.headHits => st.headHits >= value,
    GoalKind.lowDamage => st.playerDmg < value,
    GoalKind.fastWin => st.fightTime < value,
    GoalKind.noShield => !st.usedShield,
  };
}

StarGoal goalFor(int stage) {
  final c = (stage - 1) ~/ 10, i = (stage - 1) % 10 + 1;
  return switch (i) {
    1 => StarGoal(GoalKind.hits, 3 + c ~/ 3),
    2 => StarGoal(GoalKind.blocks, 2 + c ~/ 4),
    3 => StarGoal(GoalKind.lowDamage, 50 + 5 * c),
    4 => StarGoal(GoalKind.headHits, 1 + c ~/ 6),
    5 => const StarGoal(GoalKind.parries, 1),
    6 => StarGoal(GoalKind.fastWin, 50 + 3 * c),
    7 => const StarGoal(GoalKind.noShield, 0),
    8 => StarGoal(GoalKind.blocks, 3 + c ~/ 4),
    9 => StarGoal(GoalKind.lowDamage, 40 + 5 * c),
    _ => StarGoal(GoalKind.parries, c >= 3 ? 2 : 1),
  };
}

/// Star bits: win, win without losing a round, level challenge.
const int starWin = 1, starFlawless = 2, starGoal = 4;

int starBits(bool won, MatchStats st, StarGoal goal) {
  if (!won) return 0;
  var bits = starWin;
  if (st.roundsLost == 0) bits |= starFlawless;
  if (goal.met(st)) bits |= starGoal;
  return bits;
}

int starCount(int bits) => (bits & 1) + ((bits >> 1) & 1) + ((bits >> 2) & 1);

int xpNeed(int lvl) => 60 + 40 * lvl;
int stageCoins(int stage, bool boss) => jsRound((30 + 8 * stage) * (boss ? 2 : 1));
int stageXp(int stage, bool boss) => jsRound((40 + 8 * stage) * (boss ? 1.5 : 1));

class LevelDef {
  const LevelDef(this.stage);

  final int stage;

  int get chapterIndex => (stage - 1) ~/ levelsPerChapter;
  int get index => (stage - 1) % levelsPerChapter + 1;
  ChapterDef get chapter => chapters[chapterIndex];
  bool get chapterBoss => index == 10;
  bool get miniBoss => index == 5;
  bool get boss => stage % 5 == 0;
  ArenaDef get arena => chapter.arena;
  StarGoal get goal => goalFor(stage);
  int get coins => stageCoins(stage, boss);
  int get xp => stageXp(stage, boss);

  /// Blueprint unlocked by the first win.
  String? get unlocks => chapterBoss
      ? chapter.bossWeapon
      : miniBoss
      ? chapter.miniShield
      : null;
}
