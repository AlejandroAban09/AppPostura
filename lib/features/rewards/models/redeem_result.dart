// lib/features/rewards/models/redeem_result.dart
class RedeemResult {
  final String tokenCode;     // antes: code
  final DateTime expiresAt;   // ISO-8601
  final int? redemptionId;    // id_redemption
  final int? newBalance;      // saldo

  RedeemResult(
    this.tokenCode,
    this.expiresAt, {
    this.redemptionId,
    this.newBalance,
  });

  factory RedeemResult.fromJson(Map<String, dynamic> j) => RedeemResult(
    j['token_code'] as String,
    DateTime.parse(j['expires_at'] as String),
    redemptionId: j['id_redemption'] as int?,
    newBalance: (j['saldo'] as num?)?.toInt(),
  );
}
