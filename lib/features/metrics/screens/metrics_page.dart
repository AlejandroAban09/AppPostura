import 'package:flutter/material.dart';

class MetricsPage extends StatelessWidget {
  const MetricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Por ahora dummy; en tu SessionController puedes exponer stats diarias/semanales
    final minutosHoy = 42;
    final alertasHoy = 3;
    final minutosSemana = 220;
    final alertasSemana = 14;

    Widget card(String title, String value, IconData icon) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Métricas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          card('Minutos válidos (hoy)', '$minutosHoy', Icons.access_time),
          card('Alertas (hoy)', '$alertasHoy', Icons.warning_amber_rounded),
          card('Minutos válidos (semana)', '$minutosSemana', Icons.timeline),
          card('Alertas (semana)', '$alertasSemana', Icons.analytics),
        ],
      ),
    );
  }
}
