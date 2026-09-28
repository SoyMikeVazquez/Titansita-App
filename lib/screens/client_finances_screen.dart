import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import '../models/client_subscription.dart';

class ClientFinancesScreen extends StatefulWidget {
  final UserProfile client;
  const ClientFinancesScreen({super.key, required this.client});

  @override
  State<ClientFinancesScreen> createState() => _ClientFinancesScreenState();
}

class _ClientFinancesScreenState extends State<ClientFinancesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  late DateTime? _nextPaymentDate;
  List<Map<String, dynamic>> _realPayments = [];
  ClientSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _nextPaymentDate = widget.client.nextPaymentDate;
    _loadClientFinances();
  }

  Future<void> _loadClientFinances() async {
    setState(() => _isLoading = true);
    try {
      final payments = await _supabaseService.getPaymentsByClient(widget.client.userID);
      final sub = await _supabaseService.getClientSubscription(widget.client.userID);

      if (mounted) {
        setState(() {
          _realPayments = payments;
          _subscription = sub;
          if (sub != null) {
            _nextPaymentDate = sub.proximaFechaPago;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _extendPaymentDate() async {
    final subMonto = _subscription?.montoMensualidad ?? 499.0;
    final idEmpresa = widget.client.idEmpresa ?? 'GENERAL';

    setState(() => _isLoading = true);

    final success = await _supabaseService.processManualPayment(
      clienteId: widget.client.userID,
      idEmpresa: idEmpresa,
      monto: subMonto,
      concepto: 'Pago mensualidad (Manual)',
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pago registrado y acceso extendido 30 días ✅',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadClientFinances();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al procesar el pago'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return "${date.day} de ${months[date.month - 1]}, ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowDateOnly = DateTime(now.year, now.month, now.day);
    
    int daysRemaining = 0;
    bool isUrgent = false;
    String formattedDate = 'Sin fecha registrada';

    if (_nextPaymentDate != null) {
      final nextPaymentDateOnly = DateTime(_nextPaymentDate!.year, _nextPaymentDate!.month, _nextPaymentDate!.day);
      daysRemaining = nextPaymentDateOnly.difference(nowDateOnly).inDays;
      isUrgent = daysRemaining <= 5;
      formattedDate = _formatDate(_nextPaymentDate!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Finanzas del Cliente',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              color: Colors.black,
              backgroundColor: Colors.white,
              onRefresh: _loadClientFinances,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Next Payment Date Alert Card
                  if (_nextPaymentDate != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isUrgent
                              ? [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)]
                              : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isUrgent
                              ? const Color(0xFFFCA5A5).withValues(alpha: 0.5)
                              : const Color(0xFF86EFAC).withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isUrgent
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                      : const Color(0xFF22C55E).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.calendar_month_rounded,
                                  color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PRÓXIMA FECHA DE CORTE',
                                      style: GoogleFonts.inter(
                                        color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedDate,
                                      style: GoogleFonts.inter(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                                  : const Color(0xFF22C55E).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              daysRemaining > 0
                                  ? 'Faltan $daysRemaining día${daysRemaining == 1 ? '' : 's'} para la fecha de corte'
                                  : daysRemaining == 0
                                      ? '¡El pago vence hoy!'
                                      : 'Pago vencido por ${-daysRemaining} día${daysRemaining.abs() == 1 ? '' : 's'}',
                              style: GoogleFonts.inter(
                                color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 2. Reports & Payment History List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historial de Pagos (Supabase)',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const Icon(Icons.receipt_long_outlined, color: Color(0xFF737373), size: 18),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  if (_realPayments.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined, color: Color(0xFFA3A3A3), size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'No hay pagos registrados aún en Supabase',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Los pagos registrados por el entrenador o procesados en la app se guardarán en la tabla registro_pagos.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF737373),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _realPayments.length,
                      itemBuilder: (context, index) {
                        final payment = _realPayments[index];
                        final fechaStr = payment['fecha']?.toString();
                        final fecha = fechaStr != null ? DateTime.parse(fechaStr) : DateTime.now();
                        final formattedFecha = "${fecha.day}/${fecha.month}/${fecha.year}";
                        final monto = (payment['monto'] as num?)?.toDouble() ?? 499.0;
                        final concepto = payment['concepto']?.toString() ?? 'Membresía Mensual';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_outline,
                                      color: Color(0xFF22C55E),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        concepto,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$formattedFecha • Registrado',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: const Color(0xFF737373),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${monto.toStringAsFixed(2)} MXN',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Aprobado',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF22C55E),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 32),

                  // 3. Action Button for Coach
                  ElevatedButton.icon(
                    onPressed: _extendPaymentDate,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(
                      'Extender 30 días de Acceso (Registrar Pago)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
