import 'package:flutter/material.dart';

import 'auth_service.dart';
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
      // (reached via some other push somewhere) would be invisible —
      // buried under whatever's on top of AuthGate in the stack.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(e.toString(), style: TextStyle(fontSize: 22),),
        ),
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // true (the default) now, per request — with false, the body
      // never shrinks for the keyboard, so Flutter never realizes it
      // needs to scroll a focused field (e.g. Password, in landscape)
      // up above the keyboard, leaving it hidden underneath it.
      resizeToAvoidBottomInset : true,
      // appBar: AppBar(
      //   title: const Text('Login'),
      // ),

      // BACKGROUND — same cellnotation_background.jpg + dark scrim
      // treatment as home_screen.dart, per request, so the whole
      // pre-login flow shares one consistent look. Field/title text
      // that used to be plain black is now white below — black text
      // would be unreadable against this dark background.
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/cellnotation_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

          // LayoutBuilder + a min-height ConstrainedBox centers the
          // content when it's SHORTER than the viewport, while still
          // allowing it to scroll normally if it ever overflows a
          // short (e.g. landscape, or landscape + keyboard) screen —
          // same pattern as profile_screen.dart. A plain Center()
          // wrapping a SingleChildScrollView doesn't actually center
          // short content this way, since Center() alone can't tell
          // the ScrollView how tall the viewport actually is.
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: SizedBox(
                      width: 500,
                      child: Padding(
                        padding: const EdgeInsets.all(20),

                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [

                            const SizedBox(height: 100),

                            // Text('cellnotation',
                            //   style: TextStyle(
                            //     color: Colors.white,
                            //     fontSize: 80,
                            //     fontWeight: FontWeight.bold,
                            //   ),
                            // ),
                            //
                            // const SizedBox(height: 20),

                            SizedBox(
                              height: 50,
                              child: TextField(
                                controller: emailController,
                                obscureText: false,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  labelText: 'Email',
                                  labelStyle: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      setState(() {
                                        emailController.clear();
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              height: 50,
                              child: TextField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  labelText: 'Password',
                                  labelStyle: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.clear),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          setState(() {
                                            passwordController.clear();
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ROW 1 — Login and Create Account side by side,
                            // per request.
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 100,
                                    child: ElevatedButton(
                                      onPressed: loading ? null : login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 50),
                                        elevation: 0,
                                        // Same note-block shape as the home screen's
                                        // buttons — matches NoteBlockWidget's own
                                        // BorderRadius.circular(4).
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      child: loading
                                          ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                          : const Text(
                                        'Login',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 100,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const RegisterScreen(),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 50),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      child: loading
                                          ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                          : const Text(
                                        'Create Account',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // ROW 2 — Forgot Password and Google sign-in side
                            // by side, per request.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () async {
                                      if (emailController.text.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            duration: const Duration(seconds: 2),
                                            content: Text(
                                              "Enter your email first",
                                              style: TextStyle(fontSize: 22),
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      await _authService.resetPassword(
                                        emailController.text.trim(),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          duration: const Duration(seconds: 2),
                                          content: Text(
                                            "Password reset email sent",
                                            style: TextStyle(fontSize: 22),
                                          ),
                                        ),
                                      );
                                    },
                                    child: loading
                                        ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                        : const Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      try {
                                        await _authService.signInWithGoogle();
                                        // Same safety net as email/password login
                                        // above — see that comment for why this
                                        // matters.
                                        if (mounted) {
                                          Navigator.of(context)
                                              .popUntil((route) => route.isFirst);
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            duration: const Duration(seconds: 2),
                                            content: Text(
                                              e.toString(),
                                              style: TextStyle(fontSize: 22),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    // Assumes assets/google.png is registered in
                                    // pubspec.yaml's flutter/assets section —
                                    // adjust the path here if it lives somewhere
                                    // else (e.g. assets/images/google.png).
                                    //
                                    // Wrapped in a black Container, per request —
                                    // this button's own asset has a transparent
                                    // background, which used to just show the
                                    // page's plain white Scaffold through it;
                                    // against the dark background image it would
                                    // otherwise look like a floating cutout.
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: Image.asset(
                                          'assets/google.png',
                                          fit: BoxFit.fitWidth,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}