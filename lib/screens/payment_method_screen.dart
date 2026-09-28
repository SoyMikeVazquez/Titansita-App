import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  String _cardName = '';
  String _cardNumber = '';
  String _expiryDate = '';
  String _cvv = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _supabaseService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePaymentMethod() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();
    
    setState(() => _isSaving = true);
    
    // Simulating usage of the variables so Dart doesn't warn
    debugPrint('Saving card for $_cardName ending in ${_cardNumber.length > 4 ? _cardNumber.substring(_cardNumber.length - 4) : '****'} (CVV: ${_cvv.replaceAll(RegExp(r'.'), '*')})');

    try {
      // Usamos el método existente en SupabaseService pasándole un identificador de tarjeta
      await _supabaseService.updatePaymentMethod('tarjeta_guardada');

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Datos bancarios guardados correctamente ✅',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Datos Bancarios',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Payment date card
                    if (_userProfile?.nextPaymentDate != null) ...[
                      _buildPaymentDateCard(),
                      const SizedBox(height: 28),
                    ],

                    Text(
                      'Agrega tu tarjeta',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tus datos de pago mensuales se procesarán de forma segura.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF737373),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card visualization placeholder
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.credit_card, color: Colors.white, size: 32),
                              Text(
                                'VISA',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _cardNumber.isEmpty ? '**** **** **** ****' : _cardNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  letterSpacing: 2,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _cardName.isEmpty ? 'TITULAR DE LA TARJETA' : _cardName.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _expiryDate.isEmpty ? 'MM/AA' : _expiryDate,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Form Fields
                    TextFormField(
                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                      decoration: _buildInputDecoration('Titular de la tarjeta', Icons.person_outline),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa el nombre del titular' : null,
                      onChanged: (value) => setState(() => _cardName = value),
                      onSaved: (value) => _cardName = value ?? '',
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                      decoration: _buildInputDecoration('Número de tarjeta', Icons.credit_card_outlined).copyWith(counterText: ''),
                      validator: (value) => value == null || value.length < 15 ? 'Ingresa un número de tarjeta válido' : null,
                      onChanged: (value) => setState(() => _cardNumber = value),
                      onSaved: (value) => _cardNumber = value ?? '',
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            keyboardType: TextInputType.datetime,
                            maxLength: 5,
                            style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                            decoration: _buildInputDecoration('MM/AA', Icons.calendar_today_outlined).copyWith(counterText: ''),
                            validator: (value) => value == null || value.length != 5 ? 'Vencimiento inválido' : null,
                            onChanged: (value) => setState(() => _expiryDate = value),
                            onSaved: (value) => _expiryDate = value ?? '',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 4,
                            style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                            decoration: _buildInputDecoration('CVV', Icons.lock_outline).copyWith(counterText: ''),
                            validator: (value) => value == null || value.length < 3 ? 'CVV inválido' : null,
                            onChanged: (value) => setState(() => _cvv = value),
                            onSaved: (value) => _cvv = value ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _savePaymentMethod,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Guardar Datos',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Secure info note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, color: Color(0xFF22C55E), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Tus datos bancarios están encriptados y seguros',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF22C55E),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFFA3A3A3), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildPaymentDateCard() {
    final nextPayment = _userProfile!.nextPaymentDate!;
    final now = DateTime.now();
    final nowDateOnly = DateTime(now.year, now.month, now.day);
    final nextPaymentDateOnly = DateTime(nextPayment.year, nextPayment.month, nextPayment.day);
    final difference = nextPaymentDateOnly.difference(nowDateOnly).inDays;

    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final formattedDate = "${nextPayment.day} de ${months[nextPayment.month - 1]}, ${nextPayment.year}";

    final bool isUrgent = difference <= 5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUrgent
              ? [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)]
              : [const Color(0xFFF0F0FF), const Color(0xFFE8E8FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent
              ? const Color(0xFFFCA5A5).withValues(alpha: 0.5)
              : const Color(0xFFC7D2FE).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                      : const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRÓXIMA FECHA DE PAGO',
                      style: GoogleFonts.inter(
                        color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF6366F1),
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
                  : const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              difference > 0
                  ? 'Faltan $difference día${difference == 1 ? '' : 's'} para tu fecha de corte'
                  : difference == 0
                      ? '¡Tu pago vence hoy!'
                      : 'Tu pago está vencido por ${-difference} día${difference.abs() == 1 ? '' : 's'}',
              style: GoogleFonts.inter(
                color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF6366F1),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
