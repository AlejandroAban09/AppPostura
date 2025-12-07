import 'package:loading_animation_widget/loading_animation_widget.dart';

// lib/features/device/devices_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../controllers/device_status_controller.dart';
import '../../services/bluetooth_service.dart';
import '../../styles/colors.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _scanning = false;

  Future<void> _startScan(BuildContext context) async {
    final deviceCtl = context.read<DeviceStatusController>();
    final bt = BluetoothService();

    // Adjuntar el controlador (importante para que reciba los ángulos)
    bt.attachDeviceController(deviceCtl);

    // En web NO pedimos permisos (no están soportados)
    if (!kIsWeb) {
      await _requestBtPermissions();
    }

    setState(() => _scanning = true);
    bt.startScanning();
    // El propio BluetoothService se encarga de detener el scan en móvil
    // cuando encuentra el dispositivo. En web la conexión es directa.
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      setState(() => _scanning = false);
    }
  }

  Future<void> _requestBtPermissions() async {
    // No pasa nada si alguna se niega; para demo solo las pedimos
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _disconnect(BuildContext context) async {
    final bt = BluetoothService();
    await bt.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final deviceCtl = context.watch<DeviceStatusController>();

    final angle = deviceCtl.neckAngle;
    final base = deviceCtl.baseNeckAngle ?? angle;
    final delta = (angle - base).abs();
    final isOut = deviceCtl.isOutOfPosture;

    final postureText = isOut ? 'Mala postura' : 'Buena postura';
    final postureColor = isOut ? AppColors.errorColor : AppColors.successColor;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Dispositivos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🟢 ELEMENTO PRINCIPAL: ÁNGULO ACTUAL (Estilo Dashboard)
            Container(
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
                  Text(
                    'Ángulo del Cuello',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${angle.toStringAsFixed(1)}°',
                    style: GoogleFonts.poppins(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: postureColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: postureColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      postureText,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            postureColor, // Usar color brillante para contraste
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'Referencia',
                        value: '${base.toStringAsFixed(1)}°',
                      ),
                      _StatColumn(
                        label: 'Diferencia',
                        value: '${delta.toStringAsFixed(1)}°',
                      ),
                      _StatColumn(
                        label: 'Umbral',
                        value: '${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Estado de conexión
            _SectionTitle(title: 'Estado de Conexión'),
            const SizedBox(height: 12),
            Container(
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
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: deviceCtl.connected
                              ? AppColors.successColor.withOpacity(0.1)
                              : AppColors.warningColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          deviceCtl.connected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          color: deviceCtl.connected
                              ? AppColors.successColor
                              : AppColors.warningColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deviceCtl.connected
                                  ? (deviceCtl.deviceId ??
                                        'Dispositivo Conectado')
                                  : 'Desconectado',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                            Text(
                              deviceCtl.connected
                                  ? 'MAC: ${deviceCtl.deviceMac ?? '-'}'
                                  : 'Vincula tu dispositivo para comenzar',
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _scanning
                              ? null
                              : () => _startScan(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryText,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _scanning
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      LoadingAnimationWidget.staggeredDotsWave(
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                )
                              : Text(
                                  'Buscar',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: deviceCtl.connected
                              ? () => _disconnect(context)
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorColor,
                            side: const BorderSide(color: AppColors.errorColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Desconectar',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Calibración
            _SectionTitle(title: 'Configuración'),
            const SizedBox(height: 12),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calibración de Postura',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deviceCtl.baseNeckAngle == null
                        ? 'Siéntate derecho y calibra para establecer tu referencia.'
                        : 'Referencia establecida en ${deviceCtl.baseNeckAngle!.toStringAsFixed(1)}°',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: deviceCtl.connected
                              ? deviceCtl.calibrateNow
                              : null,
                          icon: const Icon(Icons.accessibility_new, size: 18),
                          label: const Text('Calibrar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (deviceCtl.baseNeckAngle != null)
                        IconButton(
                          onPressed: deviceCtl.clearCalibration,
                          icon: const Icon(Icons.refresh),
                          color: AppColors.secondaryText,
                          tooltip: 'Resetear',
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(
                    'Sensibilidad (${deviceCtl.thresholdDeg.toStringAsFixed(0)}°)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primaryColor,
                      inactiveTrackColor: AppColors.lightGray,
                      thumbColor: AppColors.primaryColor,
                      overlayColor: AppColors.primaryColor.withOpacity(0.2),
                    ),
                    child: Slider(
                      min: 5,
                      max: 45,
                      divisions: 8,
                      value: deviceCtl.thresholdDeg.clamp(5, 45),
                      label: '${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                      onChanged: (v) => deviceCtl.setThreshold(v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80), // Espacio para el bottom nav
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryText,
      ),
    );
  }
}
