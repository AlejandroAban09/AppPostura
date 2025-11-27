// lib/services/http_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '/config.dart';
import 'api_service.dart';
import '/features/rewards/models/reward.dart';
import '/features/rewards/models/redeem_result.dart';
import '/models/session_models.dart';

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

  // ========== AUTH ==========
  @override
  Future<AuthResult> authSimpleGet(String userOrEmail, String pass) async {
    final r = await _client
        .get(_u('/auth', {'user': userOrEmail, 'pass': pass}))
        .timeout(AppConfig.timeout);
    final j = await _jsonOrError(r);
    return AuthResult(j['id_usuario'] as int, j['display_name'] as String?);
  }

  @override
  Future<AuthResult> registerUser(String username, String password) async {
    // Intentar diferentes endpoints posibles
    List<String> endpoints = [
      '/register',
      '/auth/register',
      '/users/register',
      '/users',
    ];

    for (String endpoint in endpoints) {
      try {
        final r = await _client
            .post(
              _u(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'username': username, 'password': password}),
            )
            .timeout(AppConfig.timeout);

        if (r.statusCode == 404) {
          // Este endpoint no existe, intentar el siguiente
          continue;
        }

        final j = await _jsonOrError(r);
        return AuthResult(j['id_usuario'] as int, j['display_name'] as String?);
      } catch (e) {
        // Si es 404, continuar con el siguiente endpoint
        if (e.toString().contains('404')) {
          continue;
        }
        // Si es otro error, lanzarlo
        rethrow;
      }
    }

    // Si todos los endpoints fallaron con 404, lanzar error
    throw Exception(
      'HTTP 404: El endpoint de registro no está disponible en el servidor',
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    // Intentar diferentes endpoints posibles para solicitar restablecimiento
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
          // Este endpoint no existe, intentar el siguiente
          continue;
        }

        await _jsonOrError(r);
        return; // Éxito
      } catch (e) {
        // Si es 404, continuar con el siguiente endpoint
        if (e.toString().contains('404')) {
          continue;
        }
        // Si es otro error, lanzarlo
        rethrow;
      }
    }

    // Si todos los endpoints fallaron con 404, lanzar error
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
    // Intentar diferentes endpoints posibles para verificar código y restablecer
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
          // Este endpoint no existe, intentar el siguiente
          continue;
        }

        await _jsonOrError(r);
        return; // Éxito
      } catch (e) {
        // Si es 404, continuar con el siguiente endpoint
        if (e.toString().contains('404')) {
          continue;
        }
        // Si es otro error, lanzarlo
        rethrow;
      }
    }

    // Si todos los endpoints fallaron con 404, lanzar error
    throw Exception(
      'HTTP 404: El endpoint de verificación de código no está disponible en el servidor',
    );
  }

  // ========== AJUSTES ==========
  @override
  Future<UserSettings> getUserSettings(int userId) async {
    final r = await _client
        .get(_u('/users/$userId/settings'))
        .timeout(AppConfig.timeout);
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
    final r = await _client
        .get(_u('/users/$userId/points'))
        .timeout(AppConfig.timeout);
    final j = await _jsonOrError(r);
    return (j['saldo'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<LedgerItem>> getLedger(int userId, {int limit = 50}) async {
    final r = await _client
        .get(_u('/users/$userId/points/ledger', {'limit': '$limit'}))
        .timeout(AppConfig.timeout);
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
    final r = await _client
        .get(_u('/catalog/rewards', qp))
        .timeout(AppConfig.timeout);
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

  // CAMBIO: Nuevo método para obtener historial de sesiones
  @override
  Future<List<SessionHistory>> getSessionHistory(
    int userId, {
    int limit = 50,
  }) async {
    // Intentar diferentes endpoints posibles
    List<String> endpoints = [
      '/users/$userId/sessions',
      '/sessions',
      '/sessions/history',
      '/users/$userId/history',
    ];

    for (String endpoint in endpoints) {
      try {
        final Map<String, String> params = {'limit': '$limit'};
        // Si el endpoint no incluye el ID en la ruta (no tiene /users/ID/...),
        // agregamos los posibles nombres de parámetros que el backend podría esperar.
        if (!endpoint.contains('/users/')) {
          params['id_usuario'] = userId.toString();
          params['user_id'] = userId.toString();
          params['user'] = userId
              .toString(); // Encontrado en openapi.json para /sessions
        }

        final r = await _client
            .get(_u(endpoint, params))
            .timeout(AppConfig.timeout);

        // Si es 404 (Not Found) o 422 (Unprocessable Entity - params incorrectos para este endpoint),
        // probamos el siguiente.
        if (r.statusCode == 404 || r.statusCode == 422) {
          continue;
        }

        final j = await _jsonOrError(r);
        // Algunos endpoints pueden devolver la lista directamente o dentro de 'items'
        final List rawList;
        // _jsonOrError siempre devuelve un Map. Si la respuesta original era una lista,
        // estará en j['data'].
        if (j['items'] != null && j['items'] is List) {
          rawList = j['items'];
        } else if (j['data'] != null && j['data'] is List) {
          rawList = j['data'];
        } else {
          rawList = [];
        }

        return rawList
            .map((e) => SessionHistory.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Si es 404 o 422, continuar con el siguiente endpoint
        final msg = e.toString();
        if (msg.contains('404') || msg.contains('422')) {
          continue;
        }
        // Si es otro error, lanzarlo
        rethrow;
      }
    }

    // Si todos los endpoints fallaron, retornar lista vacía
    return [];
  }

  // CAMBIO: Nuevo método para obtener historial de canjes
  @override
  Future<List<RedeemHistory>> getRedeemHistory(
    int userId, {
    int limit = 50,
  }) async {
    // Intentar diferentes endpoints
    List<String> endpoints = [
      '/users/$userId/redeems',
      '/users/$userId/redeem-history',
      '/users/$userId/canjes', // Intento en español
      '/users/$userId/rewards/history',
      '/redeems',
      '/rewards/history',
      '/history/redeems',
    ];

    for (String endpoint in endpoints) {
      try {
        final Map<String, String> params = {'limit': '$limit'};
        if (!endpoint.contains('/users/')) {
          params['id_usuario'] = userId.toString();
        }

        final r = await _client
            .get(_u(endpoint, params))
            .timeout(AppConfig.timeout);

        if (r.statusCode == 404 || r.statusCode == 422) {
          continue;
        }

        final j = await _jsonOrError(r);
        final List rawList;

        // Buscar la lista en varias claves posibles
        if (j['items'] != null && j['items'] is List) {
          rawList = j['items'];
        } else if (j['data'] != null && j['data'] is List) {
          rawList = j['data'];
        } else if (j['history'] != null && j['history'] is List) {
          rawList = j['history'];
        } else if (j['redeems'] != null && j['redeems'] is List) {
          rawList = j['redeems'];
        } else if (j['canjes'] != null && j['canjes'] is List) {
          rawList = j['canjes'];
        } else if (j['results'] != null && j['results'] is List) {
          rawList = j['results'];
        } else {
          // Si no encontramos una lista en las claves conocidas, asumimos vacío
          // (o podríamos intentar devolver j si j fuera una lista, pero _jsonOrError devuelve Map)
          rawList = [];
        }

        return rawList
            .map((e) => RedeemHistory.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('404') || msg.contains('422')) {
          continue;
        }
        // Si falla el parseo (fromJson), intentamos el siguiente endpoint
        // asumiendo que este no era el correcto o devolvió basura.
        continue;
      }
    }
    return [];
  }
}
