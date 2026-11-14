import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_service.dart';

/// Firebase settings, passed with `--dart-define` (see keys.example.json and
/// docs/luu-tren-may.md).
abstract final class FirebaseConfig {
  static const projectId = String.fromEnvironment('FB_PROJECT_ID');
  static const apiKey = String.fromEnvironment('FB_API_KEY');
  static const senderId = String.fromEnvironment('FB_SENDER_ID');
  static const appIdAndroid = String.fromEnvironment('FB_APP_ID_ANDROID');
  static const appIdIos = String.fromEnvironment('FB_APP_ID_IOS');

  /// OAuth client of type "Web application" in the Firebase project. Google sign-in on
  /// Android needs it to hand Firebase an ID token.
  static const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// OAuth client for the iOS app (iOS only).
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static String get appId => Platform.isIOS ? appIdIos : appIdAndroid;

  static bool get complete => projectId.isNotEmpty && apiKey.isNotEmpty && senderId.isNotEmpty && appId.isNotEmpty;

  static bool get googleReady => Platform.isIOS ? iosClientId.isNotEmpty : serverClientId.isNotEmpty;
}

/// Firebase Auth (anonymous, then linked to Google) and one Firestore document per player,
/// `players/{uid}` = {save: JSON string, rev: int, updatedAt}.
///
/// Firestore's offline copy is switched off and every write is a transaction, so a read
/// always reflects the server and no write waits in a queue to land later over another
/// phone's save.
class FirebaseCloud extends CloudService {
  bool _started = false;
  Future<void>? _googleInit;
  User? _user;
  StreamSubscription<User?>? _sub;

  static const _timeout = Duration(seconds: 15);

  FirebaseAuth get _auth => FirebaseAuth.instance;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('players').doc(uid);

  @override
  bool get available => FirebaseConfig.complete;

  @override
  bool get canLink => available && FirebaseConfig.googleReady;

  @override
  String? get uid => _user?.uid;

  Iterable<UserInfo> get _google => _user?.providerData.where((p) => p.providerId == 'google.com') ?? const [];

  @override
  bool get linked => _google.isNotEmpty;

  @override
  String? get accountName => _google.isEmpty ? null : (_google.first.email ?? _google.first.displayName);

