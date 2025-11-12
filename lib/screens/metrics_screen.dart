// lib/screens/metrics_screen.dart
// CAMBIO: Mejoras en diseño y agregado de enlaces a nuevas funcionalidades
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../locator.dart';
import '../core/session_state.dart';
import '../core/api/api_service.dart';
import '../controllers/device_status_controller.dart';
import '../styles/colors.dart';
import 'session_history_screen.dart';
import 'trends_screen.dart';
import 'redeem_history_screen.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  final _api = locator<ApiService>();
  final _sess = locator<SessionState>();
  int? _points;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() {
      _error = null;
    });
    try {
      final p = await _api.getPoints(_sess.userId!);
      if (!mounted) return;
      setState(() => _points = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  String _fmt(int seconds) {
    final s = seconds % 60;
    final m = (seconds ~/ 60) % 60;
    final h = seconds ~/ 3600;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final deviceCtl = context.watch<DeviceStatusController>();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Métricas',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: _sess,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _loadPoints,
            color: AppColors.primaryColor,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // CAMBIO: Card de puntos mejorado
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
                          AppColors.primaryColor.withOpacity(0.1),
                          AppColors.secondaryColor.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.stars,
                          size: 48,
                          color: AppColors.warningColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _points?.toString() ?? '—',
                          style: GoogleFonts.poppins(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGray,
                          ),
                        ),
                        Text(
                          'Puntos totales',
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

                // CAMBIO: Chips mejorados
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        _sess.isSessionRunning ? 'Sesión activa' : 'Sin sesión',
                      ),
                      backgroundColor: _sess.isSessionRunning
                          ? AppColors.successColor.withOpacity(0.2)
                          : AppColors.lightGray,
                      avatar: Icon(
                        _sess.isSessionRunning
                            ? Icons.play_circle
                            : Icons.pause_circle,
                        size: 18,
                      ),
                    ),
                    Chip(
                      label: Text('Tiempo: ${_fmt(_sess.elapsedSeconds)}'),
                      backgroundColor: AppColors.lightGray,
                    ),
                    Chip(
                      label: Text('Alertas: ${deviceCtl.alertCount}'),
                      backgroundColor: deviceCtl.alertCount > 0
                          ? AppColors.errorColor.withOpacity(0.2)
                          : AppColors.lightGray,
                      avatar: Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: deviceCtl.alertCount > 0
                            ? AppColors.errorColor
                            : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // CAMBIO: Card de postura mejorado
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: deviceCtl.isOutOfPosture
                                ? AppColors.errorColor.withOpacity(0.1)
                                : AppColors.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            deviceCtl.isOutOfPosture
                                ? Icons.report_problem
                                : Icons.check_circle,
                            color: deviceCtl.isOutOfPosture
                                ? AppColors.errorColor
                                : AppColors.successColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Postura actual',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ángulo: ${deviceCtl.neckAngle.toStringAsFixed(1)}° • '
                                'Umbral: ${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // CAMBIO: Nuevas funcionalidades con diseño mejorado
                Text(
                  'Análisis y Estadísticas',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 12),

                _buildFeatureCard(
                  context,
                  icon: Icons.history,
                  title: 'Historial de Sesiones',
                  subtitle: 'Minutos, alertas y bonus de todas tus sesiones',
                  color: AppColors.primaryColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SessionHistoryScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildFeatureCard(
                  context,
                  icon: Icons.trending_up,
                  title: 'Tendencias y Rachas',
                  subtitle: 'Estadísticas semanales y días consecutivos',
                  color: AppColors.secondaryColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TrendsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildFeatureCard(
                  context,
                  icon: Icons.card_giftcard,
                  title: 'Historial de Canjes',
                  subtitle: 'Todos tus canjes y efecto de bonos',
                  color: AppColors.warningColor,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RedeemHistoryScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                if (_error != null) ...[
                  Card(
                    color: AppColors.errorColor.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.errorColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Error: $_error',
                              style: GoogleFonts.poppins(
                                color: AppColors.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
