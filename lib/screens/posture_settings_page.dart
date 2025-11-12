import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '/core/posture/posture_engine.dart';
import '/features/posture/models/posture_reading.dart';

class PostureSettingsPage extends StatefulWidget {
  const PostureSettingsPage({super.key});
  @override
  State<PostureSettingsPage> createState() => _PostureSettingsPageState();
}

class _PostureSettingsPageState extends State<PostureSettingsPage> {
  late double threshold; // grados
  late int sensitivity;  // 0=baja,1=media,2=alta

  final engine = GetIt.I<PostureEngine>();

  @override
  void initState() {
    super.initState();
    threshold = engine.thresholdDeg;
    // mapea sustain → 0/1/2
    sensitivity = engine.sustain.inSeconds <= 2 ? 0
                : engine.sustain.inSeconds <= 4 ? 1 : 2;
  }

  Duration _toSustain(int sel) {
    if (sel == 0) return const Duration(seconds: 2);
    if (sel == 1) return const Duration(seconds: 4);
    return const Duration(seconds: 6);
  }

  void _apply() {
    engine.thresholdDeg = threshold;
    engine.sustain = _toSustain(sensitivity);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes guardados')));
  }

  Future<void> _testAlert() async {
    // Simula mala postura sostenida
    final now = DateTime.now();
    for (int i = 0; i < engine.sustain.inSeconds + 1; i++) {
      engine.push(PostureReading(ts: now.add(Duration(seconds: i)), neckAngle: threshold + 10));
      await Future.delayed(const Duration(milliseconds: 150));
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prueba enviada (si hay sesión, debería alertar)')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes de Postura')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Umbral de cuello (°)', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: threshold,
            min: 5, max: 45, divisions: 40,
            label: '${threshold.toStringAsFixed(0)}°',
            onChanged: (v) => setState(() => threshold = v),
          ),
          const SizedBox(height: 16),
          Text('Sensibilidad (tiempo para alertar)', style: Theme.of(context).textTheme.titleMedium),
          DropdownButton<int>(
            value: sensitivity,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Baja (2s)')),
              DropdownMenuItem(value: 1, child: Text('Media (4s)')),
              DropdownMenuItem(value: 2, child: Text('Alta (6s)')),
            ],
            onChanged: (v) => setState(() => sensitivity = v!),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Guardar ajustes'),
            onPressed: _apply,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.warning_amber),
            label: const Text('Probar alerta'),
            onPressed: _testAlert,
          ),
        ],
      ),
    );
  }
}
