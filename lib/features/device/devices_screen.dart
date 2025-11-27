// lib/features/device/devices_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../controllers/device_status_controller.dart';
import '../../services/bluetooth_service.dart';
import '../../styles/colors.dart';
import '../../widgets/custom_dialog.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  Future<void> _checkPermissionsAndScan(BuildContext context) async {
    // 🌐 WEB: no usamos permission_handler, vamos directo al servicio
    if (kIsWeb) {
      BluetoothService().startScanning();
      return;
    }

    // 📱 MÓVIL: pedimos permisos normalmente
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.location.isGranted) {
      BluetoothService().startScanning();
    } else {
      if (context.mounted) {
        CustomDialog.show(
          context: context,
          title: 'Permisos requeridos',
          message:
              'Necesitamos permisos de Bluetooth y Ubicación para encontrar tu collar.',
          color: AppColors.errorColor,
          icon: Icons.bluetooth_disabled,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceCtl = context.watch<DeviceStatusController>();

    // Conectar el DeviceStatusController de la UI con el BluetoothService
    BluetoothService().attachDeviceController(deviceCtl);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Dispositivos',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gestiona tu conexión con el collar FocusMe',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),

              // Main Status Card
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
                      deviceCtl.connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: deviceCtl.connected
                          ? AppColors.accentGold
                          : Colors.white.withOpacity(0.3),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      deviceCtl.connected
                          ? (deviceCtl.deviceId ?? 'Collar Conectado')
                          : 'No conectado',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      deviceCtl.connected
                          ? 'Tu dispositivo está listo para monitorear.'
                          : 'Busca y conecta tu collar para empezar.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!deviceCtl.connected)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _checkPermissionsAndScan(context),
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar Dispositivo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGold,
                            foregroundColor: AppColors.cardDark,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (deviceCtl.connected) ...[
                const SizedBox(height: 24),
                Text(
                  'Configuración en tiempo real',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 16),

                // Info Cards Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.3,
                  children: [
                    _InfoCard(
                      title: 'Ángulo Actual',
                      value: '${deviceCtl.neckAngle.toStringAsFixed(1)}°',
                      icon: Icons.rotate_right,
                      color: AppColors.primaryText,
                    ),
                    _InfoCard(
                      title: 'Referencia',
                      value: deviceCtl.baseNeckAngle != null
                          ? '${deviceCtl.baseNeckAngle!.toStringAsFixed(1)}°'
                          : '--',
                      icon: Icons.flag,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Threshold Slider Card
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Umbral de Alerta',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGray,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardDark,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.cardDark,
                          inactiveTrackColor: AppColors.lightGray,
                          thumbColor: AppColors.accentGold,
                          overlayColor: AppColors.accentGold.withOpacity(0.2),
                        ),
                        child: Slider(
                          min: 5,
                          max: 30,
                          divisions: 25,
                          value: deviceCtl.thresholdDeg,
                          onChanged: (v) => deviceCtl.setThreshold(v),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          deviceCtl.calibrateNow();
                          CustomDialog.show(
                            context: context,
                            title: 'Calibrado',
                            message:
                                'Se ha establecido la postura actual como referencia.',
                            color: AppColors.successColor,
                            icon: Icons.check_circle,
                          );
                        },
                        icon: const Icon(Icons.accessibility_new),
                        label: const Text('Calibrar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (deviceCtl.baseNeckAngle != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            deviceCtl.clearCalibration();
                            CustomDialog.show(
                              context: context,
                              title: 'Reset',
                              message:
                                  'Se ha eliminado la calibración personalizada.',
                              color: AppColors.warningColor,
                              icon: Icons.refresh,
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorColor,
                            side: const BorderSide(color: AppColors.errorColor),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          Text(
            title,
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
