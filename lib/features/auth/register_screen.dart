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
        Navigator.pop(context);
      }


    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(e.toString()),
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

      appBar: AppBar(
        title: const Text('Register'),
      ),


      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          mainAxisAlignment:
          MainAxisAlignment.center,


          children: [

            TextField(
              controller: emailController,

              decoration:
              const InputDecoration(
                labelText: 'Email',
                border:
                OutlineInputBorder(),
              ),
            ),


            const SizedBox(height:15),


            TextField(
              controller: passwordController,

              obscureText:true,

              decoration:
              const InputDecoration(
                labelText:'Password',
                border:
                OutlineInputBorder(),
              ),
            ),


            const SizedBox(height:20),


            SizedBox(

              width:double.infinity,

              child: ElevatedButton(

                onPressed:
                loading ? null : register,


                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('Register'),

              ),

            ),

          ],

        ),

      ),

    );

  }

}