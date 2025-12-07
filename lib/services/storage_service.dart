import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_models.dart';
import '../core/api/api_service.dart';
import '../locator.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;
  static const String _pendingSessionsKey = 'pending_sessions';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  // --- Pending Sessions Logic ---

  Future<void> addPendingSession(PendingSession session) async {
    final List<String> list = _prefs?.getStringList(_pendingSessionsKey) ?? [];
    list.add(json.encode(session.toJson()));
    await _prefs?.setStringList(_pendingSessionsKey, list);
  }

  List<PendingSession> getPendingSessions() {
    final List<String> list = _prefs?.getStringList(_pendingSessionsKey) ?? [];
    return list.map((s) => PendingSession.fromJson(json.decode(s))).toList();
  }

  Future<void> clearPendingSessions() async {
    await _prefs?.remove(_pendingSessionsKey);
  }

  Future<void> removePendingSessionAt(int index) async {
    final List<String> list = _prefs?.getStringList(_pendingSessionsKey) ?? [];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await _prefs?.setStringList(_pendingSessionsKey, list);
    }
  }

  /// Intenta sincronizar las sesiones pendientes con el servidor
  Future<int> syncPendingSessions() async {
    final sessions = getPendingSessions();
    if (sessions.isEmpty) return 0;

    final api = locator<ApiService>();
    int syncedCount = 0;
    final List<PendingSession> failedSessions = [];

    for (final session in sessions) {
      try {
        // 1. Iniciar sesión en el servidor
        final sessionId = await api.startSession(session.start);

        // 2. Finalizar sesión inmediatamente con los datos guardados
        await api.finishSession(sessionId, session.finish);

        syncedCount++;
      } catch (e) {
        // Si falla, la guardamos para intentarlo después
        failedSessions.add(session);
      }
    }

    // Actualizar la lista con las que fallaron (o limpiar si todas pasaron)
    if (failedSessions.isEmpty) {
      await clearPendingSessions();
    } else {
      final List<String> newList = failedSessions
          .map((s) => json.encode(s.toJson()))
          .toList();
      await _prefs?.setStringList(_pendingSessionsKey, newList);
    }

    return syncedCount;
  }
}
