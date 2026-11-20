# GDD fact sheet: Bút Chiến (Flutter mobile build)

Read-only scouting of HEAD e6440ec for the game design document. Citations are file:line under the repo root. "not in code" means the value is not defined in the repo.

## 1. Core loop and controls

**Drawing (editor)**
- Player draws a weapon and a shield with strokes; both are reused in every match.
- Total ink cap `inkMax = 800`, shared by weapon and shield (lib/core/rig.dart:6). saveGear trims weapon to 800, then shield to 800 - weaponInk (lib/state/game_controller.dart:100-104). Load tolerates +30 (lib/core/save_data.dart:174).
- Ink = total stroke polyline length; a stroke under 4 values costs 3 ink (lib/core/strokes.dart:14-29).
- Weapon canvas: 380x380 box (rig.dart:11), origin at grip feet+hand0 (draw_screen.dart:69, 93-97).
- Shield canvas: circle radius shZone=120 (rig.dart:10) around feet+shRaised (draw_screen.dart:94, 602).
- Minimum weapon ink to save: 20 (draw_screen.dart:154). Shield counts as present at ink >= 5 (gear.dart:204).
- Drawing stops when ink runs out; minimum point step 2.5 px (draw_screen.dart:127).
- "Hoàn tác" (undo) and "Xóa hết" (clear) (draw_screen.dart:460-486).
- Blueprints "Mẫu" (draw_screen.dart:344): pool = starter templates plus boss and mini-boss unlocks (draw_screen.dart:25-34). Stamping needs stampMinInk = 0.30 x template ink (bots.dart:279-282; check draw_screen.dart:229). Stamp scales down to fit the remaining ink (bots.dart:287-298).
- First run: weapon, then shield, then "Xong, vào màn N" calls openStage (draw_screen.dart:161-167).

**Battle controls** (lib/ui/screens/battle_screen.dart:181-226; flex 78/78/100/118)
- "lùi" (back) pad, "tới" (forward) pad, "ĐỠ" (block, hold; shows "không khiên" with no shield), "ĐÁNH" (attack, tap; highlighted when atkReady, battle_game.dart:294).
- Keyboard (lib/game/battle_game.dart:117-124): forward D or right arrow; back A or left arrow; block K, Shift-left, Shift-right; attack J or Space. Keyboard hint shown only on web (battle_screen.dart:169).

**Rounds**
- Best of 3: BattleSetup.roundsToWin = 2 (battle.dart:44, win check battle.dart:685).
- Round start: 1.0 s ready, then "ĐÁNH!" (battle.dart:708-715; banner 0.6 s, battle_game.dart:174).
- Round-over banner holds 1.6 s (battle.dart:770).
- A fighter falls when |x| > half + 2 (battle.dart:756); the round ends when fall time > 0.85 s (battle.dart:765-768).
- Walking stops at half - 8 (battle.dart:640, 650). Only hits push a fighter over the edge.

**No round timer**: the platform crumbles instead.
- Standard arenas: shrink starts at 75 s of fight time, speed 6 px/s, minimum half-width 130 (battle.dart:146-148).
- Crumbling arenas use their own values (section 6).
- Warning "Sàn sắp sụt!" 3 s before the shrink (battle.dart:720-723).

## 2. Gear formulas (lib/core/gear.dart, lib/core/rig.dart)

**Weapon**
- Attack base = ink (gear.dart:152); points multiply via mulAtk.
- len and wid come from the grip-to-tip axis (dimsOf, gear.dart:29-52).
- Swing times (gear.dart:155-157):
  - windup = 0.05 + 0.0005*len + 0.0000095*len^2 + 0.0008*wid
  - strike = 0.03 + 0.0005*len + 0.0000025*len^2 + 0.0003*wid
  - recover = 0.08 + 0.0008*len + 0.000006*len^2 + 0.0004*wid
- cast = windup + strike (gear.dart:107); cycle adds recover (gear.dart:108).
- Reach: farthest forward x during the swing, sampled at 33 angles, body band -112 < y < -2 (gear.dart:55-67).
- Reach class by len (gear.dart:13-19): <110 "ngắn", <160 "vừa", <250 "dài", else "quá dài".
- Knockback: knock(tough) = (30 + 0.25*atk/tough) * pMul (gear.dart:99).
- Damage per hit: pct(tough) = (3 + atk/tough/40) * dMul (gear.dart:102).

