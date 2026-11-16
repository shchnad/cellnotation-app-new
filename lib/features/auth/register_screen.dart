import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(text, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  Future<void> register() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      loading = true;
    });
    try {
      await _authService.register(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      if (mounted) {
        _message('Verification email sent — check your inbox.');
        // popUntil, not a plain pop — RegisterScreen may have been
        // reached via a pushed route on top of AuthGate. Registering
        // signs the new user in right away, so AuthGate's own
        // StreamBuilder is about to show VerifyEmailScreen — but
        // UNDERNEATH whatever is pushed on top of it. Clearing back to
        // the root guarantees AuthGate's content is what becomes
        // visible.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      _message(e.toString());
    }
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  // Navigator.pop, not push — RegisterScreen was reached BY pushing
  // from LoginScreen (via "Create account"), so going back returns to
  // that SAME instance. Pushing a new LoginScreen instead would stack a
  // duplicate route on top of AuthGate, and a later successful sign-in
  // on that copy would look like it failed.
  void _backToLogin() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // true so the card moves up above the keyboard and a focused
      // field (e.g. Password, in landscape) is never hidden under it.
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        title: 'Cellnotation',
        subtitle: 'enjoy the music playing',
        // BACK TO LOGIN — a small round button with an arrow in the
        // top-left corner of the card.
        // topLeft: AuthBackButton(
        //   tooltip: 'Back to Login',
        //   onTap: _backToLogin,
        // ),
        children: [
          AuthField(
            controller: emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            onClear: () => setState(emailController.clear),
          ),
          const SizedBox(height: 18),
          AuthField(
            controller: passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            onToggleObscure: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!loading) register();
            },
            onClear: () => setState(passwordController.clear),
          ),
          const SizedBox(height: 28),

          AuthMainButton(
            label: 'Create Account',
            loading: loading,
            onPressed: register,
          ),

          const SizedBox(height: 22),

          // ALREADY HAVE AN ACCOUNT — a link back to login, as well as
          // the arrow button at the top.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(fontSize: 22, color: Colors.black54),
              ),
              TextButton(
                onPressed: loading ? null : _backToLogin,
                child: const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: authBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}