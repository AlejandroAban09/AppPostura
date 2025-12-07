import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:focusme_app/styles/colors.dart';

// lib/screens/rewards_screen.dart
import 'package:flutter/material.dart';
import '/locator.dart';
import '/core/api/api_service.dart';
import 'package:focusme_app/features/rewards/models/reward.dart';
import 'package:focusme_app/features/rewards/models/redeem_result.dart';

class RewardsScreen extends StatefulWidget {
  final int userId; // pásalo desde tu dashboard
  final int? sessionId; // opcional para asociar canje a una sesión
  const RewardsScreen({super.key, required this.userId, this.sessionId});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final _api = locator<ApiService>();
  late Future<List<Reward>> _future;
  bool _usingFallback = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Reward>> _load() async {
    try {
      _usingFallback = false;
      final items = await _api.getRewards();
      if (items.isEmpty) return _fallback(); // muestra genérico si viene vacío
      return items;
    } catch (_) {
      _usingFallback = true;
      return _fallback(); // sin API → catálogo genérico
    }
  }

  List<Reward> _fallback() {
    return <Reward>[
      Reward(
        id: 1001,
        name: 'Latte Grande',
        partner: 'Starbucks',
        cost: 120,
        imageUrl: null,
      ),
      Reward(
        id: 1002,
        name: 'Suscripción ZenCat (1 día)',
        partner: 'ZenCat',
        cost: 150,
        imageUrl: null,
      ),
      Reward(
        id: 1003,
        name: 'Descuento 10%',
        partner: 'Partner X',
        cost: 200,
        imageUrl: null,
      ),
    ];
  }

  Future<void> _redeem(Reward r) async {
    try {
      final RedeemResult res = await _api.redeem(
        r.id,
        userId: widget.userId,
        sessionId: widget.sessionId,
      );
      if (!mounted) return;
      _showTokenDialog(
        title: 'Canje exitoso',
        token: res.tokenCode,
        expires: res.expiresAt,
        newBalance: res.newBalance,
      );
    } catch (e) {
      if (!mounted) return;
      // Si estamos en fallback, avisa que es solo demo
      final msg = _usingFallback
          ? 'Catálogo de ejemplo (sin API). No se puede canjear.'
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showTokenDialog({
    required String title,
    required String token,
    required DateTime expires,
    int? newBalance,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('Código: $token'),
            const SizedBox(height: 6),
            Text('Vence: ${expires.toLocal()}'),
            if (newBalance != null) ...[
              const SizedBox(height: 6),
              Text('Nuevo saldo: $newBalance'),
            ],
            const SizedBox(height: 8),
            const Text(
              'Muestra este código en caja para validar tu canje.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recompensas'),
        actions: [
          if (_usingFallback)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.wifi_off,
                size: 20,
              ), // indicador de catálogo genérico
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Reward>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: AppColors.accentGold,
                  size: 50,
                ),
              );
            }
            if (snap.hasError) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No se pudo cargar el catálogo')),
                ],
              );
            }
            final items = snap.data ?? const <Reward>[];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No hay recompensas disponibles')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = items[i];
                return Card(
                  child: ListTile(
                    leading: r.imageUrl == null
                        ? const CircleAvatar(child: Icon(Icons.card_giftcard))
                        : CircleAvatar(
                            backgroundImage: NetworkImage(r.imageUrl!),
                          ),
                    title: Text(r.name),
                    subtitle: Text('${r.partner} • ${r.cost} pts'),
                    trailing: ElevatedButton(
                      onPressed: _usingFallback ? null : () => _redeem(r),
                      child: const Text('Canjear'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
