// lib/services/web/notif_shim.dart
// Default implementation (Mobile/Desktop) - Do nothing or rely on plugin
Future<void> showWebNotificationShim(String title, String body) async {
  // En móvil no hacemos nada con esta función específica de web,
  // ya que usamos el plugin nativo en NotificationService.
  return;
}

Future<bool> requestWebPermissionShim() async {
  return false; // En móvil usamos permission_handler
}
