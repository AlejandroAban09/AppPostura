import 'package:loading_animation_widget/loading_animation_widget.dart';

// lib/features/rewards/rewards_catalog_page.dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:barcode_widget/barcode_widget.dart';

import '/core/api/api_service.dart';
import '../models/reward.dart';
import '../../../widgets/custom_dialog.dart';
import '../../../styles/colors.dart';
import '../../../core/session_state.dart';

class RewardsCatalogPage extends StatefulWidget {
  const RewardsCatalogPage({super.key});

  @override
  State<RewardsCatalogPage> createState() => _RewardsCatalogPageState();
}

class _RewardsCatalogPageState extends State<RewardsCatalogPage> {
  late final ApiService _api;
  late final SessionState _sess;

  @override
  void initState() {
    super.initState();
    _api = GetIt.I<ApiService>();
    _sess = GetIt.I<SessionState>();
  }

  // Reemplaza esto con TU UI real de ZenCat (lo que ya tenías)
  Widget buildZenCatSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets,
              size: 32,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZenCat',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.darkGray,
                  ),
                ),
                Text(
                  'Contenido exclusivo',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              CustomDialog.show(
                context: context,
                title: 'ZenCat',
                message: 'Esta funcionalidad estará disponible pronto.',
                color: AppColors.primaryColor,
                icon: Icons.pets,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              side: const BorderSide(color: AppColors.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem(BuildContext context, Reward r) async {
    try {
      if (_sess.userId == null) {
        CustomDialog.show(
          context: context,
          title: 'Error',
          message: 'Debes iniciar sesión para canjear.',
          color: AppColors.errorColor,
          icon: Icons.error_outline,
        );
        return;
      }
      final res = await _api.redeem(r.id, userId: _sess.userId!);
      if (!mounted) return;

      final codeText = res.tokenCode;
      final expiry = res.expiresAt;
      final expiresStr =
          '${expiry.hour.toString().padLeft(2, '0')}:'
          '${expiry.minute.toString().padLeft(2, '0')}';

      _showRedeemSuccessDialog(context, codeText, expiresStr);
    } catch (e) {
      if (!mounted) return;
      CustomDialog.show(
        context: context,
        title: 'Error',
        message: 'No se pudo canjear: $e',
        color: AppColors.errorColor,
        icon: Icons.error_outline,
      );
    }
  }

  void _showRedeemSuccessDialog(
    BuildContext context,
    String code,
    String expiresStr,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.successColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Canje Exitoso!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGray,
                  // ...
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Código: $code',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Caduca hoy a las $expiresStr',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              // Barcode
              Container(
                height: 80,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: code,
                  drawText: false,
                  color: Colors.black,
                  height: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Muestra este código de barras para validar.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Entendido',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewCatalog(List<Reward> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No hay recompensas nuevas',
            style: GoogleFonts.poppins(color: AppColors.secondaryText),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = items[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (r.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    r.imageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: AppColors.accentGold,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.darkGray,
                      ),
                    ),
                    Text(
                      '${r.partner} • ${r.cost} pts',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _redeem(context, r),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text('Canjear'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recompensas',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Canjea tus puntos por premios increíbles',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),

              // --- Sección que se queda (tu “ZenCat y eso”) ---
              buildZenCatSection(context),

              // --- Encabezado de lo nuevo ---
              Text(
                'Nuevas recompensas',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 16),

              FutureBuilder(
                future: _api.getRewards(),
                builder: (context, snapshot) {
                  final loading =
                      snapshot.connectionState != ConnectionState.done;

                  final items = (snapshot.data is List<Reward>)
                      ? (snapshot.data as List<Reward>)
                      : <Reward>[];

                  if (loading) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: LoadingAnimationWidget.staggeredDotsWave(
                          color: AppColors.accentGold,
                          size: 50,
                        ),
                      ),
                    );
                  }

                  return _buildNewCatalog(items);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
