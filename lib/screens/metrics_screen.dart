// lib/screens/metrics_screen.dart
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
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _sess,
          builder: (context, _) {
            return RefreshIndicator(
              onRefresh: _loadPoints,
              color: AppColors.accentGold,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Métricas',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analiza tu rendimiento y progreso',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Main Points Card
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
                            Icons.stars,
                            size: 48,
                            color: AppColors.accentGold,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _points?.toString() ?? '—',
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Puntos Totales',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Session Status Chips
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatusChip(
                          label: _sess.isSessionRunning
                              ? 'Sesión Activa'
                              : 'Sin Sesión',
                          icon: _sess.isSessionRunning
                              ? Icons.play_circle
                              : Icons.pause_circle,
                          isActive: _sess.isSessionRunning,
                          activeColor: AppColors.successColor,
                        ),
                        _StatusChip(
                          label: 'Tiempo: ${_fmt(_sess.elapsedSeconds)}',
                          icon: Icons.timer,
                          isActive: true,
                          activeColor: AppColors.primaryText,
                        ),
                        _StatusChip(
                          label: 'Alertas: ${deviceCtl.alertCount}',
                          icon: Icons.warning_amber_rounded,
                          isActive: deviceCtl.alertCount > 0,
                          activeColor: AppColors.errorColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Posture Status Card
                    Container(
                      padding: const EdgeInsets.all(20),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: deviceCtl.isOutOfPosture
                                  ? AppColors.errorColor.withOpacity(0.1)
                                  : AppColors.successColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              deviceCtl.isOutOfPosture
                                  ? Icons.report_problem
                                  : Icons.check_circle,
                              color: deviceCtl.isOutOfPosture
                                  ? AppColors.errorColor
                                  : AppColors.successColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estado de Postura',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkGray,
                                  ),
                                ),
                                Text(
                                  'Ángulo: ${deviceCtl.neckAngle.toStringAsFixed(1)}° • Umbral: ${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
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
                    const SizedBox(height: 32),

                    // Stats Links
                    Text(
                      'Análisis Detallado',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _FeatureCard(
                      icon: Icons.history,
                      title: 'Historial de Sesiones',
                      subtitle: 'Revisa tu actividad pasada',
                      color: AppColors.primaryText,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SessionHistoryScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FeatureCard(
                      icon: Icons.trending_up,
                      title: 'Tendencias y Rachas',
                      subtitle: 'Estadísticas semanales',
                      color: AppColors.accentGold,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TrendsScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FeatureCard(
                      icon: Icons.card_giftcard,
                      title: 'Historial de Canjes',
                      subtitle: 'Tus recompensas obtenidas',
                      color: AppColors.successColor,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RedeemHistoryScreen(),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
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
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(0.1) : AppColors.lightGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? activeColor.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? activeColor : AppColors.secondaryText,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? activeColor : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
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
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.lightGray),
          ],
        ),
      ),
    );
  }
}
