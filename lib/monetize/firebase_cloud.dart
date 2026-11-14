import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_service.dart';

/// Firebase settings, passed with `--dart-define`. See docs/luu-tren-may.md.
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
}

/// Firebase Auth (anonymous, then linked to Google) and one Firestore document per player,
/// `players/{uid}`, holding the save as a JSON string.
class FirebaseCloud extends CloudService {
  bool _started = false, _googleReady = false;
  User? _user;
  StreamSubscription<User?>? _sub;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => FirebaseFirestore.instance.collection('players').doc(uid);

  @override
  bool get available => FirebaseConfig.complete;

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
      _started = true;
      _sub = _auth.userChanges().listen((u) {
        _user = u;
        notifyListeners();
      });
    }
    _user = _auth.currentUser ?? (await _auth.signInAnonymously()).user;
    notifyListeners();
  }

  @override
  Future<String?> download() async {
    final id = uid;
    if (id == null) return null;
    final data = (await _doc(id).get()).data();
    final save = data?['save'];
    return save is String ? save : null;
  }

  @override
  Future<void> upload(String json) async {
    final id = uid;
    if (id == null) return;
    await _doc(id).set({'save': json, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Asks the player to pick a Google account. Null when Google gave no ID token.
  Future<OAuthCredential?> _googleCredential() async {
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS && FirebaseConfig.iosClientId.isNotEmpty ? FirebaseConfig.iosClientId : null,
        serverClientId: FirebaseConfig.serverClientId.isEmpty ? null : FirebaseConfig.serverClientId,
      );
      _googleReady = true;
    }
    final idToken = (await GoogleSignIn.instance.authenticate()).authentication.idToken;
    return idToken == null ? null : GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<LinkOutcome> linkGoogle() async {
    final user = _started ? _auth.currentUser : null;
    if (user == null) return const LinkFailed('Chưa kết nối được máy chủ. Kiểm tra mạng rồi thử lại.');
    try {
      final cred = await _googleCredential();
      if (cred == null) return const LinkFailed('Google không trả về thông tin đăng nhập. Thử lại sau nhé.');
      try {
        await user.linkWithCredential(cred);
        await user.reload();
        _user = _auth.currentUser;
        notifyListeners();
        return const LinkedSame();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use') rethrow;
        // This Google account already has a player: continue as that player.
        await _auth.signInWithCredential(e.credential ?? cred);
        _user = _auth.currentUser;
        notifyListeners();
        return const LinkedSwitched();
      }
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled
          ? const LinkCancelled()
          : LinkFailed('Đăng nhập Google không thành công (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      return LinkFailed('Liên kết không thành công (${e.code}).');
    }
  }

  @override
  Future<bool> deleteAccount() async {
    final user = _started ? _auth.currentUser : null;
    if (user == null) return false;
    try {
      await _doc(user.uid).delete();
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        // Firebase asks a linked player to sign in again before deleting the account.
        if (e.code != 'requires-recent-login') rethrow;
        final cred = await _googleCredential();
        if (cred == null) return false;
        await user.reauthenticateWithCredential(cred);
        await user.delete();
      }
      if (_googleReady) await GoogleSignIn.instance.signOut();
      _user = (await _auth.signInAnonymously()).user;
      notifyListeners();
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
