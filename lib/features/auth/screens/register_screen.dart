// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '/locator.dart';
import '/core/api/api_service.dart';
import '/styles/colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu correo electrónico';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  String? _validateDisplayName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu nombre completo';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa un nombre de usuario';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa una contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor confirma tu contraseña';
    }
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final box = Hive.box('focusme_users');
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final email = _emailController.text.trim();
      final displayName = _displayNameController.text.trim();

      if (username.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('El nombre de usuario no puede estar vacío'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }

      // CAMBIO: Intentar registrar en la API primero
      int? apiUserId;
      bool apiRegistrationSuccess = false;

      try {
        final api = locator<ApiService>();
        final authResult = await api.registerUser(
          username,
          password,
          correo: email,
          displayName: displayName,
        );
        apiUserId = authResult.userId;
        apiRegistrationSuccess = true;
      } catch (apiError) {
        // Si es 404, el endpoint no existe, registrar solo localmente
        if (apiError.toString().contains('404') ||
            apiError.toString().contains('no está disponible')) {
          // El endpoint de registro no existe en la API, continuar con registro local
          apiRegistrationSuccess = false;
        } else {
          // Otro error de la API - verificar si es porque el usuario ya existe
          String errorMessage = 'Error al registrar en el servidor';

          if (apiError.toString().contains('409') ||
              apiError.toString().toLowerCase().contains('ya existe') ||
              apiError.toString().toLowerCase().contains('already exists')) {
            errorMessage = 'El nombre de usuario ya existe en el servidor';
            // Si ya existe en el servidor, verificar localmente
            if (box.containsKey(username)) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('El nombre de usuario ya existe'),
                  backgroundColor: AppColors.errorColor,
                ),
              );
              return;
            }
            // Si no existe localmente pero sí en el servidor, no continuar
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.errorColor,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          } else if (apiError.toString().contains('400') ||
              apiError.toString().toLowerCase().contains('invalid')) {
            errorMessage = 'Datos inválidos. Por favor verifica tu información';
          } else if (apiError.toString().contains('401') ||
              apiError.toString().contains('403')) {
            errorMessage = 'No tienes permisos para realizar esta acción';
          } else if (apiError.toString().contains('500') ||
              apiError.toString().toLowerCase().contains('server')) {
            errorMessage = 'Error del servidor. Por favor intenta más tarde';
          } else {
            errorMessage =
                'Error al conectar con el servidor: ${apiError.toString()}';
          }

          // Si hay un error de conexión (no 404), guardar localmente de todas formas
          // pero mostrar el error
          if (!apiError.toString().contains('404') &&
              !apiError.toString().contains('no está disponible')) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$errorMessage. Se guardará localmente.'),
                backgroundColor: AppColors.warningColor,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      // CAMBIO: Verificar si el usuario ya existe localmente (solo si no se registró en API)
      if (!apiRegistrationSuccess && box.containsKey(username)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('El nombre de usuario ya existe localmente'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }

      // CAMBIO: Guardar el usuario localmente (siempre, incluso si la API funcionó)
      await box.put(username, {
        'password': password,
        'points': 0,
        'focus_time': 0,
        'pomodoro_sessions': 0,
        'sound_enabled': true,
        if (apiUserId != null)
          'api_user_id': apiUserId, // Solo si se registró en la API
      });

      // Guardar el usuario actual
      await box.put('current_user', username);

      if (!mounted) return;

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiRegistrationSuccess
                ? '¡Cuenta creada exitosamente en el servidor!'
                : '¡Cuenta creada exitosamente! (Solo local)',
          ),
          backgroundColor: AppColors.successColor,
        ),
      );

      // Limpiar los campos después de un breve delay
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: ${e.toString()}'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(title: const Text('Crear Cuenta')),
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
                  'Únete a la comunidad',
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
                            controller: _displayNameController,
                            validator: _validateDisplayName,
                            decoration: InputDecoration(
                              labelText: 'Nombre Completo',
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
                                Icons.badge_outlined,
                                color: AppColors.primaryColor,
                              ),
                              filled: true,
                              fillColor: AppColors.lightGray,
                            ),
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailController,
                            validator: _validateEmail,
                            decoration: InputDecoration(
                              labelText: 'Correo Electrónico',
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
                                Icons.email_outlined,
                                color: AppColors.primaryColor,
                              ),
                              filled: true,
                              fillColor: AppColors.lightGray,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _usernameController,
                            validator: _validateUsername,
                            decoration: InputDecoration(
                              labelText: 'Nombre de usuario',
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
                            controller: _passwordController,
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
                              helperText: 'Mínimo 6 caracteres',
                              helperStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _confirmPasswordController,
                            validator: _validateConfirmPassword,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirmar Contraseña',
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
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.primaryText,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: AppColors.lightGray,
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _register(),
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: AppColors.primaryText,
                              foregroundColor: AppColors.backgroundColor,
                              disabledBackgroundColor: AppColors.lightGray,
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
                            child: _isLoading
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
                                : const Text('Registrarse'),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => context.go('/login'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryText,
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Ya tengo una cuenta'),
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
