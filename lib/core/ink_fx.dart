/// Gameplay effect carried by a special weapon ink.
enum InkFx { none, ice, fire, shock, stone, wind, leech }

/// Stat side of an ink effect: knockback, % damage and wind-up multipliers,
/// plus the text shown in the wardrobe.
class InkFxSpec {
  const InkFxSpec({
    required this.title,
    required this.desc,
    this.pMul = 1,
    this.dMul = 1,
    this.windMul = 1,
  });

  final String title;
  final String desc;
  final double pMul;
  final double dMul;
  final double windMul;
}

const Map<InkFx, InkFxSpec> inkFxSpecs = {
  InkFx.none: InkFxSpec(title: '', desc: ''),
  InkFx.ice: InkFxSpec(
    title: 'Băng',
    desc: 'Trúng đòn làm đối thủ chậm lại 1,3 giây: đi chậm, vung và giơ khiên chậm hơn. Văng kém 8%.',
    pMul: 0.92,
  ),
  InkFx.fire: InkFxSpec(
    title: 'Lửa',
    desc: 'Trúng đòn làm đối thủ bỏng, cộng thêm khoảng 4% trong 1,5 giây. % trực tiếp kém 12%.',
    dMul: 0.88,
  ),
  InkFx.shock: InkFxSpec(
    title: 'Sét',
    desc: '25% cơ hội làm đối thủ tê liệt thêm 0,3 giây sau khi trúng. Văng kém 5%.',
    pMul: 0.95,
  ),
  InkFx.stone: InkFxSpec(
    title: 'Đá',
    desc: 'Đòn nặng: văng xa hơn 15% nhưng vung chậm hơn 6%.',
    pMul: 1.15,
    windMul: 1.06,
  ),
  InkFx.wind: InkFxSpec(
    title: 'Gió',
    desc: 'Đẩy văng xa hơn 15% nhưng chỉ cộng 75% số % thường.',
    pMul: 1.15,
    dMul: 0.75,
  ),
  InkFx.leech: InkFxSpec(
    title: 'Hút',
    desc: 'Trúng đòn hồi lại cho bạn 30% số % vừa gây ra. Văng kém 8%.',
    pMul: 0.92,
  ),
};

InkFxSpec inkFxSpec(InkFx fx) => inkFxSpecs[fx]!;

// On-hit tuning shared by the battle simulation and its tests.
const double chillTime = 1.3;
const double chillWalk = 0.65;
const double chillSlow = 1.25;
const double burnTime = 1.5;
const double burnTick = 0.3;
const double burnDmg = 0.8;
const double shockChance = 0.25;
const double shockStun = 0.3;
const double leechRatio = 0.3;