**Shield** (gear.dart:202-238)
- Defence = ink * mulDef (gear.dart:227; boostS gear.dart:287).
- Raise = 0.03 + 0.0012*h + 0.000009*h^2 + 0.0004*w (gear.dart:235).
- Lower = 0.04 + 0.0007*h + 0.0002*w (gear.dart:236). h, w = bounding box height, width.
- parryWin = 0.2 s (gear.dart:177). Coverage = filled bins / 27 (gear.dart:234).

**Points** (gear.dart:240-260)
- softPts(p) = p up to 20; above 20: 20 + 20*ln(1 + (p-20)/20) (gear.dart:255).
- mulAtk = 1 + 0.05*soft(pow) (gear.dart:257). 20 points = x2.00.
- mulDef = 1 + 0.05*soft(def) (gear.dart:258).
- mulTime = 1/(1 + 0.04*soft(spd)) (gear.dart:259); multiplies windup, strike, recover. 20 points = x0.556.
- mulWalk = 1 + 0.02*soft(spd) (gear.dart:260). 20 points = x1.40.
- Points per level: 3 (game_controller.dart:285).
- Toughness = 1 + 0.05*soft(total ~/ 3) (gear.dart:264). Examples: 3 pts = 1.05; 30 = 1.50; 60 = 2.00; 90 ≈ 2.41.

**Walk speed** (gear.dart:266-269)
- Base 100 px/s (gear.dart:11). Fight speed = base * mulWalk * gearWalk (battle.dart:159).
- Weapon factor clamp(1 - 0.002*(len-140), 0.55, 1.15) (gear.dart:267).
- Shield factor clamp(1 - 0.0018*(h-85), 0.7, 1.08) (gear.dart:268). Applied even with no shield (gives the 1.08 cap).
- Walk modifiers (battle.dart:643): backward x0.8; shield raised past r>0.5 x0.35; mud x0.55 (battle.dart:228); chilled x0.65.

**Bot windup handicap**: botWindMul(aiL) = max(1, 1.6 - 0.08*(aiL-1)) (ai.dart:134), applied to bot windup (battle.dart:207). Player windMul = 1 (setup.dart:21).

## 3. Combat resolution (lib/core/battle/battle.dart, lib/core/ink_fx.dart)

**Contact** (battle.dart:306-341)
- Weapon swept from previous to current angle in up to 14 sub-steps, each <= 2.5 degrees (battle.dart:333).
- Each weapon point is checked against the fully raised shield first (r >= 1), then the body.
- Shield contact radius = wR + sR = 9.5 (battle.dart:302, 311).
- Hurt boxes (battle.dart:264-284): capsules hip-neck r8; hip-kneeF r6; kneeF-footF r5.5; hip-kneeB r6; kneeB-footB r5.5; each + wR 4.5. Head circle radius 11+2+4.5 = 17.5 (rig.dart:25).
- Head hit: damage x1.2, knockback x1.2 (battle.dart:412).

**Damage and knockback** (battle.dart:347-459)
- dmg = pct(d.tough) * mult (battle.dart:413).
- dist = knock(d.tough) * mult * (1 + d.dmg/45) (battle.dart:415). Accumulated damage increases knockback.
- Shove velocity vx = sign * sqrt(2 * 1600 * dist) (battle.dart:343; frictionBase rig.dart:15).
- Hitstun stunT = 0.2 + dist/700 (battle.dart:419).
- Hop hopV = -min(520, 160 + 1.6*dist) (battle.dart:422).
- Hitstop = 0.05 + min(0.09, kp/1800) (battle.dart:423).

**Block vs parry** (battle.dart:350-411)
- Parry window: now - raisedAt <= 0.2 s; raisedAt is set when the shield reaches r=1 (battle.dart:525-527, 351).
- Parry: attacker stunned 0.8 s and shoved back 30 + 0.35*knock(a.tough) (battle.dart:357), hitstop 0.13 s (battle.dart:358). Label "ĐỠ CHUẨN!".
- Block outside the window: diff = atk - def; push = |diff| * 0.45 / toughness of the pushed side (battle.dart:375; kBlock gear.dart:10).
  - diff > 4: defender pushed, "ÉP LÙI".
  - diff < -4: attacker pushed, "DỘI LẠI".
  - else "CHẶN", no push.
  - Attacker enters recover (battle.dart:376-379). Hitstop 0.05 s (battle.dart:394).
