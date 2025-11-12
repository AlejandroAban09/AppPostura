// lib/services/api_service.dart
import '/features/rewards/models/reward.dart';
import '/features/rewards/models/redeem_result.dart';
import '/models/session_models.dart';

abstract class ApiService {
  // Auth simple (GET /auth?user=...&pass=...)
  Future<AuthResult> authSimpleGet(String userOrEmail, String pass);

  // Register new user (POST /register)
  Future<AuthResult> registerUser(String username, String password);

  // Password recovery
  Future<void> requestPasswordReset(String email);
  Future<void> verifyResetCodeAndSetPassword(
    String email,
    String code,
    String newPassword,
  );

  // Ajustes de usuario
  Future<UserSettings> getUserSettings(int userId);
  Future<void> putUserSettings(int userId, UserSettings s);

  // Sesiones
  Future<int> startSession(SessionStart start);
  Future<FinishResponse> finishSession(int sessionId, SessionFinish finish);
  Future<List<SessionHistory>> getSessionHistory(int userId, {int limit = 50});

  // Lecturas de postura
  Future<void> sendReading(int sessionId, Reading reading);

  // Puntos
  Future<int> getPoints(int userId);
  Future<List<LedgerItem>> getLedger(int userId, {int limit = 50});

  // Catálogo y canje
  Future<List<Reward>> getRewards({int? partnerId});
  Future<RedeemResult> redeem(
    int rewardId, {
    required int userId,
    int? sessionId,
  });
  Future<List<RedeemHistory>> getRedeemHistory(int userId, {int limit = 50});
}
