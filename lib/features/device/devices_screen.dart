// lib/features/device/devices_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../controllers/device_status_controller.dart';
import '../../services/bluetooth_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos de Bluetooth no concedidos')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceCtl = context.watch<DeviceStatusController>();

    // Conectar el DeviceStatusController de la UI con el BluetoothService
    BluetoothService().attachDeviceController(deviceCtl);

    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text("Buscar collar"),
              onPressed: () => _checkPermissionsAndScan(context),
            ),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Icon(
                        deviceCtl.connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                      ),
                      title: Text(
                        deviceCtl.connected
                            ? (deviceCtl.deviceId ?? 'Collar conectado')
                            : 'Collar sin conectar',
                      ),
                      subtitle: Text(
                        deviceCtl.connected
                            ? [
                                if (deviceCtl.deviceMac != null)
                                  'MAC: ${deviceCtl.deviceMac}',
                                'Ángulo actual: ${deviceCtl.neckAngle.toStringAsFixed(2)}°',
                                if (deviceCtl.baseNeckAngle != null)
                                  'Ref: ${deviceCtl.baseNeckAngle!.toStringAsFixed(2)}°',
                              ].join('\n')
                            : 'Pulsa "Buscar collar" para conectar tu dispositivo.',
                      ),
                    ),
                    if (deviceCtl.connected) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Umbral de mala postura (grados):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        min: 5,
                        max: 30,
                        divisions: 25,
                        value: deviceCtl.thresholdDeg,
                        label: '${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                        onChanged: (v) => deviceCtl.setThreshold(v),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                deviceCtl.calibrateNow();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Collar calibrado con la postura actual.',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.accessibility_new),
                              label: const Text('Calibrar postura'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (deviceCtl.baseNeckAngle != null)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  deviceCtl.clearCalibration();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Calibración eliminada.'),
                                    ),
                                  );
                                },
                                child: const Text('Quitar calibración'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Alertas acumuladas: ${deviceCtl.alertCount}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
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
