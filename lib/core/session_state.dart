import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Estado global de sesión + cronómetro de postura.
class SessionState extends ChangeNotifier {
  int? userId;
  String? displayName;

  int? currentSessionId;
  bool _isSessionValidForPoints = true; // Nuevo flag

  // Estado del bono QR (persiste mientras la app esté viva o hasta que expire/se use)
  String? _qrSsid;
  DateTime? _qrScannedAt;

  DateTime? _sessionStartUtc;
  int _elapsedSeconds = 0;
  Timer? _ticker;

  bool get isLoggedIn => userId != null;

  // --- Temporizador ---
  bool get isSessionRunning => _sessionStartUtc != null && _ticker != null;
  int get elapsedSeconds => _elapsedSeconds;
  int get elapsedMinutes => _elapsedSeconds ~/ 60;

  void signIn({required int id, String? name}) {
    userId = id;
    displayName = name;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    try {
      if (!Hive.isBoxOpen('focusme_users')) {
        await Hive.openBox('focusme_users');
      }
      final box = Hive.box('focusme_users');
      final currentUser = box.get('current_user');

      if (currentUser != null && currentUser is String) {
        final userData = box.get(currentUser);
        if (userData != null && userData is Map) {
          final apiId = userData['api_user_id'] as int?;
          // Si tenemos un ID de API guardado, restauramos la sesión
          if (apiId != null) {
            userId = apiId;
            displayName =
                currentUser; // O agregar display_name al mapa de usuario
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
    }
  }

  void signOut() {
    userId = null;
    displayName = null;
    stopSessionTimer();
    currentSessionId = null;
    notifyListeners();
  }

  void setSessionId(int? id) {
    currentSessionId = id;
    notifyListeners();
  }

  bool get isSessionValidForPoints => _isSessionValidForPoints;

  void setSessionValid(bool valid) {
    _isSessionValidForPoints = valid;
    notifyListeners();
  }

  // --- QR Bonus ---
  String? get qrSsid => _qrSsid;
  DateTime? get qrScannedAt => _qrScannedAt;

  void setQrBonus(String ssid) {
    _qrSsid = ssid;
    _qrScannedAt = DateTime.now();
    notifyListeners();
  }

  void clearQrBonus() {
    _qrSsid = null;
    _qrScannedAt = null;
    notifyListeners();
  }

  /// Arranca el cronómetro. Si ya estaba corriendo, lo deja igual.
  void startSessionTimer() {
    if (_ticker != null) return;
    _sessionStartUtc ??= DateTime.now().toUtc();
    // inicializa _elapsedSeconds con base al tiempo real ya transcurrido (por si re-entramos)
    _elapsedSeconds = DateTime.now()
        .toUtc()
        .difference(_sessionStartUtc!)
        .inSeconds;

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Detiene y limpia el cronómetro. Devuelve los minutos reales (floor).
  int stopSessionTimer() {
    _ticker?.cancel();
    _ticker = null;
    final minutes = _elapsedSeconds ~/ 60;
    _elapsedSeconds = 0;
    _sessionStartUtc = null;
    notifyListeners();
    return minutes;
  }
}
