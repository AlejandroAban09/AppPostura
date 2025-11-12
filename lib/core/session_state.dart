import 'dart:async';
import 'package:flutter/foundation.dart';

/// Estado global de sesión + cronómetro de postura.
class SessionState extends ChangeNotifier {
  int? userId;
  String? displayName;

  int? currentSessionId;

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
