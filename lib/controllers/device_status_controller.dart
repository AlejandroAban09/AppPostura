// lib/controllers/device_status_controller.dart
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class DeviceStatusController extends ChangeNotifier {
  // Estado de conexión
  bool _connected = false;
  String? _deviceId;
  String? _deviceMac;

  // Ángulos
  double _neckAngle = 0.0; // último ángulo recibido (en grados)
  double? _baseNeckAngle; // referencia "aquí estoy bien"
  double _thresholdDeg = 15.0; // umbral de mala postura en grados

  // Alertas y detección de mala postura
  int _alertCount = 0;
  bool _isCurrentlyOut = false;
  DateTime? _outStart;
  bool _alertFiredForThisExcursion = false;
  final int _minBadSecondsToAlert;
  final NotificationService _notificationService;

  DeviceStatusController({
    int minBadSecondsToAlert = 3,
    NotificationService? notificationService,
  }) : _minBadSecondsToAlert = minBadSecondsToAlert,
       _notificationService = notificationService ?? NotificationService();

  // Getters para la UI
  bool get connected => _connected;
  String? get deviceId => _deviceId;
  String? get deviceMac => _deviceMac;

  double get neckAngle => _neckAngle;
  double? get baseNeckAngle => _baseNeckAngle;
  double get thresholdDeg => _thresholdDeg;

  int get alertCount => _alertCount;
  bool get isOutOfPosture => _isCurrentlyOut;

  // Marcar collar conectado / desconectado
  void setConnected(bool value, {String? id, String? mac}) {
    _connected = value;

    if (!value) {
      _deviceId = null;
      _deviceMac = null;
      _isCurrentlyOut = false;
      _outStart = null;
      _alertFiredForThisExcursion = false;
    } else {
      _deviceId = id ?? _deviceId;
      _deviceMac = mac ?? _deviceMac;

      // Notificar conexión exitosa
      _notificationService.showNotification(
        id: 1,
        title: 'Dispositivo Conectado',
        body: 'El dispositivo $_deviceId se ha conectado correctamente.',
      );
    }

    notifyListeners();
  }

  // Ajustar umbral (slider)
  void setThreshold(double deg) {
    _thresholdDeg = deg;
    notifyListeners();
  }

  // Calibrar usando el ángulo actual como postura correcta
  void calibrateNow() {
    if (!_connected) return;
    _baseNeckAngle = _neckAngle;
    _isCurrentlyOut = false;
    _outStart = null;
    _alertFiredForThisExcursion = false;
    notifyListeners();
  }

  // Quitar calibración manual
  void clearCalibration() {
    _baseNeckAngle = null;
    _isCurrentlyOut = false;
    _outStart = null;
    _alertFiredForThisExcursion = false;
    notifyListeners();
  }

  // Resetear contador de alertas (por ejemplo al iniciar nueva sesión)
  void resetAlerts() {
    _alertCount = 0;
    _isCurrentlyOut = false;
    _outStart = null;
    _alertFiredForThisExcursion = false;
    notifyListeners();
  }

  /// Llamar esto CADA VEZ que llega un ángulo nuevo desde BLE.
  ///
  /// Aquí se decide si estás en mala postura (fuera de umbral) y,
  /// si te quedas así al menos _minBadSecondsToAlert, se incrementa alertCount.
  void updateNeckAngle(double angle) {
    _neckAngle = angle;

    // Si no hay calibración aún, tomamos el primer ángulo como referencia
    final double ref;
    if (_baseNeckAngle == null) {
      ref = _neckAngle;
    } else {
      ref = _baseNeckAngle!;
    }

    final double delta = (_neckAngle - ref).abs();
    final now = DateTime.now();
    final bool isOut = delta > _thresholdDeg;

    if (isOut) {
      if (!_isCurrentlyOut) {
        // Empezó una nueva excursión de mala postura
        _isCurrentlyOut = true;
        _outStart = now;
        _alertFiredForThisExcursion = false;
      } else if (!_alertFiredForThisExcursion && _outStart != null) {
        final secs = now.difference(_outStart!).inSeconds;
        if (secs >= _minBadSecondsToAlert) {
          _alertCount++;
          _alertFiredForThisExcursion = true;

          // Notificar mala postura
          _notificationService.showNotification(
            id: 2,
            title: '¡Mala Postura Detectada!',
            body: 'Por favor, corrige tu postura para evitar dolores.',
          );
        }
      }
    } else {
      // Volvió a buena postura
      _isCurrentlyOut = false;
      _outStart = null;
      _alertFiredForThisExcursion = false;
    }

    notifyListeners();
  }
}
