// lib/services/bluetooth_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../locator.dart';
import '../controllers/device_status_controller.dart';

class BluetoothService {
  BluetoothService._();
  static final BluetoothService _i = BluetoothService._();
  factory BluetoothService() => _i;

  final _deviceCtl = locator<DeviceStatusController>();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  final List<StreamSubscription<List<int>>> _notifySubs = [];

  BluetoothDevice? _device;

  // Cambia esto si conoces el nombre exacto que anuncia tu collar
  static const List<String> _nameHints = ['focuscollar', 'collar', 'focus'];

  // === API pública ===

  Future<void> startScanning({Duration timeout = const Duration(seconds: 6)}) async {
    // Observa estado del adaptador para avisar si está apagado
    _adapterSub ??= FlutterBluePlus.adapterState.listen((s) {
      if (kDebugMode) {
        print('[BLE] adapterState: $s');
      }
    });

    // Limpia escaneos previos
    await _scanSub?.cancel();

    await FlutterBluePlus.startScan(timeout: timeout);
    _scanSub = FlutterBluePlus.scanResults.listen(_onScanResults, onError: (e) {
      if (kDebugMode) print('[BLE] scan error: $e');
    });
  }

  Future<void> disconnect() async {
    for (final s in _notifySubs) {
      await s.cancel();
    }
    _notifySubs.clear();

    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }
    _device = null;

    _deviceCtl.setConnected(false);
  }

  Future<void> dispose() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await _adapterSub?.cancel();
    _adapterSub = null;
    await disconnect();
  }

  // === Interno ===

  Future<void> _onScanResults(List<ScanResult> results) async {
    for (final r in results) {
      final name = (r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName)
          .toLowerCase();

      if (name.isEmpty) continue;

      final matches = _nameHints.any((h) => name.contains(h));
      if (!matches) continue;

      // Encontrado: detenemos escaneo y conectamos
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;

      await _connectAndListen(r.device);
      break;
    }
  }

  Future<void> _connectAndListen(BluetoothDevice dev) async {
    try {
      _device = dev;

      // Conecta
      await dev.connect(autoConnect: false);

      // marca conectado con id/mac
      _deviceCtl.setConnected(true, id: dev.platformName, mac: dev.remoteId.str);

      // Descubre servicios y suscribe notificaciones
      final services = await dev.discoverServices();
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.notify) {
            await c.setNotifyValue(true);
            final sub = c.value.listen(
              (raw) => _handleIncoming(raw),
              onError: (e) {
                if (kDebugMode) print('[BLE] notify error: $e');
              },
            );
            _notifySubs.add(sub);
          }
        }
      }

      // También escucha desconexión para limpiar estado
      dev.connectionState.listen((st) async {
        if (kDebugMode) print('[BLE] connectionState: $st');
        if (st == BluetoothConnectionState.disconnected) {
          await disconnect();
        }
      });
    } catch (e) {
      if (kDebugMode) print('[BLE] connect/listen error: $e');
      await disconnect();
    }
  }

  void _handleIncoming(List<int> raw) {
    try {
      // 1) Intentar decodificar como UTF8 → JSON
      String asText = '';
      try {
        asText = utf8.decode(raw);
      } catch (_) {}

      double? neck;

      if (asText.isNotEmpty) {
        // ¿JSON?
        try {
          final decoded = json.decode(asText);
          if (decoded is Map) {
            // Acepta varias claves posibles
            final map = decoded.cast<String, dynamic>();
            if (map['neck'] != null) {
              neck = _toDouble(map['neck']);
            } else if (map['angle'] != null) {
              neck = _toDouble(map['angle']);
            } else if (map['value'] != null) {
              neck = _toDouble(map['value']);
            } else if (map['shoulder'] != null) {
              // si tu fw solo manda "shoulder", úsalo como cuello por ahora
              neck = _toDouble(map['shoulder']);
            }
          } else if (decoded is num) {
            neck = decoded.toDouble();
          }
        } catch (_) {
          // No era JSON, intentamos parsear número directo
          neck = double.tryParse(asText);
        }
      }

      // 2) Si no hay texto, intenta como binario -> string -> double
      neck ??= double.tryParse(raw.toString());

      if (neck == null) return;

      // envia al controlador (esto dispara UI/alertas)
      _deviceCtl.updateNeckAngle(neck);
    } catch (e) {
      if (kDebugMode) print('[BLE] parse error: $e');
    }
  }

  double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
