# Code review: Flutter + Flame port of Bút Chiến (2026-11-14 UTC)

**Scope:** all of `lib/` at HEAD f55badb, plus the uncommitted `lib/ui` edits another session made during the review. Those edits were layout and formatting only; I re-read the logic, and line numbers below come from that working tree.
**Checks:** `flutter analyze` reports no issues and `flutter test` passes 20/20. Evidence for the findings comes from Dart and widget probes run on a scratch copy of the app (412x860 dp view).
**Battle parity:** no defect found. `battle.dart`, `ai.dart`, `poses.dart`, `rig.dart`, `gear.dart` and `strokes.dart` match updateBot, resolveHit, testContact, sweep, updateFighter, updateShield, step, poseFor and updatePose line by line, apart from the listed intentional changes. An AI-vs-AI probe (18 stages x 3 seeds) produced no NaN, and every match finished (median 19 s, max 46 s).

## Findings, ranked
1. **HIGH, CONFIRMED (UI probe): stamping a blueprint can break the 800-ink cap, and the next launch then deletes both weapon and shield.**
   - `stampBlueprint` (lib/core/bots.dart:252-261) keeps the last stroke even when it is still over `inkLeft`. The scale floor is 0.3, and nothing is scaled when inkLeft <= 0. With 10 ink left it returns 60-100 ink.
   - `_pickBlueprint` (lib/ui/screens/draw_screen.dart:219-221) does not check the ink left, and `saveGear` (lib/state/game_controller.dart:97-101) has no cap.
   - `fromJson` (lib/core/save_data.dart:109-112) clears both w and s once their total is over 830.
   - Probe: 780-ink weapon, pick "Khiên tròn", tap "Lưu đồ". The shield is saved at 79 ink; on reload w=0 and s=0.
   - Fix: cut the stamp to fit (or refuse it and flash the ink tube), clamp in saveGear, and trim rather than wipe in fromJson.
2. **HIGH, CONFIRMED (widget probe plus Flame and engine source): the battle swallows every key, which breaks Android volume and back buttons.**
   - `BattleGame.onKeyEvent` (lib/game/battle_game.dart:113-122) returns `handled` for every key while the autofocused GameWidget has focus.
   - Flutter's Android FlutterView only passes on keys the app leaves unhandled. So in battle the hardware volume keys do nothing.
   - On Android 15 and older, back never reaches the battle PopScope, because the manifest has no `enableOnBackInvokedCallback`.
   - Each key event also resets inFwd/inBack/inBlock from the keyboard state. Probe: holding ĐỠ and pressing volume dropped the shield (inBlock=false); goBack returned `handled`.
   - Fix: return `ignored` for keys the game does not use, and keep keyboard flags separate from pad flags (OR them).
3. **MEDIUM, CONFIRMED (UI probe): a weapon stroke drawn past the canvas is deleted on the next launch.**
   - Weapon strokes have no bounds. The Listener keeps delivering moves after the finger leaves the canvas, and `_inZone` is always true for the weapon (draw_screen.dart:89-90 and 108-137).
   - `cleanStrokes` (save_data.dart:135) rejects the whole drawing if any coordinate is over 420.
   - Probe: drag from the hand up to the top of the screen, save, reload. The saved stroke reaches |y|=515.7, and after reload w=0. A long spear drawn up into the header area is lost on restart.
   - Fix: end the stroke when it leaves the canvas or passes 420, and have the sanitizer clamp or drop bad points instead of the whole drawing.
4. **LOW, CONFIRMED (UI probe): the pads still work while the battle is paused.** The pad row (lib/ui/screens/battle_screen.dart:159-210) is outside the paused Stack. Tapping ĐÁNH with the pause menu open moved the player from idle to windup (`pressAttack`, lib/core/battle/battle.dart:179), so a swing can be queued from a frozen frame. Fix: wrap the pads in `IgnorePointer(ignoring: held)`, or add a paused guard to pressAttack.
5. **LOW, CONFIRMED (UI probe): system back on the first-time shield step loses the new weapon.** On the draw screen, system back goes through `Nav.back` (lib/app.dart:71-72), not `_back` (draw_screen.dart:168-177). On the shield step of the first-time flow it goes home and the unsaved weapon is lost (probe: scr=home, hasGear=false). Fix: give DrawScreen a PopScope that calls `_back()`.
6. **LOW, CONFIRMED (code): the special-ink gradient goes stale in the editor.** `farPoint` (lib/render/fighter_painter.dart:681-699) caches by list identity and never refreshes. The editor changes `w` in place, so the gradient keeps the first tip while the user draws, usually the default (0,-60). The web version keyed this cache on stroke count and last stroke length. Fix: use that key, or skip the cache while editing.
7. **LOW, CONFIRMED (code): text outlines never fade.** The `textPainter` cache key (lib/render/text_fx.dart:9) leaves out the outline paint's alpha, so outlines (text_fx.dart:36-40) never fade. "BỐP!" keeps an opaque dark outline while its text fades. After the 400-entry cache clear, an outline can also be cached half transparent for later pops. Fix: add alpha to the key, or fade with `saveLayer`.
8. **LOW, CONFIRMED (code): the winner freezes mid-taunt after the match.** `step` returns at once when the phase is done (lib/core/battle/battle.dart:650), so the winner stops mid-taunt behind the result card; the web game kept animating. Fix: keep advancing taunt time and poses after the match ends, without running the arena rules.
9. **LOW, PLAUSIBLE: a speech bubble can crash rendering on a very narrow screen.** In `drawBubble` (text_fx.dart:51), `clamp` throws an ArgumentError when the canvas is narrower than the bubble plus 8 px, so render throws every frame. Example: a narrow web window showing "Zzz… buồn ngủ quá.". Fix: centre the bubble when the lower limit is above the upper.

## Unresolved
- Finding 2's back-key loss is traced through the FlutterView/KeyboardManager source and not tried on a device; it needs an Android 13-15 device. The volume part is confirmed by the probe.
- Another session was editing lib/ui during the review. Re-check the line numbers in findings 1, 3, 4 and 5 before fixing.
