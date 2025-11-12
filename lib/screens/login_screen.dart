import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '/locator.dart';
import '/core/api/api_service.dart';
import '/core/session_state.dart';
import '/styles/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController(text: 'saul'); // demo
  final _passCtrl = TextEditingController(text: '1234'); // demo
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      final username = _userCtrl.text.trim();
      final password = _passCtrl.text;
      final box = Hive.box('focusme_users');

      // Primero intentar autenticación local (Hive)
      if (box.containsKey(username)) {
        final userData = box.get(username) as Map<dynamic, dynamic>?;
        if (userData != null && userData['password'] == password) {
          // Usuario local encontrado y contraseña correcta
          // Usar el ID de la API si está disponible, sino generar uno local
          final userId =
              userData['api_user_id'] as int? ?? username.hashCode.abs();

          // Actualizar el usuario actual
          await box.put('current_user', username);

          // Guardar sesión global
          locator<SessionState>().signIn(id: userId, name: username);

          if (!context.mounted) return;
          context.go('/dashboard');
          return;
        } else {
          // Contraseña incorrecta para usuario local
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Contraseña incorrecta'),
              backgroundColor: AppColors.errorColor,
            ),
          );
          return;
        }
      }

      // Si no se encuentra en Hive, intentar con la API
      try {
        final api = locator<ApiService>();
        final res = await api.authSimpleGet(username, password);

        // Guardar también en Hive para futuras referencias
        await box.put(username, {
          'password': password,
          'points': 0,
          'focus_time': 0,
          'pomodoro_sessions': 0,
          'sound_enabled': true,
          'api_user_id': res.userId, // Guardar el ID de la API
        });
        await box.put('current_user', username);

        // Guardar sesión global (dispara refreshListenable del router)
        locator<SessionState>().signIn(id: res.userId, name: res.displayName);

        if (!context.mounted) return;
        context.go('/dashboard');
      } catch (apiError) {
        // Error de API - credenciales inválidas
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Usuario o contraseña incorrectos'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión: ${e.toString()}'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu usuario o correo';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(25.0),
                  child: Image.asset(
                    'assets/imagenes/logo.png',
                    width: 170,
                    height: 170,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.account_circle,
                        size: 170,
                        color: AppColors.primaryColor,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Bienvenido de nuevo',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 40),
                Card(
                  color: AppColors.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    side: const BorderSide(color: AppColors.lightGray),
                  ),
                  elevation: 15,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _userCtrl,
                            validator: _validateUsername,
                            decoration: InputDecoration(
                              labelText: 'Usuario o correo',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.darkGray,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.backgroundColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.primaryColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.errorColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.errorColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outlined,
                                color: AppColors.primaryColor,
                              ),
                              filled: true,
                              fillColor: AppColors.lightGray,
                            ),
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passCtrl,
                            validator: _validatePassword,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: GoogleFonts.poppins(
                                color: AppColors.darkGray,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.backgroundColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.primaryColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.errorColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.errorColor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(15.0),
                              ),
                              prefixIcon: const Icon(
                                Icons.password_outlined,
                                color: AppColors.primaryText,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.primaryText,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: AppColors.lightGray,
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _doLogin(),
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: _loading ? null : _doLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryText,
                              foregroundColor: AppColors.backgroundColor,
                              disabledBackgroundColor: AppColors.lightGray,
                              minimumSize: const Size(double.infinity, 50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: const BorderSide(
                                  color: AppColors.primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.backgroundColor,
                                      ),
                                    ),
                                  )
                                : const Text('Iniciar Sesión'),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => context.go('/forgot-password'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryText,
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => context.go('/register'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryText,
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Crear una cuenta'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
