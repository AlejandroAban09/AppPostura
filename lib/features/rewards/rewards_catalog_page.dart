import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '/core/api/api_service.dart';
import 'models/reward.dart';
import '/widgets/success_unlock_modal.dart';

class RewardsCatalogPage extends StatefulWidget {
  const RewardsCatalogPage({super.key});

  @override
  State<RewardsCatalogPage> createState() => _RewardsCatalogPageState();
}

class _RewardsCatalogPageState extends State<RewardsCatalogPage> {
  late final ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = GetIt.I<ApiService>();
  }

  // Reemplaza esto con TU UI real de ZenCat (lo que ya tenías)
  Widget buildZenCatSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.pets, size: 36),
        title: const Text('ZenCat (sección existente)'),
        subtitle: const Text('Aquí va tu contenido original tal cual.'),
        trailing: OutlinedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Abrir ZenCat (placeholder)')),
            );
          },
          child: const Text('Abrir'),
        ),
      ),
    );
  }

  Future<void> _redeem(BuildContext context, Reward r) async {
    try {
      final res = await _api.redeem(r.id, userId: 1); // prototipo
      if (!mounted) return;

      // Tu modal exige title/description (no code/expiredAt)
      final codeText = res.tokenCode; // mostramos el token dentro de la descripción
      final expiry = res.expiresAt;
      final expiresStr = '${expiry.hour.toString().padLeft(2, '0')}:'
          '${expiry.minute.toString().padLeft(2, '0')}';

      showDialog(
        context: context,
        builder: (_) => SuccessUnlockModal(
          title: 'Recompensa canjeada',
          description: 'Código: $codeText\n'
              'Caduca hoy a las $expiresStr.\n\n'
              'Muéstralo en el partner para validar.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo canjear: $e')),
      );
    }
  }

  Widget _buildNewCatalog(List<Reward> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No hay recompensas nuevas')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = items[i];
        return Card(
          child: ListTile(
            leading: r.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(r.imageUrl!, width: 44, height: 44, fit: BoxFit.cover),
                  )
                : const Icon(Icons.card_giftcard, size: 36),
            title: Text(r.name),
            subtitle: Text('${r.partner} • ${r.cost} pts'),
            trailing: ElevatedButton(
              onPressed: () => _redeem(context, r),
              child: const Text('Canjear'),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ Usamos FutureBuilder sin genéricos para evitar conflicto de tipos
    return Scaffold(
      appBar: AppBar(title: const Text('Recompensas')),
      body: FutureBuilder(
        future: _api.getRewards(),
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;

          // Cast seguro: si el tipo difiere o viene null, quedará en []
          final items = (snapshot.data is List<Reward>)
              ? (snapshot.data as List<Reward>)
              : <Reward>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Sección que se queda (tu “ZenCat y eso”) ---
                buildZenCatSection(context),

                // --- Encabezado de lo nuevo ---
                const Text(
                  'Nuevas recompensas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  _buildNewCatalog(items),
              ],
            ),
          );
        },
      ),
    );
  }
}
