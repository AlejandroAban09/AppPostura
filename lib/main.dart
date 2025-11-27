// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'locator.dart';
import 'core/session_state.dart';
import 'controllers/device_status_controller.dart';
import 'services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  // Inicializar Hive
  await Hive.initFlutter();
  await Hive.openBox('focusme_users');
  // CAMBIO: Inicializar box para códigos de recuperación de contraseña
  await Hive.openBox('password_reset_codes');

  setupLocator();

  // Inicializar notificaciones
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  final session = locator<SessionState>();
  final router = createAppRouter(session);

  runApp(MyApp(router: router));
}

class MyApp extends StatelessWidget {
  final Object router; // GoRouter
  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 👇 Este provider es el que te falta
        ChangeNotifierProvider<DeviceStatusController>(
          create: (_) => DeviceStatusController(),
        ),
        // Si luego agregas más notifiers, los pones aquí
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'FocusMe',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        routerConfig: router as dynamic,
      ),
    );
  }
}
