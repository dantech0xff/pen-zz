import 'package:flutter/foundation.dart';

sealed class LinkOutcome {
  const LinkOutcome();
}

/// The Google account is now linked to this player; the player id stays the same.
class LinkedSame extends LinkOutcome {
  const LinkedSame();
}

/// The Google account already belonged to a player (an earlier install or another phone),
/// so the game signed in as that player. Its cloud save has to be merged next.
class LinkedSwitched extends LinkOutcome {
  const LinkedSwitched();
}

class LinkCancelled extends LinkOutcome {
  const LinkCancelled();
}

class LinkFailed extends LinkOutcome {
  const LinkFailed(this.message);

  final String message;
}

/// The player's account and cloud save as the game sees them. The Firebase version runs
/// on Android and iOS; [NoCloud] is used on the web build, in tests, and when the build has
/// no Firebase settings.
abstract class CloudService extends ChangeNotifier {
  /// This build has Firebase settings.
  bool get available;

  /// The signed-in player, or null before the first sign-in (for example offline).
  String? get uid;

  /// A Google account is linked, so the save survives a reinstall or a new phone.
  bool get linked;

  /// The linked Google account, for the settings screen.
  String? get accountName;

  /// Starts Firebase and signs in, anonymously on the first run. Throws when unreachable.
  Future<void> init();

  /// The cloud save as JSON, or null when this player has none. Throws when unreachable.
  Future<String?> download();

  Future<void> upload(String json);

  Future<LinkOutcome> linkGoogle();

  /// Deletes the cloud save and the account, then starts a new anonymous one.
  /// Returns false when it could not be done.
  Future<bool> deleteAccount();
}

class NoCloud extends CloudService {
  @override
  bool get available => false;

  @override
  String? get uid => null;

  @override
  bool get linked => false;

  @override
  String? get accountName => null;

  @override
  Future<void> init() async {}

  @override
  Future<String?> download() async => null;

  @override
  Future<void> upload(String json) async {}

  @override
  Future<LinkOutcome> linkGoogle() async => const LinkFailed('Bản này chưa bật lưu trên mây.');

  @override
  Future<bool> deleteAccount() async => false;
}