- Shield partly up (0.02 < r < 1) when hit: "HẠ KHIÊN SỚM", or "CHƯA KỊP ĐỠ" if block is held (battle.dart:441-453).
- Raise: r += dt/raise; lower: r -= dt/lower; raising is blocked during attacks (battle.dart:520-542).

**Ring-out**
- Fall: vy = -160, gravity 2400 (battle.dart:759; rig.dart:16).
- Minimum fighter gap 46 px (battle.dart:748-751).

**Ink effects** (lib/core/ink_fx.dart:16-59; applied battle.dart:461-502)

| Ink (id, price) | pMul | dMul | windMul | On-hit effect |
|---|---|---|---|---|
| Băng (muc-bang, 2500) | 0.92 | 1 | 1 | Chilled 1.3 s: walk x0.65, windup and raise x1.25. "ĐÓNG BĂNG". |
| Lửa (muc-lua, 2500) | 1 | 0.88 | 1 | Burn 1.5 s, 0.8 per 0.3 s (about 4%); burn adds to dmg, so later knockback. "BỎNG". |
| Sét (muc-set, 3000) | 0.95 | 1 | 1 | 25% chance: stun +0.3 s. "TÊ LIỆT". |
| Đá (muc-da, 1500) | 1.15 | 1 | 1.06 | None; slower windup. |
| Gió (muc-gio, 1800) | 1.15 | 0.75 | 1 | None. |
| Hút (muc-hut, 3500) | 0.92 | 1 | 1 | Attacker heals 30% of damage dealt. "HỒI x%". |
| Cầu vồng (muc-cau-vong, 6000) | 1 | 1 | 1 | Cosmetic. |
| Hoàng kim, Ngân hà (exclusive) | 1 | 1 | 1 | Cosmetic. |

Effects apply only to weapon inks (catalog.dart:198).

## 4. Bot AI and opponents

- AI level (bots.dart:32): aiLevelFor = 1 + floor((stage-1)/17) + (boss ? 1 : 0). Non-boss L1 stages 1-17, L2 18-34, L3 35-51, L4 52-68, L5 69-85, L6 86-102, L7 103-119; bosses (stage % 5 == 0) +1, max 9 at stage 120.
- Bot level = 1 + floor((stage-1)*0.45) (bots.dart:165); stage 120 gives 54.
- Ghost AI level = clamp(1 + lvl/3, 1, 6) (bots.dart:231).
- Archetypes (bots.dart:16-21), split pow/def/spd: hùng hổ 0.6/0.2/0.2; lì lợm 0.2/0.6/0.2; nhanh nhẹn 0.2/0.2/0.6; cân bằng 1/3 each. Chosen per stage with a seeded RNG (bots.dart:167).
- Bot points (bots.dart:192): round((lvl-1)*3*(boss?1.15:1)*botPower), split by archetype, remainder to spd (bots.dart:23-26).
- Weapon choice (bots.dart:169-180): stages 1-2 "kiem" at scale 0.9, no ink fill; chapter boss: its boss weapon; first chapter, or 80%: random chapter weapon; otherwise a random weapon from earlier chapters, boss weapons included.
- Weapon build (bots.dart:90-96): scale = 0.85 + U(0,0.3) + min(0.15, 0.03*(aiL-1)); for aiL >= 2, ink filled to min(560, ink*(1+0.15*(aiL-1))) (weaponInkCap bots.dart:29). Wobble 1.2.
- Shield (bots.dart:241-276), drawn at startBattle after seeing the player's weapon (game_controller.dart:274): budget = 800 - weaponInk - 8; want = playerAtk * (0.7 + min(0.4, 0.06*(aiL-1)) + U(-0.1, 0.15)) / mulDef(botPts), clamped to [90, budget]. Pool: mini-boss signature shield, else chapter shields; tall shields only if player reach > 200; falls back to "khien-nho" if the scale k < 0.5.
- Brain (lib/core/battle/ai.dart):
  - Reaction delay U(0.14,0.32) * max(0.55, 1 - 0.06*(L-1)) (ai.dart:43).
  - Block probability min(0.85, 0.3 + 0.08*(L-1) + 0.15 if safe - 0.2 if bad) (ai.dart:46).
  - Retreat (L>=2) when a block would not hold and there is room (ai.dart:51-53).
  - Passive guard (L>=3) against fast weapons (ai.dart:58-71).
  - Movement re-rolled every U(0.15,0.35) s; random dodge at L>=3 (ai.dart:86-106).
  - Attack timing U(0.15,0.6) * max(0.5, 1-0.06*(L-1)); punishes openings faster (ai.dart:111-116).
  - Waits when the foe's raised shield out-defends its attack, probability min(0.9, 0.25*L) (ai.dart:119-125).
