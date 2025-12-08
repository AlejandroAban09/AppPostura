// lib/services/web/notif_web.dart
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

// Web implementation using dart:html
Future<void> showWebNotificationShim(String title, String body) async {
  if (!html.Notification.supported) {
    debugPrint('❌ [Web] Notifications API not supported.');
    return;
  }

  if (html.Notification.permission == 'granted') {
    // Crear notificación nativa del navegador
    html.Notification(title, body: body, icon: 'icons/Icon-192.png');
    debugPrint('✅ [Web] Native Notification dispatched: $title');
  } else {
    debugPrint(
      '⚠️ [Web] Permission not granted: ${html.Notification.permission}',
    );
    // Intentar pedir permiso si no está denegado
    if (html.Notification.permission != 'denied') {
      final permission = await html.Notification.requestPermission();
      if (permission == 'granted') {
        html.Notification(title, body: body, icon: 'icons/Icon-192.png');
      }
    }
  }
}

Future<bool> requestWebPermissionShim() async {
  if (!html.Notification.supported) return false;

  if (html.Notification.permission == 'granted') return true;

  final permission = await html.Notification.requestPermission();
  return permission == 'granted';
}
