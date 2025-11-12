import 'package:get_it/get_it.dart';
import 'core/posture/posture_engine.dart';
import 'controllers/device_status_controller.dart';
import 'core/api/api_service.dart';
import 'core/api/http_api_service.dart';
import 'core/session_state.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton(() => DeviceStatusController());
  locator.registerLazySingleton<PostureEngine>(() => PostureEngine(thresholdDeg: 20));
  // API real (Render)
  locator.registerLazySingleton<ApiService>(() => HttpApiService());

  locator.registerLazySingleton<SessionState>(() => SessionState());

}
