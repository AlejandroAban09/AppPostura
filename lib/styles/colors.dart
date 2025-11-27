import 'package:flutter/material.dart';

class AppColors {
  // Colores base (Premium / Crypt Theme)
  static const Color backgroundColor = Color(0xFFF8F9FD); // Fondo claro
  static const Color cardDark = Color(0xFF1E1E1E); // Tarjeta oscura principal
  static const Color accentGold = Color(0xFFF2C94C); // Dorado/Amarillo accent

  static const Color lightGray = Color(0xFFF4F4F4);
  static const Color darkGray = Color(0xFF333333);
  static const Color white = Colors.white;

  // Compatibilidad con código existente (mapeo al nuevo tema)
  static const Color primaryColor = cardDark; // Usamos el oscuro como primario
  static const Color secondaryColor = accentGold; // Dorado como secundario
  static const Color tertiaryColor = Color(0xFFE0E0E0);
  static const Color accentColor = accentGold;

  // Colores para feedback
  static const Color errorColor = Color(0xFFFF6B6B);
  static const Color successColor = Color(0xFF27AE60);
  static const Color warningColor = Color(0xFFF2994A);

  // Colores para textos
  static const Color primaryText = cardDark;
  static const Color secondaryText = Color(0xFF828282);
  static const Color textOnDark = Colors.white;
}
