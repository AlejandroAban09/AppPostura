// lib/screens/dashboard_screen.dart
// CAMBIO: Mejoras en diseño, cambio SSID por QR, validación de dispositivo conectado
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../locator.dart';
import '../core/session_state.dart';
import '../core/api/api_service.dart';
import '../models/session_models.dart';
import '../controllers/device_status_controller.dart';
import '../widgets/qr_scanner_widget.dart';
import '../styles/colors.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = locator<ApiService>();
  final _sess = locator<SessionState>();

  int _points = 0;
  bool _loading = false;
  String? _ssid; // CAMBIO: Cambiado de TextEditingController a String para QR

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPoints() async {
    try {
      final saldo = await _api.getPoints(_sess.userId!);
      if (!mounted) return;
      setState(() => _points = saldo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Puntos: $e')));
    }
  }

  // CAMBIO: Validación de dispositivo conectado antes de iniciar sesión
  Future<void> _startSession(DeviceStatusController deviceCtl) async {
    if (_sess.currentSessionId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ya hay una sesión activa.'),
          backgroundColor: AppColors.warningColor,
        ),
      );
      return;
    }

    // CAMBIO: Validar si hay dispositivo conectado
    if (!deviceCtl.connected) {
      final shouldContinue = await _showDeviceWarningDialog();
      if (!shouldContinue) {
        return; // El usuario canceló
      }
    }

    setState(() => _loading = true);
    try {
      deviceCtl.resetAlerts(); // reinicia alertas al iniciar
      final id = await _api.startSession(
        SessionStart(
          userId: _sess.userId!,
          deviceName: deviceCtl.deviceId ?? 'FocusCollar',
          deviceMac: deviceCtl.deviceMac ?? 'AA:BB:CC:DD',
        ),
      );
      _sess.setSessionId(id);
      _sess.startSessionTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesión iniciada (#$id)'),
          backgroundColor: AppColors.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // CAMBIO: Nuevo método para mostrar advertencia de dispositivo no conectado
  Future<bool> _showDeviceWarningDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warningColor,
                ),
                const SizedBox(width: 8),
                const Text('Dispositivo no conectado'),
              ],
            ),
            content: const Text(
              'No hay dispositivos conectados. Los puntos no se contarán durante esta sesión.\n\n'
              '¿Deseas continuar de todas formas?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryText,
                  foregroundColor: AppColors.backgroundColor,
                ),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _finishSession(DeviceStatusController deviceCtl) async {
    final sessionId = _sess.currentSessionId;
    if (sessionId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No hay sesión activa.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final validMinutes = _sess.stopSessionTimer();
      final ssid = _ssid; // CAMBIO: Usar el SSID del QR
      final alerts = deviceCtl.alertCount;

      final resp = await _api.finishSession(
        sessionId,
        SessionFinish(validMinutes: validMinutes, alerts: alerts, ssid: ssid),
      );

      _sess.setSessionId(null);
      if (!mounted) return;
      setState(() => _points = resp.saldo);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sesión finalizada: +${resp.validMinutes} min, '
            'alertas $alerts (bonus ${resp.bonusApplied}). Saldo: ${resp.saldo}',
          ),
        ),
      );
    } catch (e) {
      _sess.startSessionTimer(); // si falla, reanuda para no perder conteo
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Finish: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDuration(int seconds) {
    final s = seconds % 60;
    final m = (seconds ~/ 60) % 60;
    final h = seconds ~/ 3600;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  // CAMBIO: Método para abrir el lector QR
  void _openQRScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerWidget(
          initialValue: _ssid,
          onQRCodeScanned: (value) {
            setState(() {
              _ssid = value;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _sess.displayName ?? 'Usuario';
    final deviceCtl = context.watch<DeviceStatusController>();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: _sess,
        builder: (context, _) {
          final running = _sess.isSessionRunning;
          final elapsed = _sess.elapsedSeconds;
          final sessionId = _sess.currentSessionId;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // CAMBIO: Mejora en el diseño del saludo
              Card(
                color: AppColors.primaryColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primaryColor,
                        child: Text(
                          name[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hola, $name',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkGray,
                              ),
                            ),
                            Text(
                              'Puntos: $_points',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
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
              const SizedBox(height: 16),

              // CAMBIO: Chips mejorados
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      'Sesión: ${sessionId == null ? 'Sin sesión' : '#$sessionId'}',
                    ),
                    backgroundColor: AppColors.lightGray,
                    avatar: Icon(
                      sessionId == null
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      size: 18,
                    ),
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
                  Chip(
                    label: Text(
                      deviceCtl.connected ? 'Conectado' : 'Desconectado',
                    ),
                    backgroundColor: deviceCtl.connected
                        ? AppColors.successColor.withOpacity(0.2)
                        : AppColors.warningColor.withOpacity(0.2),
                    avatar: Icon(
                      deviceCtl.connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      size: 18,
                      color: deviceCtl.connected
                          ? AppColors.successColor
                          : AppColors.warningColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // CAMBIO: Alerta de mala postura mejorada
              if (deviceCtl.connected && deviceCtl.isOutOfPosture) ...[
                Card(
                  color: AppColors.errorColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.errorColor, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.report_problem,
                          color: AppColors.errorColor,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¡Mala postura detectada!',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.errorColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ángulo: ${deviceCtl.neckAngle.toStringAsFixed(1)}° '
                                '• Umbral: ${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
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
                const SizedBox(height: 16),
              ],

              // CAMBIO: Card de tiempo mejorado
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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiempo actual',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fmtDuration(elapsed),
                          style: GoogleFonts.poppins(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGray,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          running
                              ? 'Sesión en curso…'
                              : 'Pulsa "Iniciar sesión" para comenzar.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CAMBIO: Botón para escanear QR en lugar de TextField
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SSID (Opcional)',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.lightGray,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _ssid != null
                                      ? AppColors.primaryColor
                                      : AppColors.lightGray,
                                ),
                              ),
                              child: Text(
                                _ssid ?? 'No escaneado',
                                style: GoogleFonts.poppins(
                                  color: _ssid != null
                                      ? AppColors.darkGray
                                      : AppColors.secondaryText,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _openQRScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Escanear QR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryText,
                              foregroundColor: AppColors.backgroundColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CAMBIO: Botones mejorados
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading || running
                          ? null
                          : () => _startSession(deviceCtl),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar sesión'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryText,
                        foregroundColor: AppColors.backgroundColor,
                        disabledBackgroundColor: AppColors.lightGray,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading || !running
                          ? null
                          : () => _finishSession(deviceCtl),
                      icon: const Icon(Icons.stop),
                      label: const Text('Finalizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.lightGray,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
