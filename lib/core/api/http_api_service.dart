// lib/services/http_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '/config.dart';
import 'api_service.dart';
import '/features/rewards/models/reward.dart';
import '/features/rewards/models/redeem_result.dart';
import '/models/session_models.dart';
import '/services/storage_service.dart';

class OfflineException implements Exception {
  final String message;
  OfflineException(this.message);
  @override
  String toString() => message;
}

class HttpApiService implements ApiService {
  final http.Client _client = http.Client();

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${AppConfig.apiBase}$path').replace(queryParameters: q);

  Future<Map<String, dynamic>> _jsonOrError(http.Response r) async {
    final code = r.statusCode;
    if (code >= 200 && code < 300) {
      if (r.body.isEmpty) return {};
      final data = json.decode(r.body);
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    }
    // Intenta extraer detalle de error JSON
    try {
      final parsed = json.decode(r.body);
      if (parsed is Map && parsed['detail'] != null) {
        throw Exception(parsed['detail'].toString());
      }
    } catch (_) {}
    throw Exception('HTTP $code: ${r.body}');
  }

  Future<http.Response> _getWithCache(Uri uri) async {
    final cacheKey = uri.toString();
    try {
      final response = await _client.get(uri).timeout(AppConfig.timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await StorageService().setString(cacheKey, response.body);
      }
      return response;
    } catch (e) {
      final cachedBody = StorageService().getString(cacheKey);
      if (cachedBody != null) {
        return http.Response(cachedBody, 200);
      }
      // Si no hay caché y falla la red, lanzamos una excepción más amigable
      throw OfflineException(
        'No hay conexión a internet y no hay datos guardados.',
      );
    }
  }

  // ========== AUTH ==========
  @override
  Future<AuthResult> authSimpleGet(String userOrEmail, String pass) async {
    final r = await _client
        .get(_u('/auth', {'user': userOrEmail, 'pass': pass}))
        .timeout(AppConfig.timeout);
    final j = await _jsonOrError(r);
    return AuthResult(j['id_usuario'] as int, j['display_name'] as String?);
  }

