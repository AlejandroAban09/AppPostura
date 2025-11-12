// lib/core/posture/posture_engine.dart
class PostureResult {
  final bool triggeredAlert;
  final bool isGoodPosture;
  final int sampleSeconds;
  PostureResult(this.triggeredAlert, this.isGoodPosture, this.sampleSeconds);
}

class PostureEngine {
  double thresholdDeg; // p.ej. 20°
  Duration sustain;    // p.ej. 3s
  DateTime? _badSince;

  PostureEngine({this.thresholdDeg = 20, this.sustain = const Duration(seconds: 3)});

  PostureResult push(reading) {
    final ts = reading.ts;
    final bad = reading.neckAngle > thresholdDeg;
    bool alert = false;
    bool good = !bad;

    if (bad) {
      _badSince ??= ts;
      if (ts.difference(_badSince!).abs() >= sustain) {
        alert = true;
      }
    } else {
      _badSince = null;
    }

    return PostureResult(alert, good, 1);
  }
}
