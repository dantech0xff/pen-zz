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

enum DeleteResult { deleted, cancelled, failed }

/// A player's cloud document: the save as JSON and its revision, which goes up by one with
/// every write. [json] is null when the document holds no readable save.
class CloudDoc {
  const CloudDoc(this.json, this.rev);

  final String? json;
  final int rev;
}

/// Another phone wrote the document after this phone last read it; [newer] is what is
/// there now. Nothing was written.
class CloudConflict implements Exception {
  const CloudConflict(this.newer);

  final CloudDoc newer;
}

/// The player's account and cloud save as the game sees them. The Firebase version runs
/// on Android and iOS; [NoCloud] is used on the web build, in tests, and when the build has
/// no Firebase settings.
abstract class CloudService extends ChangeNotifier {
  /// This build has Firebase settings.
  bool get available;

  /// Google sign-in is set up in this build, so a Google account can be linked.
  bool get canLink;

  /// The signed-in player, or null before the first sign-in (for example offline).
  String? get uid;

  /// A Google account is linked, so the save survives a reinstall or a new phone.
  bool get linked;

  /// The linked Google account, for the settings screen.
  String? get accountName;

  /// Starts Firebase and signs in, anonymously on the first run. Throws when unreachable.
  Future<void> init();

  /// Reads the player's document from the server, never from a copy kept on the phone.
  /// Null when the player has none. Throws when the server cannot be reached.
  Future<CloudDoc?> download();

  /// Writes [json] if the document is still at revision [rev] (0 when there was none) and
  /// returns the new revision. Throws [CloudConflict] when another phone wrote first, and
  /// another error when the server cannot be reached; nothing is queued for later.
  Future<int> upload(String json, int rev);

  Future<LinkOutcome> linkGoogle();

  /// Deletes the cloud save and the account, then starts a new anonymous account.
  Future<DeleteResult> deleteAccount();
}

class NoCloud extends CloudService {
  @override
  bool get available => false;

  @override
  bool get canLink => false;

  @override
  String? get uid => null;

  @override
  bool get linked => false;

  @override
  String? get accountName => null;

  @override
  Future<void> init() async {}

  @override
  Future<CloudDoc?> download() async => null;

  @override
  Future<int> upload(String json, int rev) async => rev;

  @override
  Future<LinkOutcome> linkGoogle() async => const LinkFailed('Bản này chưa bật lưu trên mây.');

  @override
  Future<DeleteResult> deleteAccount() async => DeleteResult.failed;
}
