import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Short sound effects, rendered offline from the web game's synthesizer (tool/gen-sfx.py).
/// Failures are swallowed: a missing sound must never break a match.
class Sfx {
  Sfx._();

  static final Sfx instance = Sfx._();

  static const List<String> ids = [
    'whoosh', 'hit', 'block', 'parry', 'fall', 'coin', 'lvup', 'win', 'lose', //
    'tap', 'buy', 'star', 'freeze', 'burn', 'zap', 'heal', 'crumble',
  ];

  bool enabled = true;
  final Map<String, AudioPool> _pools = {};
  final Set<String> _loading = {};

  PlayerMode get _mode =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? PlayerMode.lowLatency : PlayerMode.mediaPlayer;

  Future<void> _load(String id) async {
    if (_pools.containsKey(id) || !_loading.add(id)) return;
    try {
      _pools[id] = await AudioPool.create(
        source: AssetSource('$id.wav'),
        audioCache: FlameAudio.audioCache,
        maxPlayers: id == 'hit' || id == 'whoosh' || id == 'block' ? 4 : 2,
        playerMode: _mode,
        audioContext: AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (_) {
      // Audio may be unavailable (tests, muted web tab); the game runs silently.
    } finally {
      _loading.remove(id);
    }
  }

  Future<void> preload() async {
    for (final id in ids) {
      await _load(id);
    }
  }

  void play(String id, {double volume = 1}) {
    if (!enabled) return;
    final pool = _pools[id];
    if (pool == null) {
      _load(id);
      return;
    }
    pool.start(volume: volume).catchError((Object _) async => () async {});
  }
}

/// Vibration feedback on hits and parries (no-op where unsupported).
class Haptics {
  Haptics._();

  static final Haptics instance = Haptics._();
  bool enabled = true;

  void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