- Looks (bots.dart:110-157): stages 1-2 default look; non-boss hat from stage 3, glasses from 4, cape from 6, price cap 600 + 12*stage, hit FX from stage 8, effect ink chance min(0.45, 0.15+0.004*(stage-25)) from stage 25. Bosses use fixed lists; weapon effect ink 60% from chapter index 1. Bots never use exclusive items.
- Practice bot: the stage bot at the player's cleared stage, named "Bot luyện tập", no level rewards. Ghost: the player's gear, points and wardrobe, AI driven, "Bóng ma của bạn", shield not redrawn (bots.dart:204-237).
- Sample (seeded): stage 1 = Bảng Cửu Chương, lvl 1, lì lợm, kiếm, công 163, tầm 172 (vừa), thi triển 0.44 s. Stage 35 = Trùm Đĩa Quang, lvl 16, aiL 4, cân bằng 17/17/18, búa, công 1051, tầm 249 (dài), thi triển 0.57 s, mực băng, signature shield khien-dia.

## 5. Progression (lib/core/levels.dart, lib/state/game_controller.dart)

Ten stages per chapter; mini-boss at index 5, chapter boss at index 10; boss if stage % 5 == 0 (levels.dart:272).

| # | Vở | Arena | Mini-boss (shield unlock) | Boss (weapon unlock) | botPower |
|---|---|---|---|---|---|
| 1 | Toán | Trang ô li | Trùm Phấn Trắng (Khiên cục tẩy) | Trùm Bảng Đen (Com-pa) | 1 |
| 2 | Văn | Giấy dòng kẻ | Trùm Sổ Đầu Bài (Khiên quyển sách) | Trùm Bút Mực Tím (Bút lông) | 1 |
| 3 | Tiếng Anh | Sổ chính tả | Trùm Từ Mới (Khiên quyển vở) | Trùm Ngữ Pháp (Cờ hiệu) | 1.15 |
| 4 | Lý | Quạt trần | Trùm Đĩa Quang (Khiên đĩa quang) | Trùm Nam Châm (Nam châm) | 1.0 |
| 5 | Hóa | Phòng thí nghiệm | Trùm Vòng Benzen (Khiên lục giác) | Trùm Phân Tử (Chùy phân tử) | 0.8 |
| 6 | Sử | Thành cổ | Trùm Rùa Vàng (Khiên mai rùa) | Trùm Đại Đao (Đại đao) | 1.05 |
| 7 | Địa | Bản đồ | Trùm Địa Cầu (Khiên địa cầu) | Trùm Mái Chèo (Mái chèo) | 0.8 |
| 8 | Sinh | Vườn trường | Trùm Lá Sen (Khiên lá sen) | Trùm Lá Kiếm (Lá kiếm) | 1.1 |
| 9 | Mỹ thuật | Giá vẽ | Trùm Bảng Màu (Khiên bảng màu) | Trùm Cọ Khổng Lồ (Cọ vẽ khổng lồ) | 0.85 |
| 10 | Thể dục | Sân trường | Trùm Huy Chương (Khiên ngôi sao) | Trùm Vợt Cầu (Vợt cầu lông) | 1.1 |
| 11 | Tin học | Màn hình | Trùm Màn Hình Xanh (Khiên màn hình) | Trùm Chuột Cáp (Chuột cáp) | 0.9 |
| 12 | Âm nhạc | Khuông nhạc | Trùm Mặt Trống (Khiên mặt trống) | Trùm Trống Trường (Dùi trống trường) | 0.95 |

- Each chapter lists 4 weapons, 4 shields and 7 bot names (levels.dart:39-194).
- Unlock on first clear: index 5 unlocks the mini-boss shield, index 10 the boss weapon (levels.dart:279-283; game_controller.dart:309-310).
- Starter blueprints: Kiếm, Giáo; Khiên tròn, Khiên tháp (templates.dart:238-239, 276-277).
- 120 stages (levels.dart:197). 3 stars each (levels.dart:246): win; win 2-0; stage goal.

Goal by i = (stage-1)%10 + 1, c = 0-based chapter (levels.dart:229-243):

