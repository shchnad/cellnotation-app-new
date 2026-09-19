import 'package:flutter/material.dart';

import 'auth_service.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}


class _RegisterScreenState extends State<RegisterScreen> {

  final AuthService _authService = AuthService();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;

  Future<void> register() async {
    setState(() {
      loading = true;
    });
    try {
      await _authService.register(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(
              'Verification email sent — check your inbox.',
              style: TextStyle(fontSize: 22),
            ),
          ),
        );
        // popUntil, not a plain pop — RegisterScreen may have been
        // reached via a pushed route on top of AuthGate. Registering
        // signs the new user in right away, so AuthGate's own
        // StreamBuilder is about to reactively show VerifyEmailScreen
        // — but that happens UNDERNEATH whatever's currently pushed
        // on top of it. A plain pop() would only remove one route
        // (potentially landing back on a stale pushed LoginScreen,
        // the same bug already fixed once in "Back to Login?");
        // clearing back to the root guarantees AuthGate's reactive
        // content is what actually becomes visible.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
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
      //   title: const Text('Register'),
      // ),
      body: Stack(
        children: [
          // BACKGROUND — same cellnotation_background.jpg + dark
          // scrim treatment as home_screen.dart / LoginScreen, per
          // request, so the whole pre-login flow shares one
          // consistent look. Placed FIRST so it paints behind
          // everything else in this Stack.
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
          // same pattern as login_screen.dart/profile_screen.dart. A
          // plain Center() alone can't tell a ScrollView how tall the
          // viewport actually is, so it wouldn't center short content
          // this way on its own.
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: SizedBox(
                      // Widened from 500 to 660, per request — matches
                      // login_screen.dart's own treatment, keeping
                      // both auth screens visually consistent, even
                      // though a single 300px button (see below) would
                      // already fit comfortably within the old 500.
                      width: 660,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            // const SizedBox(height: 100),

                            // Text('cellnotation',
                            //   style: TextStyle(
                            //     color: Colors.white,
                            //     fontSize: 110,
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
                                  color: Colors.green,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  labelText: 'Email',
                                  labelStyle: const TextStyle(
                                    color: Colors.green,
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
                                  color: Colors.green,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  labelText: 'Password',
                                  labelStyle: const TextStyle(
                                    color: Colors.green,
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

                            const SizedBox(height:20),

                            SizedBox(
                              // width: double.infinity,
                              width: 300,
                              height: 100,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  // Matches the outer SizedBox exactly now — a
                                  // mismatched minimumSize (this was double.
                                  // infinity x 50 while the SizedBox constrained
                                  // to 300x100) is a likely cause of buttons not
                                  // sizing as expected elsewhere in this app too.
                                  minimumSize: const Size(300, 100),
                                  elevation: 0,
                                  // Same note-block shape as the home screen's
                                  // buttons — matches NoteBlockWidget's own
                                  // BorderRadius.circular(4).
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: loading ? null : register,
                                child: loading
                                    ? const CircularProgressIndicator()
                                    : const Text(
                                  'Register',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            // BACK TO LOGIN — now a plain text button placed
                            // directly under Register, per request (was
                            // previously a top-left corner icon+text link,
                            // now removed).
                            TextButton(
                              onPressed: () {
                                // Navigator.pop, not push — RegisterScreen was
                                // reached BY pushing from LoginScreen (via
                                // "Create Account"), so "Back to Login" should
                                // return to that SAME instance. Pushing a new
                                // LoginScreen here instead stacks a duplicate
                                // route on top of AuthGate — if a successful
                                // sign-in later happens on THAT pushed copy,
                                // AuthGate's own StreamBuilder switches to
                                // HomeScreen underneath it, but the pushed
                                // LoginScreen stays visible on top, making a
                                // successful login look like it silently
                                // failed.
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Back to Login',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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