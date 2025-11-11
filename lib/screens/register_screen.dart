import 'package:flutter/material.dart';
import 'package:my_app/screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer; // ...existing code...

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();

  
}

class _RegisterScreenState extends State<RegisterScreen> {
  
  final _formKey = GlobalKey<FormState>();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agree = false;
  

  // final List<String> _userTypes = ['Romo Paroki', 'Romo Ordo', 'Umat'];
   final List<Map<String, dynamic>> _userTypes = [
    {'id': 13, 'label': 'Romo Paroki', 'desc': 'Deskripsi Romo Paroki'},
    {'id': 12, 'label': 'Romo Ordo', 'desc': 'Deskripsi Romo Ordo'},
    {'id': 3, 'label': 'Umat', 'desc': 'Pilih jika Anda umat biasa'},
  ];
  

  final List<Map<String, dynamic>> _umattype = [
    {'id': 14, 'label': 'Umat Lokal'},
    {'id': 15, 'label': 'Umat Pendatang'},
  ];
  int? _selectedUserType;
  // String? _radioUmatType;
  int? _radioUmatType;

  // ...existing code...
  // Tambah controller untuk email, password, confirm
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
  // ...existing code...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 30),

                // LOGO
                Image.asset('assets/images/catuv2_1.png', height: 130),
                const SizedBox(height: 8),

                const SizedBox(height: 30),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Register",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.indigo),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Masukkan email';
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value)) return 'Email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Password
                TextFormField(
                  controller: _passController,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: "Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.indigo),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Masukkan password';
                    if (value.length < 6) return 'Password minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Confirm Password
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.indigo),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Konfirmasi password';
                    if (value != _passController.text) return 'Password tidak cocok';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Dropdown Jenis User
                // In the build method, update the DropdownButtonFormField:

              DropdownButtonFormField<int>(
                value: _selectedUserType,
                hint: const Text("-- Jenis User --"),
                items: _userTypes.map((type) {
                  return DropdownMenuItem<int>(
                    value: type['id'] as int,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type['label'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUserType = value;
                    // show radio only when selected id is 3 (Umat)
                    if (value != 3) _radioUmatType = null;
                  });
                },
                validator: (value) {
                  if (value == null) return 'Pilih jenis user';
                  return null;
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.indigo),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Then, wrap the radio buttons Column with a Visibility widget:
              // Replace the Visibility widget section with:
            Visibility(
              visible: _selectedUserType == 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: _umattype.map((type) {
                  final int id = type['id'] as int;
                  return Expanded(
                    child: RadioListTile<int>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      title: Text(type['label'] as String, style: const TextStyle(fontSize: 12)),
                      value: id,
                      groupValue: _radioUmatType,
                      onChanged: (int? value) => setState(() => _radioUmatType = value),
                    ),
                  );
                }).toList(),
              ),
            ),
                const SizedBox(height: 12),
                // Checkbox Terms
                Row(
                  children: [
                    Checkbox(
                      value: _agree,
                      onChanged: (val) => setState(() => _agree = val ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        "I agree with the applicable Terms and Policies",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Confirm Button
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
                    onPressed: _agree
                        ? () async{
                            if (_formKey.currentState!.validate()) {
                                  await _registerUser();
                            }
                          }
                        : null,
                    child: const Text(
                      "CONFIRM",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: Text(
                        "Sign In",
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.bold,
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
    );
  }
  String get _baseUrl => 'http://10.0.2.2:8080';

  // ...existing code...
Future<void> _registerUser() async {
  
  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': _emailController.text,
        'Password': _passController.text,
        'role_id': _selectedUserType
      }),
    );

    // Log basic info for every response
    developer.log('Register response received',
        name: 'register',
        error: {'status': response.statusCode, 'body': response.body});

    if (response.statusCode == 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      // Detailed failure log
      developer.log('Registration failed',
          name: 'register',
          error: 'status=${response.statusCode}, body=${response.body}',
          level: 900);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${response.body}')),
        );
      }
    }
  } catch (e, st) {
    // Exception log with stack trace
    developer.log('Register exception', name: 'register', error: e, stackTrace: st, level: 1000);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
// ...existing code...

// Then update the confirm button's onPressed:
// onPressed: _agree
//     ? () async {
//         if (_formKey.currentState!.validate()) {
//           await _registerUser();
//         }
//       }
//     : null,
}

