import 'package:loading_animation_widget/loading_animation_widget.dart';

// lib/screens/redeem_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../../../locator.dart';
import '../../../core/session_state.dart';
import '../../../core/api/api_service.dart';
import '../../../models/session_models.dart';
import '../../../styles/colors.dart';

class RedeemHistoryScreen extends StatefulWidget {
  const RedeemHistoryScreen({super.key});

  @override
  State<RedeemHistoryScreen> createState() => _RedeemHistoryScreenState();
}

class _RedeemHistoryScreenState extends State<RedeemHistoryScreen> {
  final _api = locator<ApiService>();
  final _sess = locator<SessionState>();

  List<RedeemHistory>? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      if (_sess.userId == null) {
        throw Exception("Usuario no identificado");
      }

      // 👉 Usar el nuevo endpoint con límite
      final list = await _api.getRedeemHistory(_sess.userId!, limit: 50);

      if (mounted) {
        setState(() {
          _history = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Historial de Canjes',
          style: GoogleFonts.poppins(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // Pull-to-refresh para recargar el historial
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        color: AppColors.accentGold,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: AppColors.accentGold,
          size: 50,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: AppColors.secondaryText,
              ),
              const SizedBox(height: 16),
              Text(
                'No pudimos cargar tus canjes',
                style: GoogleFonts.poppins(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Verifica tu conexión a internet e inténtalo de nuevo.',
                style: GoogleFonts.poppins(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadHistory();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_history == null || _history!.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Text(
              'No hay canjes registrados',
              style: GoogleFonts.poppins(color: AppColors.secondaryText),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history!.length,
      itemBuilder: (context, index) {
        final item = _history![index];
        return _RedeemCard(item: item);
      },
    );
  }
}

class _RedeemCard extends StatelessWidget {
  final RedeemHistory item;

  const _RedeemCard({required this.item});

  void _showBarcodeDialog(BuildContext context, String code) {
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
              Text(
                'Código de Canje',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                code,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 80,
                width: double.infinity,
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: code,
                  drawText: false,
                  height: 60,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        children: [
          // Fila principal: icono + nombre + fecha + puntos
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: AppColors.successColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.rewardName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      dateFmt.format(item.timestamp),
                      style: GoogleFonts.poppins(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-${item.pointsSpent}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppColors.errorColor,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'puntos',
                    style: GoogleFonts.poppins(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Info extra: sesión + bonus
          if (item.sessionId != null || item.bonusApplied > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.sessionId != null) ...[
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sesión #${item.sessionId}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
                if (item.sessionId != null && item.bonusApplied > 0)
                  const SizedBox(width: 12),
                if (item.bonusApplied > 0) ...[
                  const Icon(
                    Icons.stars,
                    size: 16,
                    color: AppColors.accentGold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Bonus: ${item.bonusApplied} pts',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.accentGold,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Botón para ver código de barras
          if (item.tokenCode != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showBarcodeDialog(context, item.tokenCode!),
                icon: const Icon(Icons.qr_code, size: 18),
                label: const Text('Ver Código de Barras'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryText,
                  side: const BorderSide(color: AppColors.lightGray),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
