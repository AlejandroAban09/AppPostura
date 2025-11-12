// lib/widgets/qr_scanner_widget.dart
// CAMBIO: Nuevo widget para leer códigos QR usando mobile_scanner
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '/styles/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class QRScannerWidget extends StatefulWidget {
  final Function(String) onQRCodeScanned;
  final String? initialValue;

  const QRScannerWidget({
    super.key,
    required this.onQRCodeScanned,
    this.initialValue,
  });

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = true;
  String? _scannedValue;

  @override
  void initState() {
    super.initState();
    _scannedValue = widget.initialValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture barcodeCapture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = barcodeCapture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code != null && code.isNotEmpty) {
      setState(() {
        _isScanning = false;
        _scannedValue = code;
      });
      widget.onQRCodeScanned(code);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear QR'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleBarcode),
          // Overlay con guía de escaneo
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryColor, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Instrucciones
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Apunta la cámara al código QR',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Botón para ingresar manualmente
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton.icon(
                onPressed: () {
                  _showManualInputDialog(context);
                },
                icon: const Icon(Icons.keyboard),
                label: const Text('Ingresar manualmente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryText,
                  foregroundColor: AppColors.backgroundColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog(BuildContext context) {
    final TextEditingController textController = TextEditingController(
      text: _scannedValue ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingresar SSID manualmente'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'SSID',
            hintText: 'Ej: Starbucks_MX',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = textController.text.trim();
              if (value.isNotEmpty) {
                widget.onQRCodeScanned(value);
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}
