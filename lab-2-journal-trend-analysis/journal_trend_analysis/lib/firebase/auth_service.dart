import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'analytics_service.dart';

class AuthService {
  AuthService(this._auth, this._analytics);

  final FirebaseAuth _auth;
  final AnalyticsService _analytics;
  final GoogleSignIn _google = GoogleSignIn.instance;
  late final Future<void> _googleReady = _google.initialize();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    await _googleReady;
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw StateError('Google did not return an ID token.');

    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    await _analytics.login();
  }

  Future<void> signOut() async {
    await _analytics.logout();
    await _auth.signOut();
    await _googleReady;
    await _google.signOut();
  }
}
