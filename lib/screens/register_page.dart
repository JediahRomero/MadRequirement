import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madlocapp/screens/login_page.dart';
import 'package:quickalert/quickalert.dart';

class RegistrationPageScreen extends StatefulWidget {
  const RegistrationPageScreen({super.key});

  @override
  State<RegistrationPageScreen> createState() => _RegistrationPageScreenState();
}

class _RegistrationPageScreenState extends State<RegistrationPageScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstname = TextEditingController();
  final TextEditingController _lastname = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  bool _showPassword = true;
  bool _showConfirmPassword = true;

  void _togglePassword() {
    setState(() {
      _showPassword = !_showPassword;
    });
  }

  void _toggleConfirmPassword() {
    setState(() {
      _showConfirmPassword = !_showConfirmPassword;
    });
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: 'Registering',
      text: 'Please wait...',
    );

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      String userId = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('accounts').doc(userId).set({
        'userID': userId,
        'firstname': _firstname.text.trim(),
        'lastname': _lastname.text.trim(),
        'email': _email.text.trim(),
        'isFriend': false,
        'timestamp': FieldValue.serverTimestamp(),
        'friends': [],
      });

      _firstname.clear();
      _lastname.clear();
      _email.clear();
      _password.clear();
      _confirmPassword.clear();

      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPageScreen()),
      );
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already in use.';
      } else {
        errorMessage = 'An unexpected error occurred. Please try again.';
      }
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Registration Failed',
        text: errorMessage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', width: 40, height: 40),
            const SizedBox(width: 8),
            Text(
              'SpotSync',
              style: GoogleFonts.openSans(
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade900,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/logo1.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.white70.withOpacity(0.2)),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(28.5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create an Account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ..._buildFormFields(),
                      const SizedBox(height: 20),
                      _buildRegisterButton(),
                      const SizedBox(height: 15),
                      _buildLoginButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFormFields() {
    return [
      _buildTextField(_firstname, 'First Name', false),
      const SizedBox(height: 18),
      _buildTextField(_lastname, 'Last Name', false),
      const SizedBox(height: 18),
      _buildTextField(_email, 'Email', false, email: true),
      const SizedBox(height: 18),
      _buildTextField(_password, 'Password', _showPassword,
          toggle: _togglePassword),
      const SizedBox(height: 18),
      _buildTextField(
        _confirmPassword,
        'Confirm Password',
        _showConfirmPassword,
        toggle: _toggleConfirmPassword,
        confirmPassword: true,
      ),
    ];
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    bool obscureText, {
    bool email = false,
    bool confirmPassword = false,
    VoidCallback? toggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: toggle != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: toggle,
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        if (email && !EmailValidator.validate(value.trim())) {
          return 'Enter a valid email';
        }
        if (confirmPassword && value.trim() != _password.text.trim()) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: _registerUser,
      child: Text(
        'Register',
        style: GoogleFonts.openSans(
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.all(15),
      ),
    );
  }

  Widget _buildLoginButton() {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPageScreen()),
        );
      },
      child: Text(
        'Already have an account? Login',
        style: GoogleFonts.openSans(
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.blue.shade900,
          ),
        ),
      ),
    );
  }
}