  /// Crear usuario en /users usando también correo y display_name
  @override
  Future<AuthResult> registerUser(
    String username,
    String password, {
    String? correo,
    String? displayName,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'password': password,
      'correo': correo,
      'display_name': displayName ?? username,
    };

    final r = await _client
        .post(
          _u('/users'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(AppConfig.timeout);

    final j = await _jsonOrError(r);
    // Tu API devuelve algo como { "ok": true, "id_usuario": 17 }
    final id = (j['id_usuario'] ?? j['id'] ?? 0) as int;
    return AuthResult(id, displayName ?? username);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    List<String> endpoints = [
      '/auth/forgot-password',
      '/auth/request-password-reset',
      '/auth/password-reset/request',
      '/users/password-reset/request',
      '/password-reset/request',
    ];

    for (String endpoint in endpoints) {
      try {
        final r = await _client
            .post(
              _u(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'email': email}),
            )
            .timeout(AppConfig.timeout);

        if (r.statusCode == 404) {
          continue;
        }

        await _jsonOrError(r);
        return;
      } catch (e) {
        if (e.toString().contains('404')) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      'HTTP 404: El endpoint de solicitud de restablecimiento no está disponible en el servidor',
    );
  }

  @override
  Future<void> verifyResetCodeAndSetPassword(
    String email,
    String verificationCode,
    String newPassword,
  ) async {
    List<String> endpoints = [
      '/auth/reset-password',
      '/auth/verify-reset-code',
      '/auth/password-reset/verify',
      '/users/password-reset/verify',
      '/password-reset/verify',
    ];

    for (String endpoint in endpoints) {
      try {
        final r = await _client
            .post(
              _u(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'email': email,
                'code': verificationCode,
                'new_password': newPassword,
              }),
            )
            .timeout(AppConfig.timeout);

        if (r.statusCode == 404) {
          continue;
        }

        await _jsonOrError(r);
        return;
      } catch (e) {
        if (e.toString().contains('404')) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      'HTTP 404: El endpoint de verificación de código no está disponible en el servidor',
    );
  }

  // ========== AJUSTES ==========
  @override
  Future<UserSettings> getUserSettings(int userId) async {
    final r = await _getWithCache(_u('/users/$userId/settings'));
    final j = await _jsonOrError(r);
    return UserSettings.fromJson(j);
  }

  @override
  Future<void> putUserSettings(int userId, UserSettings s) async {
    final r = await _client
        .put(
          _u('/users/$userId/settings'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(s.toJson()),
        )
        .timeout(AppConfig.timeout);
    await _jsonOrError(r);
  }

  // ========== SESIONES ==========
  @override
  Future<int> startSession(SessionStart start) async {
    final r = await _client
        .post(
          _u('/sessions/start'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(start.toJson()),
        )
        .timeout(AppConfig.timeout);
    final j = await _jsonOrError(r);
    return j['id_sesion'] as int;
  }

  @override
  Future<FinishResponse> finishSession(
    int sessionId,
    SessionFinish finish,
  ) async {
    final r = await _client
        .post(
          _u('/sessions/$sessionId/finish'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(finish.toJson()),
        )
        .timeout(AppConfig.timeout);
    final j = await _jsonOrError(r);
    return FinishResponse.fromJson(j);
  }

  // ========== LECTURAS ==========
  @override
  Future<void> sendReading(int sessionId, Reading reading) async {
    final r = await _client
        .post(
          _u('/posture/$sessionId/reading'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(reading.toJson()),
        )
        .timeout(AppConfig.timeout);
    await _jsonOrError(r);
  }

  // ========== PUNTOS ==========
  @override
  Future<int> getPoints(int userId) async {
    final r = await _getWithCache(_u('/users/$userId/points'));
    final j = await _jsonOrError(r);
    return (j['saldo'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<LedgerItem>> getLedger(int userId, {int limit = 50}) async {
    final r = await _getWithCache(
      _u('/users/$userId/points/ledger', {'limit': '$limit'}),
    );
    final j = await _jsonOrError(r);
    final items = (j['items'] as List? ?? []);
    return items
        .map((e) => LedgerItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ========== CATÁLOGO / CANJE ==========
  @override
  Future<List<Reward>> getRewards({int? partnerId}) async {
    final qp = partnerId != null ? {'partner_id': '$partnerId'} : null;
    final r = await _getWithCache(_u('/catalog/rewards', qp));
    final j = await _jsonOrError(r);
    final items = (j['items'] as List? ?? []);
    return items
        .map((e) => Reward.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RedeemResult> redeem(
    int rewardId, {
    required int userId,
    int? sessionId,
  }) async {
    final r = await _client
        .post(
          _u('/rewards/$rewardId/redeem'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'id_usuario': userId, 'id_sesion': sessionId}),
        )
        .timeout(AppConfig.timeout);
    final j = await _jsonOrError(r);
    return RedeemResult.fromJson(j);
  }

  // ========== HISTORIAL DE SESIONES ==========
  @override
  Future<List<SessionHistory>> getSessionHistory(
    int userId, {
    int limit = 50,
  }) async {
    // Tu API real: GET /sessions?user=ID&limit=N
    final r = await _getWithCache(
      _u('/sessions', {'user': '$userId', 'limit': '$limit'}),
    );

    final j = await _jsonOrError(r);

    // _jsonOrError siempre devuelve un Map:
    // - Si la respuesta es una LISTA, la envuelve como {'data': [...]}
    // - Si es un objeto, la deja tal cual
    List rawList = const [];

    if (j['items'] is List) {
      rawList = j['items'] as List;
    } else if (j['data'] is List) {
      rawList = j['data'] as List;
    } else if (j['sessions'] is List) {
      rawList = j['sessions'] as List;
    } else if (j.isEmpty) {
      rawList = const [];
    }

    return rawList
        .map((e) => SessionHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Historial de canjes (endpoint real)
  @override
  Future<List<RedeemHistory>> getRedeemHistory(
    int userId, {
    int limit = 50,
  }) async {
    final r = await _getWithCache(
      _u('/users/$userId/redemptions', {'limit': '$limit'}),
    );

    final j = await _jsonOrError(r);
    final items = (j['items'] as List?) ?? [];

    return items
        .map((e) => RedeemHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
