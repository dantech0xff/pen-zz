/// How wind behaves on an arena.
enum WindMode {
  none,

  /// Same direction all round; flips every round so no side keeps the advantage.
  roundFlip,

  /// Swaps direction every [ArenaRules.windPeriod] seconds with a smooth turn.
  alternate,

  /// Random gusts in random directions.
  gust,

  /// Short pulses on a beat, alternating direction.
  beat,
}

/// Background paper pattern.
enum PaperKind { grid, lined, dots, sepia, blueprint, pixel, staff, green, kraft, chalk }

/// Decorative doodles drawn behind the platform.
enum Doodle { math, letters, english, physics, chem, history, geo, bio, art, sport, code, music }

class Zone {
  const Zone(this.x0, this.x1);
  final double x0;
  final double x1;
  bool contains(double x) => x >= x0 && x <= x1;
}

class ArenaRules {
  const ArenaRules({
    this.half = 330,
    this.frictionMul = 1,
    this.wind = WindMode.none,
    this.windStrength = 0,
    this.windPeriod = 5,
    this.shrinkStart = 0,
    this.shrinkSpeed = 0,
    this.shrinkMin = 150,
    this.mud = const [],
    this.slick = const [],
  });

  /// Half width of the platform; stepping past it means falling.
  final double half;

  /// Multiplier on knockback slide friction (below 1 is slippery).
  final double frictionMul;
  final WindMode wind;
  final double windStrength;
  final double windPeriod;

  /// Seconds into a round before the edges start crumbling, speed in px/s, and the floor of the shrink.
  final double shrinkStart;
  final double shrinkSpeed;
  final double shrinkMin;

  /// Zones that slow walking, and zones that are extra slippery.
  final List<Zone> mud;
  final List<Zone> slick;

  bool get shrinks => shrinkSpeed > 0;
  bool get windy => wind != WindMode.none && windStrength > 0;
}

class ArenaTheme {
  const ArenaTheme({
    required this.paper,
    required this.line,
    required this.kind,
    required this.doodle,
    this.platform = 0xFBFAF3,
    this.edge = 0x474B55,
    this.ink = 0x474B55,
    this.accent = 0xD3303C,
  });

  final int paper;
  final int line;
  final PaperKind kind;
  final Doodle doodle;
  final int platform;
  final int edge;

  /// Colour of doodles and labels.
  final int ink;
  final int accent;
}

class ArenaDef {
  const ArenaDef(this.id, this.name, this.rules, this.theme, this.ruleText);

  final String id;
  final String name;
  final ArenaRules rules;
  final ArenaTheme theme;
  final String ruleText;
}