| i | Goal |
|---|---|
| 1 | Hits >= 3 + c/3 |
| 2 | Blocks >= 2 + c/4 |
| 3 | Final own damage < 50 + 5c % |
| 4 | Head hits >= 1 + c/6 |
| 5 | Parries >= 1 |
| 6 | Fight time < 50 + 3c s |
| 7 | Never raise the shield |
| 8 | Blocks >= 3 + c/4 |
| 9 | Final own damage < 40 + 5c % |
| 10 | Parries >= (c >= 3 ? 2 : 1) |

Rewards (game_controller.dart:291-338; levels.dart:258-260):
- Stage coins = round((30 + 8*stage) * (boss ? 2 : 1)); stage XP = round((40 + 8*stage) * (boss ? 1.5 : 1)).
- First clear: full coins and XP. Replay win: coins x0.4, XP x0.5.
- New 2-0 star: +25% of base coins; new goal star: +50% of base coins (only newly earned stars).
- Stage loss: 5 + stage coins, 10 + 2*stage XP.
- Practice: win 20 coins and 30 XP; loss 5 coins and 10 XP.
- XP needed from level L = 60 + 40*L (levels.dart:258); 3 points per level-up.
- Respec 100 coins, refunds all spent points (game_controller.dart:141-151).
- Practice arenas open = stage/10 + 1, clamped 1-12 (game_controller.dart:95).

## 6. Arenas (lib/core/arenas.dart:101-200)

Default half-width 330, friction 1. Chapter n uses arena n.

| Arena | Half | Friction | Wind | Shrink | Mud | Slick | Rule text |
|---|---|---|---|---|---|---|---|
| Trang ô li | 330 | 1 | none | default | – | – | Sân cổ điển, luật như bản gốc. |
| Giấy dòng kẻ | 330 | 1 | none | default | [-210,-130], [100,180] | – | Vệt mực loang: đi qua thì bước chậm lại. |
| Sổ chính tả | 270 | 1 | none | default | – | – | Sàn hẹp: dễ bị đánh văng khỏi sàn hơn. |
| Quạt trần | 330 | 1 | alternate, 1.0, every 5 s | default | – | – | Gió quạt đổi chiều mỗi 5 giây, đẩy người và làm đòn văng lệch. |
| Phòng thí nghiệm | 330 | 0.62 | none | default | – | – | Sàn trơn hoá chất: bị đánh trúng là trượt xa hơn. |
| Thành cổ | 330 | 1 | none | from 18 s, 7 px/s, min 150 | – | – | Sau 18 giây sàn sụt dần từ hai mép. |
| Bản đồ | 370 | 1 | none | default | [-285,-205], [205,285] | – | Sàn rộng, có đầm lầy gần hai mép làm chậm bước. |
| Vườn trường | 330 | 1 | roundFlip, 0.6 | default | [-110,-50] | – | Gió nhẹ thổi một chiều, đổi chiều mỗi hiệp; có vũng bùn giữa sân. |
| Giá vẽ | 330 | 1 | none | default | – | [-250,-170], [-35,35], [170,250] | Vũng sơn trơn: bị đánh trúng khi đứng trên vũng là trượt rất xa. |
| Sân trường | 380 | 1 | gust, 1.25 | default | – | – | Sân rộng, thỉnh thoảng có gió giật bất chợt. |
| Màn hình | 290 | 1 | none | from 15 s, 8 px/s, min 140 | – | – | Sàn hẹp và co dần sau 15 giây. |
| Khuông nhạc | 330 | 0.82 | beat, 1.1, every 2 s | default | – | – | Gió đập theo nhịp mỗi 2 giây, sàn hơi trơn. |

- Default shrink: from 75 s, 6 px/s, min 130 (battle.dart:146-148).
- Wind modes (arenas.dart:2-16): roundFlip by round parity; alternate flips every period; gust random 1.4-2.6 s every 2-4 s; beat pulses in the first 0.5 s of each period, x1.8 (battle.dart:242-255). Direction is random per round.
- Wind accel 320 px/s^2 (battle.dart:99, 576); drift when still 24 px/s (battle.dart:100, 658); smoothing 3/s (battle.dart:259).
- Mud: friction x1.35, walk x0.55. Slick: friction x0.5 (battle.dart:215-228).

## 7. Content catalog (lib/core/catalog.dart, lib/core/templates.dart)

Counts: hats 19; capes 15; glasses 11; body inks 14; weapon inks 9; hit FX 16; taunts 10. Weapon templates 35; shield templates 19.

