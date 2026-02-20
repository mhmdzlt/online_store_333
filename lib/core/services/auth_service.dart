import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String mobileRedirectUrl =
      'com.example.onlinestore333://login-callback/';

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<bool> ensureSignedInWithGoogle({bool triggerLogin = true}) async {
    if (_client.auth.currentUser != null) {
      return true;
    }
    if (!triggerLogin) {
      return false;
    }

    await signInWithGoogle();
    return _client.auth.currentUser != null;
  }

  Future<void> signInWithGoogle() async {
    final redirectTo = _shouldUseMobileRedirect ? mobileRedirectUrl : null;

    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  bool get _shouldUseMobileRedirect {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
