import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '/controllers/device_status_controller.dart';
import '/services/bluetooth_service.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  Future<void> _checkPermissionsAndScan(BuildContext context) async {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text("Buscar collar"),
            onPressed: () => _checkPermissionsAndScan(context),
          ),
          const SizedBox(height: 12),

          if (deviceCtl.connected && deviceCtl.isOutOfPosture) ...[
            Card(
              color: Colors.red.withOpacity(0.08),
              child: ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.red),
                title: const Text('¡Mala postura detectada!'),
                subtitle: Text(
                  'Ángulo: ${deviceCtl.neckAngle.toStringAsFixed(1)}° '
                  '• Umbral: ${deviceCtl.thresholdDeg.toStringAsFixed(0)}° '
                  '${deviceCtl.baseNeckAngle != null ? '• Ref: ${deviceCtl.baseNeckAngle!.toStringAsFixed(1)}°' : ''}',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          Card(
            child: ListTile(
              leading: Icon(
                deviceCtl.connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: deviceCtl.connected ? Colors.blue : Colors.grey,
              ),
              title: Text(
                deviceCtl.connected
                    ? (deviceCtl.deviceId ?? 'Collar')
                    : 'Sin collar conectado',
              ),
              subtitle: Text(
                deviceCtl.connected
                    ? 'MAC: ${deviceCtl.deviceMac ?? '—'}'
                    : 'Pulsa "Buscar collar" para conectar',
              ),
              trailing: Chip(
                label: Text('Alertas: ${deviceCtl.alertCount}'),
                avatar: const Icon(Icons.warning_amber_rounded, size: 18),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Postura', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Ángulo actual: ${deviceCtl.neckAngle.toStringAsFixed(1)}°'),
                  Text('Referencia: ${deviceCtl.baseNeckAngle?.toStringAsFixed(1) ?? '—'}°'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: deviceCtl.connected ? deviceCtl.calibrateNow : null,
                        child: const Text('Calibrar'),
                      ),
                      const SizedBox(width: 12),
                      Text('Umbral: ${deviceCtl.thresholdDeg.toStringAsFixed(0)}°'),
                    ],
                  ),
                  Slider(
                    min: 5,
                    max: 45,
                    divisions: 40,
                    value: deviceCtl.thresholdDeg,
                    label: '${deviceCtl.thresholdDeg.toStringAsFixed(0)}°',
                    onChanged: (v) => deviceCtl.setThreshold(v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
