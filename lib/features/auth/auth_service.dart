import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();


  // Email login
  Future<UserCredential> signIn(
      String email,
      String password,
      ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }


  // Register
  Future<UserCredential> register(
      String email,
      String password,
      ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // The account now exists, but shouldn't grant full app access
    // until this link is clicked — see AuthGate, which checks
    // user.emailVerified separately from just "is a user signed in
    // at all".
    await credential.user?.sendEmailVerification();
    return credential;
  }

  /// Re-fetches the current user's latest emailVerified status from
  /// Firebase's servers. The LOCAL, cached User object does NOT
  /// update on its own when the person clicks the link elsewhere
  /// (e.g. in their email client) — this must be called explicitly
  /// (e.g. from a "Check again" button, or a periodic timer) to
  /// notice a verification that already happened.
  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Resends the verification email — e.g. from a "Resend" button if
  /// the original was lost, expired, or landed in spam.
  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }


  // Google login
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      return null;
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential =  GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(
      credential,
    );
  }


  // Reset password
  Future<void> resetPassword(
      String email,
      ) async {

    await _auth.sendPasswordResetEmail(
      email: email,
    );

  }


  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}