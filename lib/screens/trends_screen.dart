// lib/screens/trends_screen.dart
// CAMBIO: Nueva pantalla para mostrar tendencias semanales y rachas
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

  // Calcular estadísticas semanales
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

  // Calcular racha actual
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

  // Calcular datos diarios de la semana
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
          'Tendencias y Rachas',
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
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
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
                      color: AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryText,
                      foregroundColor: AppColors.backgroundColor,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Card de racha
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryColor.withOpacity(0.2),
                            AppColors.secondaryColor.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 48,
                            color: AppColors.warningColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$streak',
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGray,
                            ),
                          ),
                          Text(
                            streak == 1
                                ? 'día consecutivo'
                                : 'días consecutivos',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Estadísticas semanales
                  Text(
                    'Esta Semana',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Sesiones',
                          '${weeklyStats['sessions']}',
                          Icons.timer,
                          AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Minutos',
                          '${weeklyStats['totalMinutes']}',
                          Icons.access_time,
                          AppColors.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Alertas',
                          '${weeklyStats['totalAlerts']}',
                          Icons.warning_amber_rounded,
                          AppColors.errorColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Bonus',
                          '${weeklyStats['totalBonus']}',
                          Icons.stars,
                          AppColors.warningColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Gráfico de barras semanal
                  Text(
                    'Actividad Diaria',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 200,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: dailyData.map((day) {
                                final minutes = day['minutes'] as int;
                                final height = maxMinutes > 0
                                    ? (minutes / maxMinutes) * 180
                                    : 0.0;
                                final dayName = DateFormat('E', 'es')
                                    .format(day['date'] as DateTime)
                                    .substring(0, 1)
                                    .toUpperCase();

                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$minutes',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 30,
                                      height: height,
                                      decoration: BoxDecoration(
                                        color: minutes > 0
                                            ? AppColors.primaryColor
                                            : AppColors.lightGray,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dayName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
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
      ),
    );
  }
}
