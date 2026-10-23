import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static Future<void>? _googleInitialization;
  static bool _googleInitialized = false;

  final FirebaseAuth? _providedAuth;

  AuthService({FirebaseAuth? auth}) : _providedAuth = auth;

  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<User?> get userChanges => _auth.userChanges();

  Future<void> signInWithGoogle() async {
    final credential = await _authenticateGoogleCredential();
    await _auth.signInWithCredential(credential);
  }

  Future<User> linkGoogleAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('A signed-in user is required.');

    final credential = await _authenticateGoogleCredential();
    final result = await user.linkWithCredential(credential);
    final linkedUser = result.user;
    if (linkedUser == null) {
      throw StateError('Google was linked without returning a user.');
    }
    return linkedUser;
  }

  Future<void> reauthenticateWithGoogle(User user) async {
    // Reauthentication must use a fresh Google credential. Clearing the
    // Google Sign-In session also lets the user choose the account linked to
    // this Firebase user instead of silently reusing a different account.
    await _initializeGoogleSignIn();
    await GoogleSignIn.instance.signOut();
    final credential = await _authenticateGoogleCredential();
    await user.reauthenticateWithCredential(credential);
  }

  Future<OAuthCredential> _authenticateGoogleCredential() async {
    await _initializeGoogleSignIn();
    final googleUser = await GoogleSignIn.instance.authenticate();
    return _googleCredential(googleUser);
  }

  Future<void> _initializeGoogleSignIn() =>
      _googleInitialization ??= GoogleSignIn.instance.initialize().then((_) {
        _googleInitialized = true;
      });

  Future<OAuthCredential> _googleCredential(
    GoogleSignInAccount googleUser,
  ) async {
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google Sign-In did not return an ID token. Check the OAuth client '
        'configuration for this app.',
      );
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> createAccount({
    required String username,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Account creation succeeded without a Firebase user.');
    }
    await user.updateDisplayName(username.trim());
  }

  Future<void> updateProfile({required String username}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('A signed-in user is required.');

    await user.updateDisplayName(username.trim());
    await user.reload();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('A signed-in email/password user is required.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    if (_googleInitialized) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
