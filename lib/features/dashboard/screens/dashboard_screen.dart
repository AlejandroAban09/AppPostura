// lib/screens/dashboard_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../locator.dart';
import '../../../core/session_state.dart';
import '../../../core/api/api_service.dart';
import '../../../models/session_models.dart';
import '../../../controllers/device_status_controller.dart';
import '../../../services/storage_service.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/qr_scanner_widget.dart';
import '../../../widgets/custom_dialog.dart';
import '../../../styles/colors.dart';

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
  static const Duration _bonusDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _trySync();
  }

  Future<void> _trySync() async {
    // Intentar sincronizar sesiones pendientes en segundo plano
    try {
      final count = await StorageService().syncPendingSessions();
      if (count > 0 && mounted) {
        _showPopup(
          'Sincronización Completada',
          'Se han subido $count sesiones pendientes.',
          color: AppColors.successColor,
          icon: Icons.cloud_upload,
        );
        _loadPoints(); // Recargar puntos actualizados
      }
    } catch (_) {
      // Silencioso si falla (probablemente sigue offline)
    }
  }

  void _showPopup(
    String title,
    String message, {
    Color? color,
    IconData? icon,
  }) {
    CustomDialog.show(
      context: context,
      title: title,
      message: message,
      color: color,
      icon: icon ?? Icons.info,
    );
  }

  Future<void> _loadPoints() async {
    final box = Hive.box('focusme_users');
    try {
      final saldo = await _api.getPoints(_sess.userId!);
      if (!mounted) return;
      setState(() => _points = saldo);
      // Cache points
      await box.put('cached_points_${_sess.userId}', saldo);
    } catch (e) {
      if (!mounted) return;
      // Load from cache if offline
      final cached = box.get('cached_points_${_sess.userId}');
      if (cached != null && cached is int) {
        setState(() => _points = cached);
      }
    }
  }

  Future<void> _startSession(DeviceStatusController deviceCtl) async {
    // 🔔 Solicitar permisos (crucial para Web por requerir interacción)
    try {
      await NotificationService().requestPermissions();
    } catch (_) {}

    if (_sess.currentSessionId != null) {
      _showPopup(
        'Sesión Activa',
        'Ya hay una sesión activa.',
        color: AppColors.warningColor,
      );
      return;
    }

    if (!deviceCtl.connected) {
      final shouldContinue = await _showDeviceWarningDialog();
      if (!shouldContinue) return;
      // Si el usuario decide continuar sin dispositivo, la sesión no es válida para puntos
      _sess.setSessionValid(false);
    } else {
      // Si hay dispositivo, la sesión es válida
      _sess.setSessionValid(true);
    }

    setState(() => _loading = true);
    try {
      deviceCtl.resetAlerts();
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
      _showPopup(
        'Sesión Iniciada',
        'Sesión #$id iniciada.',
        color: AppColors.successColor,
      );
    } catch (e) {
      if (!mounted) return;

      // Si falla la conexión, ofrecer modo offline
      final startOffline = await CustomDialog.show<bool>(
        context: context,
        title: 'Sin conexión',
        message:
            'No se pudo conectar con el servidor.\n¿Deseas iniciar una sesión offline? (Los datos se guardarán en tu historial al recuperar la conexión)',
        color: AppColors.warningColor,
        icon: Icons.wifi_off_rounded,
        actions: [
          Expanded(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: AppColors.secondaryText),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Iniciar Offline',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );

      if (startOffline == true) {
        _sess.setSessionId(null); // Sin ID de servidor
        _sess.startSessionTimer();
        if (!mounted) return;
        _showPopup(
          'Sesión Offline',
          'Sesión de práctica iniciada.\nRecuerda que estos datos no se guardarán.',
          color: AppColors.warningColor,
          icon: Icons.wifi_off_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _showDeviceWarningDialog() async {
    return await CustomDialog.show<bool>(
          context: context,
          title: 'Dispositivo no conectado',
          message:
              '¿Deseas continuar sin dispositivo? No se registrarán puntos de postura.',
          color: AppColors.warningColor,
          icon: Icons.bluetooth_disabled,
          actions: [
            Expanded(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(false),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.poppins(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Continuar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ) ??
        false;
  }

  Future<void> _finishSession(DeviceStatusController deviceCtl) async {
    // Verificar si hay sesión corriendo (independientemente de si tiene ID o no)
    if (!_sess.isSessionRunning) {
      _showPopup(
        'Atención',
        'No hay sesión activa.',
        color: AppColors.warningColor,
      );
      return;
    }

    final sessionId = _sess.currentSessionId;
    final alerts = deviceCtl.alertCount;
    final minutes = _sess.stopSessionTimer();

    // Si es sesión offline (sessionId == null)
    if (sessionId == null) {
      deviceCtl.resetAlerts();

      // Guardar sesión pendiente para sincronizar después
      final pending = PendingSession(
        start: SessionStart(
          userId: _sess.userId!,
          deviceName: deviceCtl.deviceId ?? 'Offline Device',
          deviceMac: deviceCtl.deviceMac ?? '00:00:00:00:00:00',
        ),
        finish: SessionFinish(
          validMinutes: minutes,
          alerts: alerts,
          ssid: _sess
              .qrSsid, // Guardamos el SSID si había uno, aunque puede expirar
        ),
        timestamp: DateTime.now(),
      );

      await StorageService().addPendingSession(pending);
      if (_sess.qrSsid != null) _sess.clearQrBonus();

      _showPopup(
        'Sesión Guardada Offline',
        'Tiempo: $minutes min\nAlertas: $alerts\n\nTu sesión se ha guardado en el dispositivo y se sincronizará cuando recuperes la conexión.',
        color: AppColors.warningColor,
        icon: Icons.save_alt,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Si la sesión no era válida (sin dispositivo), enviamos 0 minutos
      final validMinutes = _sess.isSessionValidForPoints ? minutes : 0;

      String? ssidToSend = _sess.qrSsid;
      if (ssidToSend != null && _sess.qrScannedAt != null) {
        final diff = DateTime.now().difference(_sess.qrScannedAt!);
        if (diff > _bonusDuration) {
          ssidToSend = null;
          _showPopup(
            'Bono Expirado',
            'El bono x2 ha expirado.',
            color: AppColors.warningColor,
          );
          _sess.clearQrBonus();
        }
      }

      final resp = await _api.finishSession(
        sessionId,
        SessionFinish(
          validMinutes: validMinutes,
          alerts: alerts,
          ssid: ssidToSend,
        ),
      );

      _sess.setSessionId(null);
      if (ssidToSend != null) _sess.clearQrBonus();

      // Resetear alertas en el controlador para que no se queden en el dashboard
      deviceCtl.resetAlerts();

      if (!mounted) return;
      setState(() => _points = resp.saldo);

      _showPopup(
        'Sesión Finalizada',
        _sess.isSessionValidForPoints
            ? 'Tiempo: ${resp.validMinutes} min\nAlertas: $alerts\nBonus: ${resp.bonusApplied}\nSaldo: ${resp.saldo}'
            : 'Sesión sin dispositivo.\nNo se han registrado puntos.',
        color: AppColors.successColor,
      );
    } catch (e) {
      // Si falla al finalizar, restauramos el timer para que el usuario pueda reintentar
      // O podríamos ofrecer cerrar forzosamente. Por ahora, restauramos.
      _sess.startSessionTimer();
      if (!mounted) return;
      _showPopup(
        'Error',
        'Error al finalizar: $e',
        color: AppColors.errorColor,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openQRScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerWidget(
          initialValue: _sess.qrSsid,
          onQRCodeScanned: (value) {
            _sess.setQrBonus(value);
            if (value.isNotEmpty) {
              _showPopup(
                '¡Código Escaneado!',
                'x2 Puntos activos por 30 min.',
                color: AppColors.successColor,
              );
            }
          },
        ),
      ),
    );
  }

  String _fmtDuration(int seconds) {
    final s = seconds % 60;
    final m = (seconds ~/ 60) % 60;
    final h = seconds ~/ 3600;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final deviceCtl = context.watch<DeviceStatusController>();

    return AnimatedBuilder(
      animation: _sess,
      builder: (context, _) {
        final running = _sess.isSessionRunning;
        final elapsed = _sess.elapsedSeconds;
        final name = _sess.displayName ?? 'Usuario';

        return Scaffold(
          backgroundColor: AppColors.backgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, $name',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          Text(
                            'Tu Dashboard',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        backgroundColor: AppColors.lightGray,
                        child: Icon(Icons.person, color: AppColors.darkGray),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Main Dark Card (Points & Status)
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Puntos Totales',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            Icon(Icons.stars, color: AppColors.accentGold),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_points',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            _StatBadge(
                              label: 'Tiempo',
                              value: _fmtDuration(elapsed),
                              icon: Icons.timer,
                            ),
                            const SizedBox(width: 16),
                            _StatBadge(
                              label: 'Alertas',
                              value: '${deviceCtl.alertCount}',
                              icon: Icons.warning_amber_rounded,
                              iconColor: deviceCtl.alertCount > 0
                                  ? AppColors.errorColor
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Actions Grid Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Acciones rápidas',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      if (_sess.qrSsid != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'x2 Activo',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      // 1. Device Status (con SVG y ángulo)
                      _DeviceStatusCard(
                        deviceCtl: deviceCtl,
                        onTap: () {
                          _showPopup(
                            'Estado del dispositivo',
                            deviceCtl.connected
                                ? 'Conectado a ${deviceCtl.deviceId}'
                                : 'No hay dispositivo conectado. Ve a la pestaña de dispositivos para conectar.',
                          );
                        },
                      ),

                      // 2. Start/Stop Button
                      _ActionCard(
                        title: running ? 'Finalizar' : 'Iniciar',
                        subtitle: running
                            ? 'Sesión en curso'
                            : 'Comenzar ahora',
                        icon: running
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        color: running
                            ? AppColors.errorColor
                            : AppColors.successColor,
                        onTap: _loading
                            ? null
                            : () {
                                if (running) {
                                  _finishSession(deviceCtl);
                                } else {
                                  _startSession(deviceCtl);
                                }
                              },
                      ),

                      // 3. QR Scanner
                      _ActionCard(
                        title: 'Escanear QR',
                        subtitle: _sess.qrSsid != null
                            ? 'Bono activo'
                            : 'Obtener x2',
                        icon: Icons.qr_code_scanner,
                        color: AppColors.accentGold,
                        onTap: _openQRScanner,
                      ),

                      // 4. More / Stats
                      _ActionCard(
                        title: 'Estadísticas',
                        subtitle: 'Ver progreso',
                        icon: Icons.bar_chart_rounded,
                        color: AppColors.primaryText,
                        onTap: () {
                          context.push('/metrics');
                        },
                      ),
                    ],
                  ),

                  //nuevo orden del grid, la columna 3 se concvierte en la 1, la 1 en la dos, la 2 en la 3 y la 4 en la 4
                  // nuevo grid orden
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔹 Tarjeta especial para el estado del dispositivo con SVG + ángulo
class _DeviceStatusCard extends StatelessWidget {
  final DeviceStatusController deviceCtl;
  final VoidCallback? onTap;

  const _DeviceStatusCard({required this.deviceCtl, this.onTap});

  @override
  Widget build(BuildContext context) {
    final angle = deviceCtl.neckAngle;
    final base = deviceCtl.baseNeckAngle ?? angle;
    final delta = (angle - base).abs();
    final isOut = deviceCtl.isOutOfPosture;

    // Inclinar un poco la columna según la diferencia
    final tiltDeg = (angle - base).clamp(-30.0, 30.0);
    final tiltRad = tiltDeg * math.pi / 180.0;

    final connected = deviceCtl.connected;
    final title = connected ? 'Conectado' : 'Desconectado';
    final subtitle = connected
        ? '${deviceCtl.deviceId ?? 'Dispositivo'}'
        : 'Sin dispositivo';

    final color = connected
        ? (isOut ? AppColors.errorColor : AppColors.successColor)
        : AppColors.secondaryText;

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Columna + icono BT
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Center(
                      child: SizedBox(
                        height: 80,
                        child: Transform.rotate(
                          angle: -tiltRad,
                          child: SvgPicture.asset(
                            'assets/imagenes/spine.svg',
                            colorFilter: ColorFilter.mode(
                              color,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        size: 18,
                        color: connected
                            ? AppColors.primaryText
                            : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Estado + ángulo
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (connected) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ángulo: ${angle.toStringAsFixed(1)}°',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.primaryText,
                    ),
                  ),
                  Text(
                    'Δ ${delta.toStringAsFixed(1)}° • Umbral ${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
