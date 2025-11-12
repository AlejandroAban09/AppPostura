// lib/features/session_health/models/session.dart
class Session {
  final int id;
  final DateTime start;
  final DateTime? end;
  final int validMinutes;
  final int alerts;
  Session({required this.id, required this.start, this.end, this.validMinutes = 0, this.alerts = 0});
}

