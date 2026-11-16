import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

  Future<void> login() async {
    // Dismiss the on-screen keyboard as soon as Login is tapped —
    // FocusManager.instance.primaryFocus?.unfocus() rather than
    // FocusScope.of(context).unfocus(), which didn't reliably close
    // the keyboard when triggered from a button tap elsewhere in this
    // app (see profile_screen.dart's _saveName for the same fix).
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      loading = true;
    });

    try {
      await _authService.signIn(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      // Safety net: unconditionally return to AuthGate's own root
      // route on success, regardless of how many screens got pushed
      // to reach this LoginScreen instance. AuthGate's StreamBuilder
      // reacts to the auth state change on its own either way, but
      // without this, a successful sign-in on a PUSHED LoginScreen
      // would be invisible — buried under whatever's on top of
      // AuthGate in the stack.
      if (mounted) {
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

  Future<void> _forgotPassword() async {
    if (emailController.text.isEmpty) {
      _message('Enter your email first');
      return;
    }
    await _authService.resetPassword(emailController.text.trim());
    if (!mounted) return;
    _message('Password reset email sent');
  }

  Future<void> _googleSignIn() async {
    try {
      await _authService.signInWithGoogle();
      // Same safety net as email/password login above.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      _message(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // true so the card moves up above the keyboard and a focused
      // field (e.g. Password, in landscape) is never hidden under it.
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        title: 'Cellnotation',
        subtitle: 'enjoy the music playing',
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
              if (!loading) login();
            },
            onClear: () => setState(passwordController.clear),
          ),

          // SIGN IN WITH GOOGLE and FORGOT PASSWORD — two small text
          // buttons in the same style, side by side under the password
          // field.
          // A Wrap, so on a narrow screen the two simply go on two lines.
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: loading ? null : _googleSignIn,
                child: const Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: loading ? null : _forgotPassword,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          AuthMainButton(
            label: 'Login',
            loading: loading,
            onPressed: login,
          ),

          const SizedBox(height: 22),

          // CREATE ACCOUNT — a link under the buttons.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'No account yet?',
                style: TextStyle(fontSize: 22, color: Colors.black54),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Create account',
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