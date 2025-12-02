// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box box;
  bool _soundEnabled = true;
  double _pomodoroDuration = 25;

  @override
  void initState() {
    super.initState();
    box = Hive.box('focusme_users');
    _soundEnabled = box.get('sound_enabled', defaultValue: true);
    _pomodoroDuration = box.get('pomodoro_duration', defaultValue: 25).toDouble();
  }

  void _toggleSound(bool value) {
    setState(() => _soundEnabled = value);
    box.put('sound_enabled', value);
  }

  void _updatePomodoroDuration(double value) {
    setState(() => _pomodoroDuration = value);
    box.put('pomodoro_duration', value.toInt());
  }

  void _logout() {
    box.delete('current_user');
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Sonido de alerta'),
            subtitle: const Text('Activa o desactiva los sonidos de alarma'),
            value: _soundEnabled,
            onChanged: _toggleSound,
          ),
          const Divider(),
          ListTile(
            title: const Text('Duración del Pomodoro (minutos)'),
            subtitle: Text('${_pomodoroDuration.round()} minutos'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _pomodoroDuration,
                min: 5,
                max: 60,
                divisions: 11,
                label: '${_pomodoroDuration.round()}',
                onChanged: _updatePomodoroDuration,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
