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
          'Dispositivo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🟢 ELEMENTO PRINCIPAL: ÁNGULO ACTUAL
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor.withOpacity(0.15),
                      AppColors.secondaryColor.withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Ángulo actual del cuello',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${angle.toStringAsFixed(1)}°',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      postureText,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: postureColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Diferencia vs. referencia: ${delta.toStringAsFixed(1)}°',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Umbral: ${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Estado de conexión + info básica
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      deviceCtl.connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: deviceCtl.connected
                          ? AppColors.successColor
                          : AppColors.warningColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deviceCtl.connected
                                ? (deviceCtl.deviceId ?? 'Collar conectado')
                                : 'Collar sin conectar',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            deviceCtl.connected
                                ? 'MAC: ${deviceCtl.deviceMac ?? '-'}'
                                : 'Pulsa "Buscar y conectar" para enlazar tu collar',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          if (deviceCtl.connected) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Alertas en esta sesión: ${deviceCtl.alertCount}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botones de conectar / desconectar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _scanning
                        ? null
                        : () => _startScan(context),
                    icon: _scanning
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _scanning ? 'Buscando...' : 'Buscar y conectar',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryText,
                      foregroundColor: AppColors.backgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        deviceCtl.connected ? () => _disconnect(context) : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Desconectar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.lightGray,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Calibración
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calibración',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      deviceCtl.baseNeckAngle == null
                          ? 'Aún no calibrado. Siéntate derecho y pulsa "Calibrar ahora".'
                          : 'Referencia actual: ${deviceCtl.baseNeckAngle!.toStringAsFixed(1)}°',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: deviceCtl.connected
                              ? deviceCtl.calibrateNow
                              : null,
                          child: const Text('Calibrar ahora'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: deviceCtl.baseNeckAngle != null
                              ? deviceCtl.clearCalibration
                              : null,
                          child: const Text('Borrar calibración'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Umbral de sensibilidad
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensibilidad del umbral',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A partir de qué ángulo se considera "mala postura".',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            min: 5,
                            max: 45,
                            divisions: 8,
                            value: deviceCtl.thresholdDeg.clamp(5, 45),
                            label:
                                '${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                            onChanged: (v) => deviceCtl.setThreshold(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ],
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
}