- Hats (catalog.dart:46-66): khong-mu 0; non-la 150; luoi-trai 150; bao-hiem 250; tai-meo 250; mu-len 300; bang-do 350; non-coi 450; tot-nghiep 600; phu-thuy 800; cao-boi 900; tai-tho 1000; vong-hoa 1200; cuop-bien 1500; sung-quy 2200; hao-quang 3500; vuong-mien 5000. Exclusive: vuong-mien-ngoc, mu-ngan-ha.
- Capes (catalog.dart:68-84): khong-choang 0; khan-do 150; phi-phong-do 250; khan-ran 400; ao-choang-den 500; balo 600; ao-choang-la 800; ao-choang-sao 1000; ao-choang-bang 1400; ao-choang-lua 1800; canh-doi 2600; phi-phong-vang 3500; canh-thien-than 4500. Exclusive: ao-choang-hoang-gia, ao-choang-ngan-ha.
- Glasses (catalog.dart:86-98): khong-kinh 0; kinh-can 100; kinh-ram 200; kinh-tim 250; kinh-boi 300; kinh-tron-vang 500; bit-mat 700; kinh-3d 900; kinh-sao 1200; mat-na 1600; kinh-pixel 2500.
- Body inks (catalog.dart:100-115): muc-xanh 0; muc-den 100; muc-xam 150; muc-tim 150; muc-luc 150; muc-ngoc 200; muc-cam 200; muc-hong 300; muc-nau 300; muc-troi 400; muc-man 600; nhu-vang 1500; muc-bac 2500. Exclusive: nhu-ngoc (starter pack).
- Weapon inks (catalog.dart:118-128): muc-da 1500; muc-gio 1800; muc-bang 2500; muc-lua 2500; muc-set 3000; muc-hut 3500; muc-cau-vong 6000 (cosmetic). Exclusive: muc-hoang-kim, muc-ngan-ha (cosmetic).
- Shield ink: same as body, or any body ink (catalog.dart:187).
- Hit FX (catalog.dart:130-147): muc 0; lua 250; set 300; bong-bong 300; cau-vong 400; hoa-dao 400; trai-tim 500; ngoi-sao 600; tuyet 700; giay-vun 800; phao-hoa 1000; la-phong 1100; not-nhac 1300; muc-tau 1500; dien-tu 1800; chu-bop 2500.
- Taunts (catalog.dart:149-160): vay-tay 0 "Hehe!"; cui-chao 150 "Cảm ơn đã chơi!"; nhay 200 "Dễ ợt!"; gong 250 "Ai nữa?"; vo-tay 300 "Hay lắm!"; xoay 400 "Còn non lắm!"; tra-da 500 "Làm ly trà đá đã."; chup-anh 800 "Chụp tấm kỷ niệm!"; ngoi-thien 1200 "Tĩnh tâm…"; ngu-gat 1800 "Zzz… buồn ngủ quá."
- Owned at start: khong-mu, khong-choang, khong-kinh, muc-xanh, muc, vay-tay (save_data.dart:41-47).
- Weapon templates (templates.dart:237-272): starters kiem, giao; others bua, riu, chuy-gai, dao-cong, dinh-ba, thuoc-ke, com-pa, e-ke, but-chi, but-long, keo, liem, choi, quat, mai-cheo, gay-bong-chay, vot, sao-truc, dui-trong, dui-trong-truong, dan-ghita, kinh-lup, chuot-cap, nam-cham, lo-xo, ong-nghiem, dai-dao, thuong, co, xeng, la, co-ve, chuy-phan-tu.
- Shield templates (templates.dart:275-294): starters khien-tron, khien-thap (tall); tall khien-dieu, khien-sach, khien-la, khien-mai-rua; others khien-nho, khien-gai, khien-tay, khien-vo, khien-luc-giac, khien-dia, khien-dia-cau, khien-bang-mau, khien-man-hinh, khien-trong, khien-sao, khien-tim, khien-nap-noi.

## 8. Economy and monetization

- Coin sources: stage clears, practice, rewarded free coins, rewarded doubling, coin packs, starter pack. Sinks: wardrobe items (game_controller.dart:109-124), respec 100 coins. Start: 0 coins, level 1 (save_data.dart:9-16).

