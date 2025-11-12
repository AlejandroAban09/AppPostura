// lib/features/session_health/session_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '/core/posture/posture_engine.dart';
import '/features/posture/models/posture_reading.dart';

class SessionController extends ChangeNotifier {
  bool _running = false;
  DateTime? _start;
  Timer? _ticker;
  int _validSeconds = 0;
  int _alerts = 0;

  final PostureEngine engine;
  SessionController({required this.engine});

  bool get isRunning => _running;
  int get validMinutes => (_validSeconds ~/ 60);
  int get alerts => _alerts;
  DateTime? get startTime => _start;

  void start() {
    if (_running) return;
    _running = true;
    _start = DateTime.now();
    _validSeconds = 0;
    _alerts = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _running = false;
    notifyListeners();
  }

  // Llamar desde BLE cada lectura
  void onReading(PostureReading r) {
    final result = engine.push(r);
    if (result.triggeredAlert) {
      _alerts++;
    }
    if (result.isGoodPosture) {
      _validSeconds += result.sampleSeconds; // p.ej. 1s por lectura/seg
    }
    if (_running) notifyListeners();
  }
}
