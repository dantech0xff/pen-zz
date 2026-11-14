import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../core/save_data.dart';
import '../core/save_merge.dart';
import '../monetize/cloud_service.dart';
import 'game_controller.dart';

/// Keeps the save on this phone and the copy in the cloud in step.
///
/// The save on the phone stays the one the game plays with; the cloud copy is merged into
/// it once per session and player (see [mergeSaves]), and every change after that is sent
/// up after a short pause. Nothing is uploaded before that merge, so an offline start can
/// never overwrite a better cloud save.
class CloudSync extends ChangeNotifier {
  CloudSync({required this.game, required this.cloud, this.onAccount, this.debounce = const Duration(seconds: 8)});

  /// No cloud: the web build and widget tests.
  factory CloudSync.none(GameController game) => CloudSync(game: game, cloud: NoCloud());

  final GameController game;
  final CloudService cloud;

  /// Called after the cloud copy is merged, with the player's id, whenever it is new or
  /// changed. The store signs in with it, so purchases follow the player.
  final Future<void> Function(String uid)? onAccount;

  final Duration debounce;

  String? _mergedFor, _sent;
  Future<void>? _connecting;
  Timer? _timer;
  bool _started = false;

  bool get enabled => cloud.available;

  bool get linked => cloud.linked;

  String? get accountName => cloud.accountName;

  /// The cloud copy has been merged this session, so the save is backed up from now on.
  bool get synced => _mergedFor != null && _mergedFor == cloud.uid;

  Future<void> init() async {
    if (!enabled || _started) return;
    _started = true;
    game.addListener(_schedule);
    cloud.addListener(notifyListeners);
    await connect();
  }

  /// Signs in and merges with the cloud copy if that has not happened yet; call again when
  /// the app comes back to the foreground. Failures (offline) leave the phone's save as is.
  Future<void> connect() {
    if (!enabled) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    try {
      await cloud.init();
      final uid = cloud.uid;
      if (uid == null || uid == _mergedFor) return;
      final raw = await cloud.download();
      if (raw != null) {
        final merged = mergeSaves(game.save, SaveData.fromJson(jsonDecode(raw)));
        _sent = raw;
        if (jsonEncode(merged.toJson()) != jsonEncode(game.save.toJson())) game.replaceSave(merged);
      }
      _mergedFor = uid;
      await onAccount?.call(uid);
      await push();
    } catch (_) {
      // Offline or Firebase not set up for this phone: keep playing on the local save.
    } finally {
      notifyListeners();
    }
  }

  void _schedule() {
    if (!synced) return;
    _timer?.cancel();
    _timer = Timer(debounce, push);
  }

  /// Sends the save now if it changed since the last upload (also used when the app goes
  /// to the background).
  Future<void> push() async {
    _timer?.cancel();
    if (!synced) return;
    final json = jsonEncode(game.save.toJson());
    if (json == _sent) return;
    _sent = json;
    try {
      await cloud.upload(json);
    } catch (_) {
      _sent = null;
    }
  }

  /// Links a Google account. If that account already has a player (an earlier install or
  /// another phone), the game switches to it and merges its save with this one.
  Future<LinkOutcome> linkGoogle() async {
    await push();
    final r = await cloud.linkGoogle();
    if (r is LinkedSwitched) {
      _mergedFor = null;
      await connect();
    }
    notifyListeners();
    return r;
  }

  /// Deletes the cloud save and the account. The save on this phone stays and is backed up
  /// under a new anonymous account.
  Future<bool> deleteAccount() async {
    final ok = await cloud.deleteAccount();
    if (ok) {
      _mergedFor = null;
      _sent = null;
      await connect();
    }
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_started) {
      game.removeListener(_schedule);
      cloud.removeListener(notifyListeners);
    }
    super.dispose();
  }
}

class CloudScope extends InheritedNotifier<CloudSync> {
  const CloudScope({super.key, required CloudSync sync, required super.child}) : super(notifier: sync);

  static CloudSync of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<CloudScope>()!.notifier!;

  static CloudSync read(BuildContext context) => context.getInheritedWidgetOfExactType<CloudScope>()!.notifier!;
}
