// lib/screens/posture_settings_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '/core/posture/posture_engine.dart';
import '/features/posture/models/posture_reading.dart';
import '../../../services/notification_service.dart';
import '../../../styles/colors.dart';
import '../../../widgets/custom_dialog.dart';

class PostureSettingsPage extends StatefulWidget {
  const PostureSettingsPage({super.key});
  @override
  State<PostureSettingsPage> createState() => _PostureSettingsPageState();
}

class _PostureSettingsPageState extends State<PostureSettingsPage> {
  late double threshold; // grados
  late int sensitivity; // 0=baja,1=media,2=alta

  final engine = GetIt.I<PostureEngine>();

  @override
  void initState() {
    super.initState();
    threshold = engine.thresholdDeg;
    // mapea sustain → 0/1/2
    sensitivity = engine.sustain.inSeconds <= 2
        ? 0
        : engine.sustain.inSeconds <= 4
        ? 1
        : 2;
  }

  Duration _toSustain(int sel) {
    if (sel == 0) return const Duration(seconds: 2);
    if (sel == 1) return const Duration(seconds: 4);
    return const Duration(seconds: 6);
  }

  void _apply() {
    engine.thresholdDeg = threshold;
    engine.sustain = _toSustain(sensitivity);
    CustomDialog.show(
      context: context,
      title: 'Ajustes Guardados',
      message: 'La configuración de postura ha sido actualizada.',
      color: AppColors.successColor,
      icon: Icons.check_circle,
    );
  }

  Future<void> _testAlert() async {
    // Simula mala postura sostenida
    final now = DateTime.now();
    for (int i = 0; i < engine.sustain.inSeconds + 1; i++) {
      engine.push(
        PostureReading(
          ts: now.add(Duration(seconds: i)),
          neckAngle: threshold + 10,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // Enviar notificación de prueba
    await NotificationService().showNotification(
      id: 999,
      title: 'Prueba de Alerta',
      body: 'Esta es una notificación de prueba de mala postura.',
    );

    if (mounted) {
      CustomDialog.show(
        context: context,
        title: 'Prueba Enviada',
        message: 'Se ha enviado una notificación de prueba.',
        color: AppColors.primaryColor,
        icon: Icons.notifications_active,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Ajustes de Postura',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuración',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Personaliza la sensibilidad de las alertas',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),

              // Settings Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                      'Umbral de Cuello',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${threshold.toStringAsFixed(0)}°',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        Text(
                          'Ángulo máximo permitido',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primaryColor,
                        inactiveTrackColor: AppColors.lightGray,
                        thumbColor: AppColors.primaryColor,
                        overlayColor: AppColors.primaryColor.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: threshold,
                        min: 5,
                        max: 45,
                        divisions: 40,
                        onChanged: (v) => setState(() => threshold = v),
                      ),
                    ),

                    const Divider(height: 32),

                    Text(
                      'Sensibilidad',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tiempo necesario para activar alerta',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: sensitivity,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.primaryColor,
                          ),
                          style: GoogleFonts.poppins(
                            color: AppColors.darkGray,
                            fontSize: 16,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 0,
                              child: Text('Alta (2s - Rápida)'),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text('Media (4s - Normal)'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('Baja (6s - Lenta)'),
                            ),
                          ],
                          onChanged: (v) => setState(() => sensitivity = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Ajustes'),
                  onPressed: _apply,
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Probar Alerta'),
                  onPressed: _testAlert,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                    side: const BorderSide(color: AppColors.primaryColor),
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
      ),
    );
  }
}
