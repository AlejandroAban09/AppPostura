import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// Import condicional para lógica Web nativa
// Utiliza notif_shim.dart por defecto (móvil) y notif_web.dart si dart.library.html está disponible (web)
import 'web/notif_shim.dart' if (dart.library.html) 'web/notif_web.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );

    // Linux
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
          linux: initializationSettingsLinux,
        );

    // Initialización
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    // 1. WEB: Usamos nuestra lógica nativa + PermissionHandler
    if (kIsWeb) {
      // Intentamos usar la API nativa primero
      await requestWebPermissionShim();
      // También llamamos a PermissionHandler por si acaso el plugin lo necesita
      await Permission.notification.request();
      return;
    }

    // 2. Móvil / Desktop (sin usar dart:io para evitar errores en web)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } else {
      // Fallback para otras plataformas
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      // 🌐 WEB: Usar API nativa directamente
      // Esto genera la "burbuja" del sistema que usuario espera
      await showWebNotificationShim(title, body);
      return;
    }

    // Lógica para NATIVO (Android/iOS)
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'focus_channel_id',
          'Focus Alerts',
          channelDescription: 'Alertas de postura y conexión',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const LinuxNotificationDetails linuxNotificationDetails =
        LinuxNotificationDetails(urgency: LinuxNotificationUrgency.critical);

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
      linux: linuxNotificationDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}
