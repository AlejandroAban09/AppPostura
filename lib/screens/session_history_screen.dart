import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../locator.dart';
import '../core/session_state.dart';
import '../core/api/api_service.dart';
import '../models/session_models.dart';
import '../styles/colors.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final _api = locator<ApiService>();
  final _sess = locator<SessionState>();

  List<SessionHistory>? _history;
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
      final list = await _api.getSessionHistory(_sess.userId!);
      if (mounted) {
        setState(() {
          _history = list;
          _loading = false;
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
          'Historial de Sesiones',
          style: GoogleFonts.poppins(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Error: $_error',
          style: GoogleFonts.poppins(color: AppColors.errorColor),
        ),
      );
    }
    if (_history == null || _history!.isEmpty) {
      return Center(
        child: Text(
          'No hay sesiones registradas',
          style: GoogleFonts.poppins(color: AppColors.secondaryText),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history!.length,
      itemBuilder: (context, index) {
        final session = _history![index];
        return _SessionCard(session: session);
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionHistory session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    // Fallback if locale is not initialized or available, though 'es' is usually fine.
    // If it fails, we can remove 'es' or ensure intl initialized.
    // For now, let's try with 'es' as the app seems to be in Spanish.
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateFmt.format(session.startTime),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${session.validMinutes} min',
                  style: GoogleFonts.poppins(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.errorColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${session.alerts} alertas',
                style: GoogleFonts.poppins(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              if (session.bonusApplied > 0) ...[
                const Icon(
                  Icons.stars,
                  size: 16,
                  color: AppColors.successColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '+${session.bonusApplied} bonus',
                  style: GoogleFonts.poppins(
                    color: AppColors.successColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