| id | Kind | Title | Coins | Entitlement | Items |
|---|---|---|---|---|---|
| pz_remove_ads | one-time | Gỡ quảng cáo | – | no_ads | – |
| pz_starter_pack | one-time | Gói khởi đầu | 2000, once per account | starter_pack | nhu-ngoc |
| pz_set_royal | one-time | Bộ Hoàng gia | – | set_royal | vuong-mien-ngoc, ao-choang-hoang-gia, muc-hoang-kim |
| pz_set_galaxy | one-time | Bộ Ngân hà | – | set_galaxy | mu-ngan-ha, ao-choang-ngan-ha, muc-ngan-ha |
| pz_coins_1000 | consumable | Túi xu | 1000 | – | – |
| pz_coins_3500 | consumable | Hộp xu | 3500 | – | – |
| pz_coins_9000 | consumable | Rương xu | 9000 | – | – |

- Prices are set in the stores (not in code). Store groups (store_sheet.dart:82-85): Gỡ quảng cáo; Gói khởi đầu; Bộ trang phục độc quyền; Xu.
- Coin packs credit once per RevenueCat transaction id (game_controller.dart:255-262); starter once per account (:244-252); purchases before storeSince are not credited (:253-254); remove-ads is sticky (:243).
- Ads (store_catalog.dart:94-110):
  - Free coins: 3 per day, 60 + 6*stage each (60 at stage 0, 780 at stage 120).
  - Interstitial when leaving a result card (battle_screen.dart:65-71): ads on and not removed, stage >= 3, at least 3 finished matches since the last one, at least 150 s since the last full-screen ad, rewarded included (monetization.dart:103-115).
  - Rewarded double: once per match reward when coins > 0, wins and losses (monetization.dart:66, 78-84).
  - Banner: lobby only, adaptive up to 90 px tall, else 320x50 (monetization.dart:63; home_screen.dart:241; admob_ads.dart:207, 225).
  - Remove ads hides the banner and interstitials; rewarded stays (store_sheet.dart:146-175).
  - Ad content rating capped at T (admob_ads.dart:55-56). Missing unit ids fall back to Google test ids (ad_ids.dart:14-26). Load retry 15 s * 2^(n-1), cap 300 s; presentation timeout 5 s (admob_ads.dart:66, 128).

## 9. Save and cloud

- Local: SharedPreferences key `pen-zz-save-v1`, JSON `v: 1`; write debounce 400 ms; flush on pause (game_controller.dart:45, 78; app.dart:114-131). Fields: coins, xp, lvl, free, pts, stage, stars (120 ints 0-7), owned, eq, w, s, blueprints, sound, haptics, tutorialDone, wins, losses, noAds, creditedPacks, creditedTx, storeSince, adDay, adCoinsUsed, matchesSinceAd, epoch, account. Defensive load limits (save_data.dart:142-246).
- Cloud: Android and iOS with Firebase configured. Firestore `players/{uid}` = {save JSON string, rev, updatedAt}. Rules: owner only; save < 600000 chars; rev = previous + 1; create with rev 1 (firestore.rules).
- Sync (lib/state/cloud_sync.dart): download and merge on start, resume and after leaving a match or the editor, once per session and account; no upload before the first merge; upload about 8 s after a change and when the app is hidden; conflict: merge and retry up to 3 times; writes fail at once offline.
- Merge (lib/core/save_merge.dart): same account, higher epoch wins; else further along (stage, level, XP, matches), ties keep the phone's; purchases merged (coins added once per transaction or pack, exclusives and remove-ads kept); free-coin counts take the larger value for the same day; sound and haptics stay per phone.
- Google linking (firebase_cloud.dart:156-196): links the anonymous account; if the Google account already exists, this phone's anonymous account and doc are deleted, then the player switches and merges. Outcomes: LinkedSame, LinkedSwitched, LinkCancelled, LinkFailed.
- Account deletion (cloud_panel.dart:49-72): confirm dialog; deletes the Firestore doc and the Firebase user (Google link too); the local save stays and is backed up under a new anonymous account.
- Reset progress (game_controller.dart:172-189): keeps sound, haptics, noAds, credited packs and transactions, storeSince, ad counters, account and exclusive items; epoch + 1.

## 10. Screens and navigation

