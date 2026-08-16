import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../screens/home_screen.dart';
import 'auth_service.dart';

/// Shown by AuthGate whenever a signed-in user's email isn't verified
/// yet (see AuthGate — user != null but !user.emailVerified). Polls
/// Firebase every few seconds so the app notices on its own the
/// moment the person clicks the link in their email, without
/// requiring a manual "Check again" tap — though that's offered too,
/// for anyone who doesn't want to wait for the next poll.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();
  Timer? _pollTimer;
  bool _checking = false;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkVerified(showResultIfNotVerified: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified({bool showResultIfNotVerified = true}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
    });

    final verified = await _authService.checkEmailVerified();

    if (!mounted) return;

    if (verified) {
      _pollTimer?.cancel();
      // authStateChanges() never fires again for just an
      // emailVerified change (only actual sign-in/out), so AuthGate's
      // own StreamBuilder won't notice this on its own — navigate to
      // HomeScreen explicitly instead of waiting on it.
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Account Created',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Your email has been verified and your account is ready.',
            style: TextStyle(fontSize: 22),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    setState(() {
      _checking = false;
    });

    if (showResultIfNotVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Not verified yet — check your inbox and click the link.",
            style: TextStyle(fontSize: 22),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 500,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "We've sent a verification link to:\n$email\n\n"
                      "Please check your inbox and click the link to "
                      "activate your account. This page will update "
                      "automatically once it's verified.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: 300,
                  child: ElevatedButton(
                    onPressed: _checking
                        ? null
                        : () => _checkVerified(showResultIfNotVerified: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: _checking
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : const Text(
                      "I've Verified — Continue",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: 300,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _authService.resendVerificationEmail();
                      if (!mounted) return;
                      setState(() {
                        _resent = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Verification email resent.',
                            style: TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      _resent ? 'Email Resent' : 'Resend Email',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: 300,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _authService.signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}