  @override
  Future<void> init() async {
    if (!available) return;
    if (!_started) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: FirebaseConfig.apiKey,
          appId: FirebaseConfig.appId,
          messagingSenderId: FirebaseConfig.senderId,
          projectId: FirebaseConfig.projectId,
          iosClientId: FirebaseConfig.iosClientId.isEmpty ? null : FirebaseConfig.iosClientId,
        ),
      );
      _db.settings = const Settings(persistenceEnabled: false);
      _started = true;
      _sub = _auth.userChanges().listen((u) {
        _user = u;
        notifyListeners();
      });
    }
    _user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    notifyListeners();
  }

  static CloudDoc _docOf(Map<String, dynamic>? data) {
    final save = data?['save'], rev = data?['rev'];
    return CloudDoc(save is String ? save : null, rev is num ? rev.toInt() : 0);
  }

  @override
  Future<CloudDoc?> download() async {
    final id = uid;
    if (id == null) return null;
    final snap = await _doc(id).get(const GetOptions(source: Source.server)).timeout(_timeout);
    return snap.exists ? _docOf(snap.data()) : null;
  }

  @override
  Future<int> upload(String json, int rev) async {
    final id = uid;
    if (id == null) throw StateError('not signed in');
    final ref = _doc(id);
    CloudDoc? newer;
    final written = await _db.runTransaction<int>((tx) async {
      newer = null;
      final snap = await tx.get(ref);
      final now = snap.exists ? _docOf(snap.data()) : null;
      final current = now?.rev ?? 0;
      if (current != rev) {
        newer = now ?? const CloudDoc(null, 0);
        return current;
      }
      tx.set(ref, {'save': json, 'rev': current + 1, 'updatedAt': FieldValue.serverTimestamp()});
      return current + 1;
    }, timeout: _timeout);
    final conflict = newer;
    if (conflict != null) throw CloudConflict(conflict);
    return written;
  }

  /// Deletes a document through a transaction, so it fails at once offline instead of
  /// waiting in a queue.
  Future<void> _deleteDoc(String id) => _db.runTransaction<void>((tx) async => tx.delete(_doc(id)), timeout: _timeout);

  Future<void> _initGoogle() async {
    final pending = _googleInit ??= GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS && FirebaseConfig.iosClientId.isNotEmpty ? FirebaseConfig.iosClientId : null,
      serverClientId: FirebaseConfig.serverClientId.isEmpty ? null : FirebaseConfig.serverClientId,
    );
    try {
      await pending;
    } catch (_) {
      _googleInit = null;
      rethrow;
    }
  }

  /// Asks the player to pick a Google account. Null when Google gave no ID token.
  Future<OAuthCredential?> _googleCredential() async {
    await _initGoogle();
    final idToken = (await GoogleSignIn.instance.authenticate()).authentication.idToken;
    return idToken == null ? null : GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<LinkOutcome> linkGoogle() async {
    final user = _started ? _auth.currentUser : null;
    if (user == null) return const LinkFailed('Chưa kết nối được máy chủ. Kiểm tra mạng rồi thử lại.');
    if (!canLink) return const LinkFailed('Bản này chưa cài đặt đăng nhập Google.');
    try {
      final cred = await _googleCredential();
      if (cred == null) return const LinkFailed('Google không trả về thông tin đăng nhập. Thử lại sau nhé.');
      try {
        await user.linkWithCredential(cred);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use') rethrow;
        // This Google account already has a player. The save on this phone holds everything
        // and is merged next, so drop this phone's anonymous account and its cloud copy
        // rather than leave them behind, then continue as that player.
        try {
          await _deleteDoc(user.uid);
          await user.delete();
        } on Exception {
          // Best effort: the switch matters more than the clean-up.
        }
        await _auth.signInWithCredential(e.credential ?? cred);
        _user = _auth.currentUser;
        notifyListeners();
        return const LinkedSwitched();
      }
      try {
        await user.reload();
      } on Exception {
        // The link went through; the name in settings updates on the next start.
      }
      _user = _auth.currentUser;
      notifyListeners();
      return const LinkedSame();
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled
          ? const LinkCancelled()
          : LinkFailed('Đăng nhập Google không thành công (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      return LinkFailed('Liên kết không thành công (${e.code}). Kiểm tra mạng rồi thử lại.');
    }
  }

  @override
  Future<DeleteResult> deleteAccount() async {
    final user = _started ? _auth.currentUser : null;
    if (user == null) return DeleteResult.failed;
    try {
      // A server read first, so being offline fails at once instead of half-way through.
      await _doc(user.uid).get(const GetOptions(source: Source.server)).timeout(_timeout);
      // Firebase asks a linked player to sign in again before deleting the account. Ask
      // first, so nothing is deleted if they cancel.
      if (linked) {
        final cred = await _googleCredential();
        if (cred == null) return DeleteResult.failed;
        await user.reauthenticateWithCredential(cred);
      }
      await _deleteDoc(user.uid);
      await user.delete().timeout(_timeout);
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled ? DeleteResult.cancelled : DeleteResult.failed;
    } on Exception {
      return DeleteResult.failed;
    }
    // The account is gone. Start a new anonymous one now, or on the next connect if offline.
    _user = null;
    if (_googleInit != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } on Exception {
        // Only clears the account Google remembers for the next sign-in.
      }
    }
    try {
      _user = (await _auth.signInAnonymously()).user;
    } on Exception {
      // Signed out for now; CloudSync signs in again when it next connects.
    }
    notifyListeners();
    return DeleteResult.deleted;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
