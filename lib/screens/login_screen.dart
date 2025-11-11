import 'package:flutter/material.dart';
import '../widgets/custom_textfield.dart';
import 'package:flutter/gestures.dart';
import 'register_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool rememberMe = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Welcoming Testing",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6), 
              const Text(
                "Information or tagline for completing welcoming page",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Logo
              Center(
                child: Column(
                  children: [
                    Image.asset('assets/images/catuv2_1.png', height: 120),
                    const SizedBox(height: 8),
                    
                  ],
                ),
              ),
              const SizedBox(height: 40),

              const Text("Masuk", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Input Email & Password
              const CustomTextField(label: "Email", hint: "Email"),
              const SizedBox(height: 12),
              const CustomTextField(
                  label: "Kata Sandi", hint: "Kata Sandi", obscureText: true),

              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (value) {
                      setState(() => rememberMe = value ?? false);
                    },
                  ),
                  const Text("Ingat Saya"),
                ],
              ),
              const SizedBox(height: 10),

              // Tombol Masuk
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {},
                  child: const Text("Masuk", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 1),

              Container(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text("Lupa Password",
                      style: TextStyle(color: Colors.indigo)),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: RichText(
                  text: TextSpan(
                    text: "Tidak Punya Akun? ",
                    style: const TextStyle(color: Colors.black),
                    children: [
                      TextSpan(
                        text: "Daftar Disini",
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