const List<ArenaDef> arenas = [
  ArenaDef(
    'o-li',
    'Trang ô li',
    ArenaRules(),
    ArenaTheme(paper: 0xFBFAF3, line: 0xD3DBF1, kind: PaperKind.grid, doodle: Doodle.math),
    'Sân cổ điển, luật như bản gốc.',
  ),
  ArenaDef(
    'dong-ke',
    'Giấy dòng kẻ',
    ArenaRules(mud: [Zone(-210, -130), Zone(100, 180)]),
    ArenaTheme(paper: 0xFDFBF4, line: 0xBFD3EA, kind: PaperKind.lined, doodle: Doodle.letters, accent: 0x6A3DB8),
    'Vệt mực loang: đi qua thì bước chậm lại.',
  ),
  ArenaDef(
    'chinh-ta',
    'Sổ chính tả',
    ArenaRules(half: 270),
    ArenaTheme(paper: 0xF7FAFF, line: 0xC9D3E8, kind: PaperKind.dots, doodle: Doodle.english),
    'Sàn hẹp: dễ bị đánh văng khỏi sàn hơn.',
  ),
  ArenaDef(
    'quat-tran',
    'Quạt trần',
    ArenaRules(wind: WindMode.alternate, windStrength: 1, windPeriod: 5),
    ArenaTheme(paper: 0xF4F8FB, line: 0xC5D6E6, kind: PaperKind.blueprint, doodle: Doodle.physics, ink: 0x2F5D8A),
    'Quạt trần: gió đổi chiều mỗi 5 giây, đẩy người và làm đòn văng lệch.',
  ),
  ArenaDef(
    'thi-nghiem',
    'Phòng thí nghiệm',
    ArenaRules(frictionMul: 0.62),
    ArenaTheme(paper: 0xF3FBF7, line: 0xBFE3D3, kind: PaperKind.grid, doodle: Doodle.chem, ink: 0x1B8452),
    'Sàn trơn hoá chất: bị đánh trúng là trượt xa hơn.',
  ),
  ArenaDef(
    'thanh-co',
    'Thành cổ',
    ArenaRules(shrinkStart: 18, shrinkSpeed: 7, shrinkMin: 150),
    ArenaTheme(
      paper: 0xF6EBD3,
      line: 0xE0CBA0,
      kind: PaperKind.sepia,
      doodle: Doodle.history,
      ink: 0x7A4A2A,
      platform: 0xF1E2C2,
    ),
    'Thành cổ: sau 18 giây sàn sụt dần từ hai mép.',
  ),
  ArenaDef(
    'ban-do',
    'Bản đồ',
    ArenaRules(half: 370, mud: [Zone(-285, -205), Zone(205, 285)]),
    ArenaTheme(paper: 0xF4F6EC, line: 0xD5DDBE, kind: PaperKind.kraft, doodle: Doodle.geo, ink: 0x5C6B2E),
    'Bản đồ rộng, có đầm lầy gần hai mép làm chậm bước.',
  ),
  ArenaDef(
    'vuon-truong',
    'Vườn trường',
    ArenaRules(wind: WindMode.roundFlip, windStrength: 0.6, mud: [Zone(-110, -50)]),
    ArenaTheme(paper: 0xF2F9EC, line: 0xCFE6BE, kind: PaperKind.green, doodle: Doodle.bio, ink: 0x2F7A2F),
    'Gió nhẹ thổi một chiều, đổi chiều mỗi hiệp; có vũng bùn giữa sân.',
  ),
  ArenaDef(
    'gia-ve',
    'Giá vẽ',
    ArenaRules(slick: [Zone(-250, -170), Zone(-35, 35), Zone(170, 250)]),
    ArenaTheme(paper: 0xFFFDF8, line: 0xEADFD5, kind: PaperKind.dots, doodle: Doodle.art, ink: 0xC2185B),
    'Vũng sơn trơn: bị đánh trúng khi đứng trên vũng là trượt rất xa.',
  ),
  ArenaDef(
    'san-truong',
    'Sân trường',
    ArenaRules(half: 380, wind: WindMode.gust, windStrength: 1.25),
    ArenaTheme(paper: 0xF2F5F0, line: 0xD2DCCB, kind: PaperKind.lined, doodle: Doodle.sport, ink: 0x2E6B3A),
    'Sân rộng, thỉnh thoảng có gió giật bất chợt.',
  ),
  ArenaDef(
    'man-hinh',
    'Màn hình',
    ArenaRules(half: 290, shrinkStart: 15, shrinkSpeed: 8, shrinkMin: 140),
    ArenaTheme(
      paper: 0xEEF3FF,
      line: 0xC3CFF0,
      kind: PaperKind.pixel,
      doodle: Doodle.code,
      ink: 0x2D4FB8,
      platform: 0xF5F8FF,
    ),
    'Sàn hẹp và co dần sau 15 giây.',
  ),
  ArenaDef(
    'khuong-nhac',
    'Khuông nhạc',
    ArenaRules(frictionMul: 0.82, wind: WindMode.beat, windStrength: 1.1, windPeriod: 2),
    ArenaTheme(paper: 0xFFFBF5, line: 0xD9CFE6, kind: PaperKind.staff, doodle: Doodle.music, ink: 0x6A3DB8),
    'Gió đập theo nhịp mỗi 2 giây, sàn hơi trơn.',
  ),
];

final Map<String, ArenaDef> arenasById = {for (final a in arenas) a.id: a};

ArenaDef arenaOf(String id) => arenasById[id] ?? arenas.first;
