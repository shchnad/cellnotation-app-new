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
      resizeToAvoidBottomInset : false,
      // appBar: AppBar(
      //   title: const Text('Register'),
      // ),
      body: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 500,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [

                    const SizedBox(height: 100),

                    Text('Cellnotation',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

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
                          labelText: 'Email',
                          labelStyle: const TextStyle(
                            color: Colors.black,
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
                          labelText: 'Password',
                          labelStyle: const TextStyle(
                            color: Colors.black,
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
                      width: 250,
                      height: 100,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          // Matches the outer SizedBox exactly now — a
                          // mismatched minimumSize (this was double.
                          // infinity x 50 while the SizedBox constrained
                          // to 250x100) is a likely cause of buttons not
                          // sizing as expected elsewhere in this app too.
                          minimumSize: const Size(250, 100),
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

                  ],

                ),

              ),
            ),
          ),

          // BACK TO LOGIN — top-left corner, clickable text + icon
          // (not a full note-block button), matching HomeScreen's own
          // Exit treatment exactly (same red color, same arrow-back
          // icon as ProfileScreen's Home), just with different text.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  // Navigator.pop, not push — RegisterScreen was
                  // reached BY pushing from LoginScreen (via
                  // "Create Account"), so "Back to Login" should
                  // return to that SAME instance. Pushing a new
                  // LoginScreen here instead stacks a duplicate route
                  // on top of AuthGate — if a successful sign-in
                  // later happens on THAT pushed copy, AuthGate's own
                  // StreamBuilder switches to HomeScreen underneath
                  // it, but the pushed LoginScreen stays visible on
                  // top, making a successful login look like it
                  // silently failed.
                  Navigator.pop(context);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, color: Colors.red),
                    SizedBox(width: 6),
                    Text(
                      'Back to Login',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

    );

  }

}