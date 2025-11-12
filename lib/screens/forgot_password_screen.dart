// lib/screens/forgot_password_screen.dart
// CAMBIO: Pantalla de recuperación de contraseña implementada con lógica API primero, luego local
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '/locator.dart';
import '/core/api/api_service.dart';
import '/styles/colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _codeSent = false;
  String? _userEmail;
  String? _localVerificationCode; // Para usuarios locales

  // Validación de email
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu correo electrónico o usuario';
    }
    return null;
  }

  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa el código de verificación';
    }
    if (value.length < 4) {
      return 'El código debe tener al menos 4 caracteres';
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
    if (value != _newPasswordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  // Generar código de verificación local (6 dígitos)
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Solicitar restablecimiento de contraseña
  // CAMBIO: Primero intenta API, si falla usa método local
  Future<void> _requestPasswordReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailOrUser = _emailController.text.trim().toLowerCase();
      final box = Hive.box('focusme_users');

      // Buscar usuario local por email o username
      String? foundUsername;
      for (var key in box.keys) {
        if (key.toString().toLowerCase() == emailOrUser ||
            (key.toString().contains('@') &&
                key.toString().toLowerCase() == emailOrUser)) {
          foundUsername = key.toString();
          break;
        }
      }

      bool apiRequestSuccess = false;

      // CAMBIO: Intentar solicitar restablecimiento en la API primero
      try {
        final api = locator<ApiService>();
        await api.requestPasswordReset(emailOrUser);
        apiRequestSuccess = true;
      } catch (apiError) {
        // Si es 404, el endpoint no existe, usar método local
        if (apiError.toString().contains('404') ||
            apiError.toString().contains('no está disponible')) {
          apiRequestSuccess = false;
        } else {
          // Otro error de la API - mostrar mensaje pero continuar con local si existe usuario
          if (foundUsername == null) {
            String errorMessage = 'Error al solicitar restablecimiento';
            if (apiError.toString().toLowerCase().contains('no encontrado') ||
                apiError.toString().toLowerCase().contains('not found')) {
              errorMessage = 'Usuario no encontrado';
            } else if (apiError.toString().contains('400') ||
                apiError.toString().toLowerCase().contains('invalid')) {
              errorMessage = 'Datos inválidos';
            }

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.errorColor,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }
        }
      }

      // Si el usuario existe localmente, generar código local
      if (foundUsername != null) {
        _localVerificationCode = _generateVerificationCode();

        // Guardar código temporal con expiración (10 minutos)
        final resetCodesBox = await Hive.openBox('password_reset_codes');
        await resetCodesBox.put(emailOrUser, {
          'code': _localVerificationCode,
          'username': foundUsername,
          'expires_at': DateTime.now()
              .add(const Duration(minutes: 10))
              .toIso8601String(),
        });
        await resetCodesBox.close();

        if (!mounted) return;

        // Mostrar código en desarrollo (en producción esto vendría por email)
        if (kDebugMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Código de verificación (solo desarrollo): $_localVerificationCode',
              ),
              backgroundColor: AppColors.primaryColor,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      } else if (!apiRequestSuccess) {
        // Usuario no encontrado ni localmente ni en API
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Usuario no encontrado. Verifica tu información.',
            ),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Si llegamos aquí, el código fue enviado (por API o generado localmente)
      setState(() {
        _codeSent = true;
        _userEmail = emailOrUser;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiRequestSuccess
                ? 'Código de verificación enviado a tu correo electrónico'
                : 'Código de verificación generado (modo local)',
          ),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 4),
        ),
      );
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

  // Verificar código y restablecer contraseña
  // CAMBIO: Primero intenta local, luego API
  Future<void> _verifyCodeAndResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _userEmail!;
      final code = _codeController.text.trim();
      final newPassword = _newPasswordController.text;
      final box = Hive.box('focusme_users');

      // Verificar código local primero
      final resetCodesBox = await Hive.openBox('password_reset_codes');
      final resetData = resetCodesBox.get(email);

      bool codeValid = false;
      String? username;

      if (resetData != null) {
        final data = resetData as Map<dynamic, dynamic>;
        final storedCode = data['code'] as String?;
        final expiresAt = DateTime.parse(data['expires_at'] as String);
        username = data['username'] as String?;

        if (DateTime.now().isBefore(expiresAt) && storedCode == code) {
          codeValid = true;
        } else if (DateTime.now().isAfter(expiresAt)) {
          await resetCodesBox.delete(email);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('El código de verificación ha expirado'),
              backgroundColor: AppColors.errorColor,
            ),
          );
          return;
        }
      }
      await resetCodesBox.close();

      // Si el código local es válido, restablecer localmente
      if (codeValid && username != null) {
        final userData = box.get(username) as Map<dynamic, dynamic>?;
        if (userData != null) {
          await box.put(username, {...userData, 'password': newPassword});

          // Eliminar código usado
          final resetCodesBox2 = await Hive.openBox('password_reset_codes');
          await resetCodesBox2.delete(email);
          await resetCodesBox2.close();

          // CAMBIO: Intentar también en la API si está disponible
          bool apiSuccess = false;
          try {
            final api = locator<ApiService>();
            await api.verifyResetCodeAndSetPassword(email, code, newPassword);
            apiSuccess = true;
          } catch (_) {
            // Si falla la API, no es problema, ya se restableció localmente
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                apiSuccess
                    ? 'Contraseña restablecida exitosamente'
                    : 'Contraseña restablecida exitosamente (solo local)',
              ),
              backgroundColor: AppColors.successColor,
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          context.go('/login');
          return;
        }
      }

      // Si no hay código local válido, intentar con la API
      try {
        final api = locator<ApiService>();
        await api.verifyResetCodeAndSetPassword(email, code, newPassword);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contraseña restablecida exitosamente'),
            backgroundColor: AppColors.successColor,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        context.go('/login');
        return;
      } catch (apiError) {
        // Error de API
        String errorMessage = 'Código de verificación inválido o expirado';

        if (apiError.toString().toLowerCase().contains('invalid') ||
            apiError.toString().toLowerCase().contains('código') ||
            apiError.toString().toLowerCase().contains('code')) {
          errorMessage = 'Código de verificación inválido';
        } else if (apiError.toString().toLowerCase().contains('expired') ||
            apiError.toString().toLowerCase().contains('expirado')) {
          errorMessage = 'El código de verificación ha expirado';
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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

  void _goBackToEmailStep() {
    setState(() {
      _codeSent = false;
      _codeController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _localVerificationCode = null;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(_codeSent ? 'Verificar Código' : 'Restablecer Contraseña'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
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
                      return Icon(
                        _codeSent ? Icons.verified_user : Icons.lock_reset,
                        size: 170,
                        color: AppColors.primaryColor,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _codeSent ? 'Verificar Código' : 'Restablecer Contraseña',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _codeSent
                      ? 'Ingresa el código de verificación que recibiste por correo y tu nueva contraseña'
                      : 'Ingresa tu correo electrónico o usuario para recibir un código de verificación',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
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
                          if (!_codeSent) ...[
                            // Paso 1: Solicitar código
                            TextFormField(
                              controller: _emailController,
                              validator: _validateEmail,
                              decoration: InputDecoration(
                                labelText: 'Correo electrónico o usuario',
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
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _requestPasswordReset(),
                            ),
                            const SizedBox(height: 40),
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _requestPasswordReset,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.backgroundColor,
                                            ),
                                      ),
                                    )
                                  : const Text('Enviar Código de Verificación'),
                            ),
                          ] else ...[
                            // Paso 2: Verificar código y establecer nueva contraseña
                            TextFormField(
                              controller: _codeController,
                              validator: _validateCode,
                              decoration: InputDecoration(
                                labelText: 'Código de verificación',
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
                                  Icons.verified_user_outlined,
                                  color: AppColors.primaryColor,
                                ),
                                filled: true,
                                fillColor: AppColors.lightGray,
                                helperText: 'Revisa tu correo electrónico',
                                helperStyle: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _newPasswordController,
                              validator: _validatePassword,
                              obscureText: _obscureNewPassword,
                              decoration: InputDecoration(
                                labelText: 'Nueva Contraseña',
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
                                    _obscureNewPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.primaryText,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword =
                                          !_obscureNewPassword;
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
                                labelText: 'Confirmar Nueva Contraseña',
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
                              onFieldSubmitted: (_) =>
                                  _verifyCodeAndResetPassword(),
                            ),
                            const SizedBox(height: 40),
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _verifyCodeAndResetPassword,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.backgroundColor,
                                            ),
                                      ),
                                    )
                                  : const Text('Restablecer Contraseña'),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _isLoading ? null : _goBackToEmailStep,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryText,
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Cambiar correo electrónico'),
                            ),
                          ],
                          const SizedBox(height: 16),
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
                            child: const Text('Volver al inicio de sesión'),
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
