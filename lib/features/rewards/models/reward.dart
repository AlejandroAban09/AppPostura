// lib/features/rewards/models/reward.dart
class Reward {
  final int id;
  final String name;
  final String partner;
  final int cost;
  final String? imageUrl;

  Reward({
    required this.id,
    required this.name,
    required this.partner,
    required this.cost,
    this.imageUrl,
  });

  // Mapea /catalog/rewards
  factory Reward.fromJson(Map<String, dynamic> j) => Reward(
    id: j['id_reward'] as int,
    name: (j['nombre'] ?? j['reward'] ?? '') as String,
    partner: (j['partner'] ?? '') as String,
    cost: (j['cost_points'] ?? 0) as int,
    imageUrl: j['image_url'] as String?,
  );
}
