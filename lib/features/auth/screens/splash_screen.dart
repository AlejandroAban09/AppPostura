// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../locator.dart';
import '../../../core/session_state.dart';
import '../../../styles/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navega tras una breve pausa para mostrar el logo
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!context.mounted) return;
      final logged = locator<SessionState>().isLoggedIn;
      context.go(logged ? '/dashboard' : '/login');
      // Si aún no usas SessionState, fuerza siempre a login:
      // context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ajusta la ruta del asset si es distinta
            // (recuerda declararlo en pubspec.yaml)
            SizedBox(
              width: 260,
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25.0),
                child: const Image(
                  image: AssetImage('assets/imagenes/logo.png'),
                  fit: BoxFit.contain,
                ),

                // image: AssetImage('assets/imagenes/logo.png'),
                // fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ErgoSense',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 48),
            LoadingAnimationWidget.staggeredDotsWave(
              color: AppColors.accentGold,
              size: 50,
            ),
          ],
        ),
      ),
    );
  }
}
