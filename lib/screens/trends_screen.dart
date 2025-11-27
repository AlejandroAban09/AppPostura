// lib/screens/trends_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../locator.dart';
import '../core/session_state.dart';
import '../core/api/api_service.dart';
import '../models/session_models.dart';
import '../styles/colors.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  final _api = locator<ApiService>();
  final _sess = locator<SessionState>();

  List<SessionHistory> _sessions = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sessions = await _api.getSessionHistory(_sess.userId!, limit: 100);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _calculateWeeklyStats() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final weekSessions = _sessions.where((s) {
      final sessionDate = DateTime(
        s.startTime.year,
        s.startTime.month,
        s.startTime.day,
      );
      return sessionDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          sessionDate.isBefore(weekEnd.add(const Duration(days: 1)));
    }).toList();

    final totalMinutes = weekSessions.fold<int>(
      0,
      (sum, s) => sum + s.validMinutes,
    );
    final totalAlerts = weekSessions.fold<int>(0, (sum, s) => sum + s.alerts);
    final totalBonus = weekSessions.fold<int>(
      0,
      (sum, s) => sum + s.bonusApplied,
    );

    return {
      'sessions': weekSessions.length,
      'totalMinutes': totalMinutes,
      'totalAlerts': totalAlerts,
      'totalBonus': totalBonus,
      'avgMinutes': weekSessions.isEmpty
          ? 0
          : totalMinutes ~/ weekSessions.length,
    };
  }

  int _calculateStreak() {
    if (_sessions.isEmpty) return 0;

    final sortedSessions = List<SessionHistory>.from(_sessions)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    int streak = 0;
    DateTime? lastDate;

    for (final session in sortedSessions) {
      final sessionDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      if (lastDate == null) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final diff = todayDate.difference(sessionDate).inDays;

        if (diff == 0 || diff == 1) {
          streak = 1;
          lastDate = sessionDate;
        } else {
          break;
        }
      } else {
        final diff = lastDate.difference(sessionDate).inDays;
        if (diff == 1) {
          streak++;
          lastDate = sessionDate;
        } else if (diff > 1) {
          break;
        }
      }
    }

    return streak;
  }

  List<Map<String, dynamic>> _getDailyData() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return days.map((day) {
      final daySessions = _sessions.where((s) {
        final sessionDate = DateTime(
          s.startTime.year,
          s.startTime.month,
          s.startTime.day,
        );
        final dayDate = DateTime(day.year, day.month, day.day);
        return sessionDate == dayDate;
      }).toList();

      final minutes = daySessions.fold<int>(
        0,
        (sum, s) => sum + s.validMinutes,
      );

      return {'date': day, 'minutes': minutes, 'sessions': daySessions.length};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final weeklyStats = _calculateWeeklyStats();
    final streak = _calculateStreak();
    final dailyData = _getDailyData();
    final maxMinutes = dailyData.isEmpty
        ? 1
        : dailyData
              .map((d) => d['minutes'] as int)
              .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Tendencias',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentGold),
              )
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.errorColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar datos',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cardDark,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.accentGold,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rachas y Tendencias',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu constancia es clave para mejorar',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Streak Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 48,
                              color: AppColors.accentGold,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '$streak',
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              streak == 1
                                  ? 'Día Consecutivo'
                                  : 'Días Consecutivos',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Weekly Stats
                      Text(
                        'Esta Semana',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Sesiones',
                              value: '${weeklyStats['sessions']}',
                              icon: Icons.timer,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              label: 'Minutos',
                              value: '${weeklyStats['totalMinutes']}',
                              icon: Icons.access_time,
                              color: AppColors.accentGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Alertas',
                              value: '${weeklyStats['totalAlerts']}',
                              icon: Icons.warning_amber_rounded,
                              color: AppColors.errorColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              label: 'Bonus',
                              value: '${weeklyStats['totalBonus']}',
                              icon: Icons.stars,
                              color: AppColors.successColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Weekly Chart
                      Text(
                        'Actividad Diaria',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: 220,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: dailyData.map((day) {
                              final minutes = day['minutes'] as int;
                              final height = maxMinutes > 0
                                  ? (minutes / maxMinutes) * 160
                                  : 0.0;
                              final dayName = DateFormat('E', 'es')
                                  .format(day['date'] as DateTime)
                                  .substring(0, 1)
                                  .toUpperCase();

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (minutes > 0)
                                    Text(
                                      '$minutes',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: AppColors.secondaryText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 24,
                                    height: height > 0 ? height : 4,
                                    decoration: BoxDecoration(
                                      color: minutes > 0
                                          ? AppColors.cardDark
                                          : AppColors.lightGray.withOpacity(
                                              0.3,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    dayName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
