import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:focusme_app/models/session_models.dart';

// Copying logic from TrendsScreen for testing purposes since it's private
int calculateStreak(List<SessionHistory> sessions) {
  if (sessions.isEmpty) return 0;

  // 1. Agrupar fechas con actividad
  final activeDates = <String>{};
  for (var s in sessions) {
    final local = s.startTime.toLocal();
    final dateStr = DateFormat('yyyy-MM-dd').format(local);
    activeDates.add(dateStr);
  }

  // 2. Contar racha hacia atrás
  int streak = 0;
  var checkDate = DateTime.now();

  // Verificar si hoy tiene actividad
  var dateStr = DateFormat('yyyy-MM-dd').format(checkDate);

  // Si hoy no tiene actividad, verificar ayer (para no romper la racha si aún no practico hoy)
  if (!activeDates.contains(dateStr)) {
    checkDate = checkDate.subtract(const Duration(days: 1));
    dateStr = DateFormat('yyyy-MM-dd').format(checkDate);

    if (!activeDates.contains(dateStr)) {
      return 0; // Ni hoy ni ayer => racha 0
    }
  }

  // Contar días consecutivos hacia atrás
  while (activeDates.contains(dateStr)) {
    streak++;
    checkDate = checkDate.subtract(const Duration(days: 1));
    dateStr = DateFormat('yyyy-MM-dd').format(checkDate);
  }

  return streak;
}

void main() {
  test('Streak calculation - empty sessions', () {
    expect(calculateStreak([]), 0);
  });

  test('Streak calculation - today only', () {
    final now = DateTime.now();
    final sessions = [
      SessionHistory(
        sessionId: 1,
        startTime: now,
        validMinutes: 10,
        alerts: 0,
        bonusApplied: 0,
      ),
    ];
    expect(calculateStreak(sessions), 1);
  });

  test('Streak calculation - yesterday only (should be 1)', () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final sessions = [
      SessionHistory(
        sessionId: 1,
        startTime: yesterday,
        validMinutes: 10,
        alerts: 0,
        bonusApplied: 0,
      ),
    ];
    expect(calculateStreak(sessions), 1);
  });

  test('Streak calculation - today and yesterday (should be 2)', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final sessions = [
      SessionHistory(
        sessionId: 1,
        startTime: now,
        validMinutes: 10,
        alerts: 0,
        bonusApplied: 0,
      ),
      SessionHistory(
        sessionId: 2,
        startTime: yesterday,
        validMinutes: 10,
        alerts: 0,
        bonusApplied: 0,
      ),
    ];
    expect(calculateStreak(sessions), 2);
  });

  test('Streak calculation - gap day (should be 0 or 1 depending on gap)', () {
    // Today: No
    // Yesterday: No
    // 2 days ago: Yes
    // Should be 0
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    final sessions = [
      SessionHistory(
        sessionId: 1,
        startTime: twoDaysAgo,
        validMinutes: 10,
        alerts: 0,
        bonusApplied: 0,
      ),
    ];
    expect(calculateStreak(sessions), 0);
  });

  test('Streak calculation - 3 days streak', () {
    final now = DateTime.now();
    final d1 = now.subtract(const Duration(days: 1));
    final d2 = now.subtract(const Duration(days: 2));

    final sessions = [
      SessionHistory(
        sessionId: 1,
        startTime: now,
        validMinutes: 10,
        alerts: 0,
        bonusApplied: 0,
      ),
      SessionHistory(
        sessionId: 2,
        startTime: d1,
        validMinutes: 10,
        alerts: 0,
        bonusApplied: 0,
      ),
      SessionHistory(
        sessionId: 3,
        startTime: d2,
        validMinutes: 10,
        alerts: 0,
        bonusApplied: 0,
      ),
    ];
    expect(calculateStreak(sessions), 3);
  });
}