- Scr enum (app.dart:18): home, draw, pre, battle, upgrade, shop, practice. Back handling app.dart:69-85.
- Home: header (logo, coin chip opens the store when the store is enabled and gear exists, settings icon), level pill and XP bar, total stars, hero (tap: taunt), chapter switcher with arena, cleared count and chapter stars, 2x5 stage nodes (bosses are "T" squares), rule text, main button "Đánh màn N" (+ "(trùm)") or "Vẽ đồ đầu tiên", 4 menu buttons (Luyện tập, Nâng cấp with alert dot, Tủ đồ, Sửa đồ; disabled before the first gear), banner at the bottom.
- Pre-match: title "Màn N · trùm · Vở X", arena rule, matchup text, two fighter cards, reward line, star goals, boss unlock line; Vào trận, Sửa khiên, Sửa vũ khí.
- Battle: HUD (names, %, round dots, pause, round number, attack and defence), hint line, pads lùi, tới, ĐỠ, ĐÁNH. Pause card: Tiếp tục, Đấu lại từ đầu, Bỏ trận. Tutorial card on the first match: "Đã hiểu, vào trận". Result card: title (Thắng!, Hạ trùm rồi!, Thua rồi), score and stats, rewards, x2 ad button, stars and goals, level-up line, blueprint unlock; buttons Màn N+1 or Đấu lại, Cộng N điểm nâng cấp, Sửa đồ (loss), Về sảnh; practice: Đấu lại, Về luyện tập.
- Draw: "Vẽ vũ khí" / "Vẽ khiên" on the first run, "Sửa đồ" otherwise with a Vũ khí / Khiên switch; Mẫu sheet; live stats; ink tube; Hoàn tác, Xóa hết, Tiếp: vẽ khiên / Xong, vào màn N / Lưu đồ.
- Upgrade: Sức mạnh, Phòng thủ, Tốc độ with +1; summary; "Tẩy điểm để cộng lại (100 xu)".
- Wardrobe: tabs Mũ, Áo choàng, Kính, Màu mực (Người / Vũ khí / Khiên), Hiệu ứng, Ăn mừng; preview; labels Đang dùng, Dùng, Mua · N xu, Thiếu N xu, Có trong <product>, Chỉ có trên bản app; "Cửa hàng" button.
- Practice: arena chips for opened chapters; Đấu bot luyện tập; Đấu bóng ma của chính bạn; wins and losses.
- Sheets: Settings (Âm thanh, Rung khi trúng đòn, stats line, cloud panel, Khôi phục giao dịch, privacy options, licences, Xoá tiến trình + dialog); Store (Xu miễn phí, Gỡ quảng cáo, Gói khởi đầu, Bộ trang phục độc quyền, Xu, link prompt after a purchase, Khôi phục giao dịch); Blueprint sheet (3-column grid, locked tiles dimmed).

## 11. Audio, haptics, feedback

| Sound | When |
|---|---|
| whoosh | Strike starts (vol 0.7) |
| hit | Any hit |
| block | CHẶN, ÉP LÙI, DỘI LẠI |
| parry | Perfect block |
| fall | Fighter falls |
| win / lose | Round end |
| crumble | 3 s before the shrink |
| freeze, burn, zap, heal | Ink effects (vol 0.7) |
| lvup | Match reward with a level-up |
| star | New star, no level-up |
| coin | Plain match reward, point spent, doubled reward |
| tap | Equip, hero tap (vol 0.4) |
| buy | Coin purchase |

- Haptics (sfx.dart:59-76), one toggle: hit on player medium, on opponent light; block light; parry heavy; player falls heavy.
- Visual: hit pop "+N%" / "Trúng đầu! +N%"; screen shake min(16, 3+kp/14) on hits, 3+push on blocks, 8 on parry, off with reduced motion; camera follows and zooms (battle.dart:370-440; battle_game.dart:299-318).

## 12. Balance tool (tool/balance.dart)

- `dart run tool/balance.dart` prints only; no target numbers in code.
- Proxy player: sword x1.05 filled to 380 ink, round shield 360 ink, AI level 5; lvl = 1 + floor(stage*0.47), points 3*(lvl-1) split evenly.
- Output 1: win rate per chapter at stages c*10 + {2,5,7,10}, 16 matches each, normal and boss separately, average fight time. Output 2: each special ink against a mirror without ink, 160 matches, stage 40 gear.

## Concerns

- gear.dart:267-268: the shield walk factor applies with no shield, so a shieldless fighter walks x1.08.
- battle.dart:343: slide speed uses frictionBase, not arena friction, so slides on slick floors go further than `dist`.
- battle.dart:415: burn damage also raises later knockback.
- bots.dart:117: chapter 1 bosses get no effect inks (0-based chapter index).
- Rewarded doubling is offered on losses too (monetization.dart:66).
