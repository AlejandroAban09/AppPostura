// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../locator.dart';
import '../core/session_state.dart';

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
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!context.mounted) return;
      final logged = locator<SessionState>().isLoggedIn;
      context.go(logged ? '/dashboard' : '/login');
      // Si aún no usas SessionState, fuerza siempre a login:
      // context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ajusta la ruta del asset si es distinta
            // (recuerda declararlo en pubspec.yaml)
            SizedBox(
              width: 120,
              height: 120,
              child: Image(
                image: AssetImage('assets/imagenes/logo.png'),
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'FocusMe',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
