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
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
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