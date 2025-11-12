// lib/features/posture/models/posture_reading.dart
class PostureReading {
  final int? sessionId;
  final DateTime ts;
  final double neckAngle;
  final double? shoulderAngle;
  PostureReading({this.sessionId, required this.ts, required this.neckAngle, this.shoulderAngle});
}

