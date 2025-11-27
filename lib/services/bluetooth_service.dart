// lib/services/bluetooth_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

// Móvil: BLE nativo
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Web: Web Bluetooth API
import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart' as webbt;

import '../controllers/device_status_controller.dart';

/// UUIDs de tu ESP32 (del .ino)
const String kServiceUuid = '12345678-1234-1234-1234-1234567890ab';
const String kCharUuid = 'abcd1234-ab12-cd34-ef56-abcdef123456';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  StreamSubscription<List<ScanResult>>? _scanSub;
  BluetoothDevice? _connectedDevice;

  /// MISMA instancia de DeviceStatusController que usa la UI (Provider)
  DeviceStatusController? _deviceStatus;

  /// Timer para lecturas periódicas en web
  Timer? _webReadTimer;

  /// Contador de errores seguidos en web
  int _webErrorCount = 0;

  /// Llamar desde DevicesScreen para adjuntar controlador
  void attachDeviceController(DeviceStatusController controller) {
    _deviceStatus = controller;
    debugPrint(
      '🔗 [BT] DeviceStatusController adjuntado (${controller.hashCode})',
    );
  }

  /// Inicia el escaneo BLE (móvil) o Web Bluetooth (web)
  void startScanning() {
    debugPrint('🔵 [BT] startScanning()');

    if (_deviceStatus == null) {
      debugPrint(
        '⚠️ [BT] DeviceStatusController es null. Llama attachDeviceController() antes de escanear.',
      );
    }

    if (kIsWeb) {
      // 👉 En web: Web Bluetooth real, sin simulación
      _startWebBluetoothScan();
      return;
    }

    // 👉 En móvil usamos FlutterBluePlus
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen(
      _handleScanResults,
      onError: (e) => debugPrint('❌ [BT] Error en scanResults: $e'),
    );

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5))
        .then((_) {
          debugPrint('🔵 [BT] startScan iniciado (5s)');
        })
        .catchError((e) {
          debugPrint('❌ [BT] Error al iniciar scan: $e');
        });
  }

  // ==========================
  //  🌐 WEB BLUETOOTH REAL (SIN SIMULACIÓN, SOLO readValue)
  // ==========================

  Future<void> _startWebBluetoothScan() async {
    debugPrint('🌐 [BT] Modo web: intentando Web Bluetooth real');

    final deviceStatus = _deviceStatus;
    if (deviceStatus == null) {
      debugPrint('⚠️ [BT] _deviceStatus es null en _startWebBluetoothScan');
      return;
    }

    // Detener cualquier timer previo
    _webReadTimer?.cancel();
    _webReadTimer = null;
    _webErrorCount = 0;

    // 1) Comprobar soporte de API
    final supported =
        webbt.FlutterWebBluetooth.instance.isBluetoothApiSupported;
    if (!supported) {
      debugPrint('❌ [BT] Web Bluetooth no soportado en este navegador');
      deviceStatus.setConnected(false);
      return;
    }

    try {
      // 2) Pedir dispositivo (Chrome abre popup para elegir)
      final requestOptions =
          webbt.RequestOptionsBuilder.acceptAllDevices(optionalServices: [
        kServiceUuid, // necesitamos pedir permiso al servicio que vamos a usar
      ]);

      final device =
          await webbt.FlutterWebBluetooth.instance.requestDevice(requestOptions);

      debugPrint(
        '🌐 [BT] Dispositivo web seleccionado: ${device.name} / ${device.id}',
      );

      // 3) Conectar
      await device.connect();
      debugPrint('🌐 [BT] Conectado via Web Bluetooth');

      deviceStatus.setConnected(
        true,
        id: device.name ?? 'FocusCollar (web)',
        mac: device.id ?? 'WEB',
      );

      // 4) Buscar servicio y characteristic
      final services = await device.discoverServices();
      debugPrint('🌐 [BT] Servicios web descubiertos: ${services.length}');

      final service = services.firstWhere(
        (s) => s.uuid == kServiceUuid,
        orElse: () {
          throw Exception('Servicio $kServiceUuid no encontrado en el collar');
        },
      );

      final characteristic = await service.getCharacteristic(kCharUuid);

      // 5) Lecturas periódicas (usa PROPERTY_READ que añadimos en el ESP32)
      _webReadTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (timer) async {
          try {
            final byteData = await characteristic.readValue();
            final bytes = byteData.buffer.asUint8List();
            if (bytes.isEmpty) return;

            final jsonString = utf8.decode(bytes);
            debugPrint('📥 [BT] (web) Lectura periódica raw: $jsonString');
            _handleData(jsonString);

            // Si salió bien, reseteamos contador de errores
            _webErrorCount = 0;
          } catch (e) {
            _webErrorCount++;
            debugPrint(
              '❌ [BT] Error en lectura periódica web (#$_webErrorCount): $e',
            );

            // Solo nos rendimos si falla varias veces seguidas
            if (_webErrorCount >= 5) {
              debugPrint(
                '❌ [BT] Demasiados errores consecutivos en web, cancelando lecturas.',
              );
              timer.cancel();
              _webReadTimer = null;
              deviceStatus.setConnected(false);
            }
          }
        },
      );

      debugPrint('🌐 [BT] Lecturas periódicas activadas en Web Bluetooth');
    } catch (e) {
      debugPrint('❌ [BT] Error en Web Bluetooth: $e');
      deviceStatus.setConnected(false);
    }
  }

  // ==========================
  //  📱 MÓVIL (FlutterBluePlus)
  // ==========================

  void _handleScanResults(List<ScanResult> results) async {
    debugPrint('🔵 [BT] scanResults: ${results.length} dispositivos');

    for (final r in results) {
      final platformName = r.device.platformName;
      final advName = r.advertisementData.advName;
      final lowName = (platformName.isNotEmpty ? platformName : advName)
          .toLowerCase();

      debugPrint(
        '🔵 [BT] Encontrado -> id=${r.device.remoteId.str}, '
        'platformName="$platformName", advName="$advName"',
      );

      if (lowName.contains('focuscollar') || lowName.contains('focuspulsera')) {
        debugPrint('✅ [BT] Objetivo detectado: $lowName');
        try {
          await FlutterBluePlus.stopScan();
          await _connectToDevice(r.device);
        } catch (e) {
          debugPrint('❌ [BT] Error al detener scan o conectar: $e');
        }
        break;
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    debugPrint(
      '🔵 [BT] Conectando a ${device.remoteId.str} (${device.platformName})',
    );
    _connectedDevice = device;

    final deviceStatus = _deviceStatus;

    try {
      await device.connect(autoConnect: false);
      debugPrint('✅ [BT] Conectado');

      if (deviceStatus != null) {
        deviceStatus.setConnected(
          true,
          id: device.platformName.isNotEmpty
              ? device.platformName
              : 'FocusCollar',
          mac: device.remoteId.str,
        );
        debugPrint(
          '✅ [BT] DeviceStatusController.setConnected(true) en ${deviceStatus.hashCode}',
        );
      } else {
        debugPrint('⚠️ [BT] _deviceStatus es null al conectar');
      }

      final services = await device.discoverServices();
      debugPrint('🔵 [BT] Servicios: ${services.length}');

      bool anyNotify = false;

      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.notify) {
            anyNotify = true;
            debugPrint(
              '🔵 [BT] Suscribiendo notify -> svc=${s.uuid} chr=${c.uuid}',
            );
            await c.setNotifyValue(true);
            c.value.listen(
              (value) {
                try {
                  final jsonString = utf8.decode(value);
                  debugPrint('📥 [BT] Notificación (raw): $jsonString');
                  _handleData(jsonString);
                } catch (e) {
                  debugPrint('❌ [BT] Error al decodificar bytes: $e');
                }
              },
              onError: (e) => debugPrint('❌ [BT] Error en char.value: $e'),
            );
          }
        }
      }

      if (!anyNotify) {
        debugPrint('⚠️ [BT] No encontré ninguna characteristic con notify');
      }
    } catch (e) {
      debugPrint('❌ [BT] Error conectando: $e');
      if (deviceStatus != null) {
        deviceStatus.setConnected(false);
      }
    }
  }

  // ==========================
  //  LÓGICA COMÚN (parse JSON)
  // ==========================

  /// Procesa el JSON enviado por el ESP32.
  ///
  /// value = accY en "g" (entre ~ -1.0 y 1.0) -> lo convertimos a grados.
  void _handleData(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      debugPrint('📥 [BT] JSON parseado: $data');

      if (!data.containsKey('value')) {
        debugPrint('⚠️ [BT] JSON sin "value"');
        return;
      }

      final rawValue = data['value'];

      // accY en "g"
      final double accY = rawValue is num
          ? rawValue.toDouble()
          : double.parse(rawValue.toString());

      // Clamp para evitar asin fuera de rango por ruido numérico
      final double accClamped =
          accY.clamp(-1.0, 1.0); // mantiene el valor entre -1 y 1

      // Ángulo en radianes y luego en grados
      final double angleRad = math.asin(accClamped);
      final double angleDeg = angleRad * 180.0 / math.pi;

      final deviceStatus = _deviceStatus;
      if (deviceStatus != null) {
        deviceStatus.updateNeckAngle(angleDeg);
        debugPrint(
          '✅ [BT] updateNeckAngle($angleDeg°) llamado en ${deviceStatus.hashCode}',
        );

        // Por si acaso no se marcó conectado antes:
        if (!deviceStatus.connected) {
          deviceStatus.setConnected(true);
          debugPrint('ℹ️ [BT] Forzando connected=true al recibir datos');
        }
      } else {
        debugPrint(
          '⚠️ [BT] _deviceStatus es null en _handleData (no adjuntado)',
        );
      }
    } catch (e) {
      debugPrint('❌ [BT] Error procesando JSON BLE: $e');
    }
  }

  /// Desconectar manualmente
  Future<void> disconnect() async {
    final deviceStatus = _deviceStatus;

    // Parar timer de web si estaba corriendo
    _webReadTimer?.cancel();
    _webReadTimer = null;
    _webErrorCount = 0;

    if (_connectedDevice != null) {
      try {
        debugPrint(
          '🔵 [BT] Desconectando de ${_connectedDevice!.remoteId.str}',
        );
        await _connectedDevice!.disconnect();
      } catch (e) {
        debugPrint('❌ [BT] Error al desconectar: $e');
      } finally {
        _connectedDevice = null;
        if (deviceStatus != null) {
          deviceStatus.setConnected(false);
        }
      }
    } else {
      // Solo web / sin dispositivo
      if (deviceStatus != null) {
        deviceStatus.setConnected(false);
      }
    }
  }
}
