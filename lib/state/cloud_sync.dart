import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../core/save_data.dart';
import '../core/save_merge.dart';
import '../monetize/cloud_service.dart';
import 'game_controller.dart';

/// Keeps the save on this phone and the copy in the cloud in step.
///
/// The phone's save is the one the game plays with. Once per session and account, the
/// server's copy is merged into it (see [mergeSaves]); after that, changes are sent up a few
/// seconds later. Every upload names the revision it was based on, so if another phone wrote
/// in between, its save is merged first and the upload tried again. Nothing is sent before
/// the first merge, and nothing waits in a queue, so a phone that was offline can never
/// overwrite a better cloud save.
class CloudSync extends ChangeNotifier {
  CloudSync({required this.game, required this.cloud, this.onAccount, this.debounce = const Duration(seconds: 8)});

  /// No cloud: the web build and widget tests.
  factory CloudSync.none(GameController game) => CloudSync(game: game, cloud: NoCloud());

  final GameController game;
  final CloudService cloud;

  /// Called after a merge with the player's id when it is new or changed. The store signs
  /// in with it, so purchases follow the player.
  final Future<void> Function(String uid)? onAccount;

  final Duration debounce;

  /// True while a match or the editor is open. A merge would swap the save under them, so it
  /// waits until [idle].
  bool Function() busy = _never;

  static bool _never() => false;

  String? _mergedFor, _sent;
  int _rev = 0;
  Future<void>? _connecting, _pushing;
  bool _pushAgain = false, _switching = false, _started = false;
  Timer? _timer;

  bool get enabled => cloud.available;

  bool get canLink => cloud.canLink;

  bool get linked => cloud.linked;

  String? get accountName => cloud.accountName;

  /// The cloud copy has been merged this session, so the save is backed up from now on.
  bool get synced => !_switching && _mergedFor != null && _mergedFor == cloud.uid;

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
    if (!enabled || _switching) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  /// Call when a match or the editor closes: runs a merge or an upload that waited.
  void idle() {
    unawaited(connect());
    unawaited(push());
  }

  Future<void> _connect() async {
    try {
      await cloud.init();
      // The account can change while the server answers (a link or a deletion).
      for (var tries = 0; tries < 3; tries++) {
        final uid = cloud.uid;
        if (uid == null || uid == _mergedFor || busy()) return;
        final doc = await cloud.download();
        if (cloud.uid != uid) continue;
        if (busy()) return;
        _adopt(uid, doc);
        _mergedFor = uid;
        await onAccount?.call(uid);
        if (cloud.uid != uid) continue;
        unawaited(push());
        return;
      }
    } catch (_) {
      // Offline or Firebase not set up for this phone: keep playing on the local save.
    } finally {
      notifyListeners();
    }
  }

  static SaveData? _parse(String? json) {
    if (json == null) return null;
    try {
      return SaveData.fromJson(jsonDecode(json));
    } on FormatException {
      return null;
    }
  }

  /// Merges a cloud document into the phone's save. A document that cannot be read counts
  /// as missing, and the next upload replaces it.
  void _adopt(String uid, CloudDoc? doc) {
    _rev = doc?.rev ?? 0;
    _sent = doc?.json;
    final cloudSave = _parse(doc?.json);
    final merged = cloudSave == null
        ? (SaveData.fromJson(game.save.toJson())..account = uid)
        : mergeSaves(game.save, cloudSave, uid: uid);
    if (jsonEncode(merged.toJson()) != jsonEncode(game.save.toJson())) game.replaceSave(merged);
  }

  void _schedule() {
    if (!synced) return;
    _timer?.cancel();
    _timer = Timer(debounce, push);
  }

  /// Sends the save now if it changed since the last upload (also used when the app goes
  /// to the background). Uploads never overlap.
  Future<void> push() {
    _timer?.cancel();
    if (!synced) return Future.value();
    final running = _pushing;
    if (running != null) {
      _pushAgain = true;
      return running;
    }
    return _pushing = _push().whenComplete(() {
      _pushing = null;
      if (_pushAgain) {
        _pushAgain = false;
        unawaited(push());
      }
    });
  }

  Future<void> _push() async {
    for (var tries = 0; tries < 3; tries++) {
      final uid = cloud.uid;
      if (!synced || uid == null) return;
      final json = jsonEncode(game.save.toJson());
      if (json == _sent) return;
      try {
        final rev = await cloud.upload(json, _rev);
        if (cloud.uid != uid) return;
        _rev = rev;
        _sent = json;
        return;
      } on CloudConflict catch (c) {
        // Another phone saved since this one last looked: merge its save, then try again.
        // During a match the merge waits for [idle].
        if (cloud.uid != uid || !synced || busy()) return;
        _adopt(uid, c.newer);
      } catch (_) {
        return; // Offline: the next change, resume or idle tries again.
      }
    }
  }

  /// Stops uploads and waits for running work before the account changes.
  Future<void> _beginSwitch() async {
    final connecting = _connecting;
    if (connecting != null) await connecting;
    _switching = true;
    _timer?.cancel();
    final pushing = _pushing;
    if (pushing != null) await pushing;
  }

  void _forgetAccount() {
    _mergedFor = null;
    _sent = null;
    _rev = 0;
  }

  /// Links a Google account. If that account already has a player (an earlier install or
  /// another phone), the game switches to it and merges its save with this one.
  Future<LinkOutcome> linkGoogle() async {
    await _beginSwitch();
    final LinkOutcome r;
    try {
      r = await cloud.linkGoogle();
      if (r is LinkedSwitched) _forgetAccount();
    } finally {
      _switching = false;
    }
    await connect();
    notifyListeners();
    return r;
  }

  /// Deletes the cloud save and the account. The save on this phone stays and is backed up
  /// under a new anonymous account.
  Future<DeleteResult> deleteAccount() async {
    await _beginSwitch();
    final DeleteResult r;
    try {
      r = await cloud.deleteAccount();
      if (r == DeleteResult.deleted) _forgetAccount();
    } finally {
      _switching = false;
    }
    await connect();
    if (r != DeleteResult.deleted) _schedule();
    notifyListeners();
    return r;
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
