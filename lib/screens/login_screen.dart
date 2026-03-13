import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading       = false;
  bool _obscurePassword = true;

  static const Color primary      = Color(0xFFFF9900);
  static const Color brown        = Color(0xFF1A1A1A);
  static const Color bgColor      = Color(0xFFFAFAFA);
  static const Color textColor    = Color(0xFF1A1A1A);
  static const Color mutedColor   = Color(0xFF999999);
  static const Color divColor     = Color(0xFFE0E0E0);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showSnackbar('Email dan password tidak boleh kosong!');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ));
      }
    } catch (e) {
      _showSnackbar('Email atau password salah!');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 60),

            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 40,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(child: Image.asset('assets/images/logo.jpeg', fit: BoxFit.cover))),
              const SizedBox(width: 10),
              Text('BoendaKitchen', style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.bold, color: primary, letterSpacing: 0.3)),
            ])),

            const SizedBox(height: 48),

            Text('Selamat Datang di\nBoendaKitchen', style: GoogleFonts.poppins(
              fontSize: 26, fontWeight: FontWeight.bold, color: textColor, height: 1.3)),
            const SizedBox(height: 8),
            Text('Masuk untuk berbagi dan temukan resep favoritmu.',
              style: GoogleFonts.poppins(fontSize: 13, color: mutedColor)),

            const SizedBox(height: 40),

            _InputField(
              controller: _emailController, hint: 'Email',
              icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _InputField(
              controller: _passwordController, hint: 'Password',
              icon: Icons.lock_outline, obscure: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: mutedColor, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary, foregroundColor: brown,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: brown, strokeWidth: 2.5))
                    : Text('Masuk', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 24),

            Row(children: [
              const Expanded(child: Divider(color: divColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('atau', style: GoogleFonts.poppins(fontSize: 13, color: mutedColor)),
              ),
              const Expanded(child: Divider(color: divColor)),
            ]),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: Container(
                width: double.infinity, height: 54,
                decoration: BoxDecoration(
                  border: Border.all(color: divColor),
                  borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text('Belum punya akun? Daftar Sekarang',
                  style: GoogleFonts.poppins(fontSize: 14, color: primary, fontWeight: FontWeight.w500)),
              ),
            ),

            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(color: const Color(0xFF1A1A1A), fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: const Color(0xFF999999), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFFFF9900), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}