// import 'dart:async';
import 'package:flutter/foundation.dart';

/// Controlador único para el collar (BLE).
/// Mantiene ángulos, calibración, umbral y cuenta alertas.
class DeviceStatusController extends ChangeNotifier {
  // Conexión / identificación
  bool _connected = false;
  String? _deviceId;
  String? _deviceMac;

  // Postura
  double? _baseNeckAngle;          // referencia calibrada
  double _neckAngle = 0;           // último ángulo recibido
  double _thresholdDeg = 20;       // umbral en grados (sensibilidad)

  // Alertas (conteo durante la sesión)
  int _alertCount = 0;

  // Anti-ruido / debouncing
  bool _isCurrentlyOut = false;          // estado actual (según umbral)
  DateTime? _outStart;                   // cuándo empezó a estar fuera
  bool _alertFiredForThisExcursion = false;
  final int _minBadSecondsToAlert = 2;   // segundos sostenidos para contar alerta

  // Getters
  bool get connected => _connected;
  String? get deviceId => _deviceId;
  String? get deviceMac => _deviceMac;

  double get neckAngle => _neckAngle;
  double? get baseNeckAngle => _baseNeckAngle;
  double get thresholdDeg => _thresholdDeg;

  int get alertCount => _alertCount;

  bool get hasBase => _baseNeckAngle != null;
  double get _deltaFromBase =>
      hasBase ? (_neckAngle - _baseNeckAngle!).abs() : 0;

  /// ¿Está fuera de postura (instantáneo, sin debouncing)?
  bool get isOutOfPostureInstant =>
      hasBase ? _deltaFromBase > _thresholdDeg : false;

  /// ¿Está fuera de postura y ya disparó alerta (tras sostener el tiempo)?
  bool get isOutOfPosture => _isCurrentlyOut;

  // Setters / acciones
  void setConnected(bool v, {String? id, String? mac}) {
    _connected = v;
    _deviceId = id ?? _deviceId;
    _deviceMac = mac ?? _deviceMac;
    notifyListeners();
  }

  void setThreshold(double deg) {
    _thresholdDeg = deg.clamp(5, 45);
    notifyListeners();
  }

  void calibrateNow() {
    _baseNeckAngle = _neckAngle;
    // Reinicia estado de excursión
    _isCurrentlyOut = false;
    _outStart = null;
    _alertFiredForThisExcursion = false;
    notifyListeners();
  }

  void clearCalibration() {
    _baseNeckAngle = null;
    _isCurrentlyOut = false;
    _outStart = null;
    _alertFiredForThisExcursion = false;
    notifyListeners();
  }

  /// Llama esto cada vez que llega un ángulo nuevo desde BLE.
  void updateNeckAngle(double value) {
    _neckAngle = value;

    if (!hasBase) {
      notifyListeners();
      return;
    }

    final outNow = _deltaFromBase > _thresholdDeg;

    if (outNow) {
      if (!_isCurrentlyOut) {
        // Entró a mala postura
        _isCurrentlyOut = true;
        _outStart = DateTime.now();
        _alertFiredForThisExcursion = false;
      } else {
        // Sigue fuera, verifica si ya pasaron los 2s
        if (!_alertFiredForThisExcursion && _outStart != null) {
          final secs = DateTime.now().difference(_outStart!).inSeconds;
          if (secs >= _minBadSecondsToAlert) {
            _alertCount += 1;
            _alertFiredForThisExcursion = true;
          }
        }
      }
    } else {
      // Volvió a postura aceptable -> resetea excursión
      _isCurrentlyOut = false;
      _outStart = null;
      _alertFiredForThisExcursion = false;
    }

    notifyListeners();
  }

  /// Para reiniciar las alertas al iniciar una nueva sesión, si deseas.
  void resetAlerts() {
    _alertCount = 0;
    notifyListeners();
  }
}
