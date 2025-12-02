// lib/models/session_models.dart

/// Resultado del login simple /auth
class AuthResult {
  final int userId;
  final String? displayName;
  AuthResult(this.userId, this.displayName);
}

/// Ajustes del usuario /users/{id}/settings
class UserSettings {
  double umbralCuelloDeg;
  int sensibilidadSeg;

  UserSettings({this.umbralCuelloDeg = 20, this.sensibilidadSeg = 3});

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
    umbralCuelloDeg: (j['umbral_cuello_deg'] as num).toDouble(),
    sensibilidadSeg: j['sensibilidad_seg'] as int,
  );

  Map<String, dynamic> toJson() => {
    'umbral_cuello_deg': umbralCuelloDeg,
    'sensibilidad_seg': sensibilidadSeg,
  };
}

/// Iniciar sesión de postura /sessions/start
class SessionStart {
  final int userId;
  final String? deviceName;
  final String? deviceMac;
  final String validationSource;

  SessionStart({
    required this.userId,
    this.deviceName,
    this.deviceMac,
    this.validationSource = 'BLE',
  });

  Map<String, dynamic> toJson() => {
    'id_usuario': userId,
    'device_name': deviceName,
    'device_mac': deviceMac,
    'validation_source': validationSource,
  };
}

/// Finalizar sesión de postura /sessions/{id}/finish
class SessionFinish {
  final int validMinutes;
  final int alerts;
  final String? ssid;

  SessionFinish({required this.validMinutes, required this.alerts, this.ssid});

  Map<String, dynamic> toJson() => {
    'valid_minutes': validMinutes,
    'alerts': alerts,
    'ssid': ssid,
  };
}

/// Respuesta de finish session
class FinishResponse {
  final int validMinutes;
  final int alerts;
  final int bonusApplied;
  final int saldo;

  FinishResponse(this.validMinutes, this.alerts, this.bonusApplied, this.saldo);

  factory FinishResponse.fromJson(Map<String, dynamic> j) => FinishResponse(
    (j['valid_minutes'] ?? 0) as int,
    (j['alerts'] ?? 0) as int,
    (j['bonus_applied'] ?? 0) as int,
    (j['saldo'] ?? 0) as int,
  );
}

/// Lectura /posture/{sessionId}/reading
class Reading {
  final double neckAngle;
  final double? shoulderAngle;
  final bool alert;

  Reading({required this.neckAngle, this.shoulderAngle, this.alert = false});

  Map<String, dynamic> toJson() => {
    'neck_angle': neckAngle,
    'shoulder_angle': shoulderAngle,
    'alert': alert,
  };
}

/// Item del ledger de puntos /users/{id}/points/ledger
class LedgerItem {
  final DateTime ts;
  final String sourceType;
  final int? sourceId;
  final int points;
  final String? descripcion;

  LedgerItem(
    this.ts,
    this.sourceType,
    this.sourceId,
    this.points,
    this.descripcion,
  );

  factory LedgerItem.fromJson(Map<String, dynamic> j) => LedgerItem(
    DateTime.parse(j['ts'] as String),
    j['source_type'] as String,
    j['source_id'] as int?,
    (j['points'] as num).toInt(),
    j['descripcion'] as String?,
  );
}

/// Historial de sesiones
class SessionHistory {
  final int sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final int validMinutes;
  final int alerts;
  final int bonusApplied;
  final String? ssid;
  final String? deviceName;

  SessionHistory({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.validMinutes,
    required this.alerts,
    required this.bonusApplied,
    this.ssid,
    this.deviceName,
  });

  factory SessionHistory.fromJson(Map<String, dynamic> j) => SessionHistory(
    sessionId: (j['id_sesion'] ?? j['id'] ?? 0) as int,
    startTime:
        DateTime.tryParse(
          (j['start_time'] ?? j['created_at'] ?? j['date'] ?? j['ts'] ?? '')
              .toString(),
        ) ??
        DateTime(1970),
    endTime: j['end_time'] != null
        ? DateTime.parse(j['end_time'] as String)
        : null,
    validMinutes: (j['valid_minutes'] ?? j['minutes'] ?? 0) as int,
    alerts: (j['alerts'] ?? 0) as int,
    bonusApplied: (j['bonus_applied'] ?? j['bonus'] ?? 0) as int,
    ssid: j['ssid'] as String?,
    deviceName: (j['device_name'] ?? j['device']) as String?,
  );
}

/// Historial de canjes
class RedeemHistory {
  final int redeemId;
  final DateTime timestamp;
  final int rewardId;
  final String rewardName;
  final int pointsSpent;
  final int? sessionId;
  final int bonusApplied;
  final String? tokenCode;

  RedeemHistory({
    required this.redeemId,
    required this.timestamp,
    required this.rewardId,
    required this.rewardName,
    required this.pointsSpent,
    this.sessionId,
    required this.bonusApplied,
    this.tokenCode,
  });

  factory RedeemHistory.fromJson(Map<String, dynamic> j) => RedeemHistory(
    // 👇 tu API usa id_redemption
    redeemId: (j['id_redemption'] ?? j['id'] ?? 0) as int,

    // 👇 tu API usa created_at
    timestamp: DateTime.parse(
      (j['created_at'] ??
              j['ts'] ??
              j['date'] ??
              DateTime.now().toIso8601String())
          as String,
    ),

    // De momento tu JSON no manda id de recompensa, lo dejamos en 0
    rewardId: (j['reward_id'] ?? 0) as int,

    // 👇 tu API usa reward_name
    rewardName:
        (j['reward_name'] ?? j['nombre_recompensa']) as String? ?? 'Recompensa',

    // 👇 tu API usa cost_points
    pointsSpent:
        (j['cost_points'] ?? j['puntos_gastados'] ?? j['points'] ?? 0) as int,

    // Tu JSON actual no lleva estos, pero los dejamos preparados
    sessionId: (j['id_sesion'] ?? j['session_id']) as int?,
    bonusApplied: (j['bonus_aplicado'] ?? j['bonus'] ?? 0) as int,
    tokenCode: (j['token_code'] ?? j['code']) as String?,
  );
}
