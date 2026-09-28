import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../models/payment_config.dart';

class IntegrationConfigScreen extends StatefulWidget {
  final String title;
  final String description;
  final String prefKey;
  final String hintText;
  final List<String> steps;
  final IconData icon;
  final Color iconColor;
  final String successMessage;

  const IntegrationConfigScreen({
    super.key,
    required this.title,
    required this.description,
    required this.prefKey,
    required this.hintText,
    required this.steps,
    required this.icon,
    required this.iconColor,
    this.successMessage = 'API Key guardada correctamente ✅',
  });

  @override
  State<IntegrationConfigScreen> createState() => _IntegrationConfigScreenState();
}

class _IntegrationConfigScreenState extends State<IntegrationConfigScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _controller = TextEditingController();
  bool _isObscured = true;
  bool _isSaving = false;
  bool _hasExistingKey = false;
  String? _maskedKey;
  String? _idEmpresa;

  @override
  void initState() {
    super.initState();
    _loadExistingKey();
  }

  Future<void> _loadExistingKey() async {
    final trainer = await _supabaseService.getTrainerProfile();
    final idEmpresa = trainer?.id ?? 'GENERAL';
    _idEmpresa = idEmpresa;

    // 1. Cargar desde Supabase config_pagos_empresa por IDEmpresa
    final config = await _supabaseService.getPaymentConfigByEmpresa(idEmpresa);
    String? key;
    if (config != null) {
      if (widget.prefKey == 'mercadopago_api_key') {
        key = config.mercadopagoAccessToken ?? config.publicKey;
      } else if (widget.prefKey == 'stripe_api_key') {
        key = config.stripeSecretKey ?? config.secretKeyEncrypted;
      } else if (widget.prefKey == 'whatsapp_api_key') {
        key = config.whatsappApiKey;
      } else if (widget.prefKey == 'openai_api_key') {
        key = config.openaiApiKey;
      }
    }

    // 2. Si no está en Supabase, buscar en SharedPreferences scoped por IDEmpresa
    if (key == null || key.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      key = prefs.getString('${idEmpresa}_${widget.prefKey}') ?? prefs.getString(widget.prefKey);
    }

    if (key != null && key.isNotEmpty) {
      setState(() {
        _hasExistingKey = true;
        final visibleLength = key!.length > 11 ? 7 : 2;
        _maskedKey = '${key.substring(0, visibleLength)}${'•' * 20}${key.substring(key.length - 4)}';
      });
    }
  }

  Future<void> _saveKey() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final trainer = await _supabaseService.getTrainerProfile();
      final idEmpresa = trainer?.id ?? _idEmpresa ?? 'GENERAL';

      // 1. Guardar localmente en SharedPreferences por IDEmpresa
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${idEmpresa}_${widget.prefKey}', key);
      await prefs.setString(widget.prefKey, key);

      // 2. Guardar en Supabase config_pagos_empresa para esta IDEmpresa
      final currentConfig = await _supabaseService.getPaymentConfigByEmpresa(idEmpresa);
      final newConfig = PaymentConfig(
        id: currentConfig?.id ?? '',
        idEmpresa: idEmpresa,
        pasarela: currentConfig?.pasarela ?? 'manual',
        publicKey: currentConfig?.publicKey,
        secretKeyEncrypted: currentConfig?.secretKeyEncrypted,
        stripeAccountId: currentConfig?.stripeAccountId,
        openaiApiKey: widget.prefKey == 'openai_api_key' ? key : currentConfig?.openaiApiKey,
        whatsappApiKey: widget.prefKey == 'whatsapp_api_key' ? key : currentConfig?.whatsappApiKey,
        mercadopagoAccessToken: widget.prefKey == 'mercadopago_api_key' ? key : currentConfig?.mercadopagoAccessToken,
        stripeSecretKey: widget.prefKey == 'stripe_api_key' ? key : currentConfig?.stripeSecretKey,
        moneda: currentConfig?.moneda ?? 'MXN',
        montoDefault: currentConfig?.montoDefault ?? 499.0,
        instruccionesTransferencia: currentConfig?.instruccionesTransferencia,
      );

      await _supabaseService.savePaymentConfig(newConfig);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _hasExistingKey = true;
        final visibleLength = key.length > 11 ? 7 : 2;
        _maskedKey = '${key.substring(0, visibleLength)}${'•' * 20}${key.substring(key.length - 4)}';
        _controller.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.successMessage,
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _removeKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar Configuración',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la configuración de ${widget.title}? Esta integración dejará de funcionar.',
          style: GoogleFonts.inter(color: const Color(0xFF737373)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final idEmpresa = _idEmpresa ?? 'GENERAL';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${idEmpresa}_${widget.prefKey}');
      await prefs.remove(widget.prefKey);

      final currentConfig = await _supabaseService.getPaymentConfigByEmpresa(idEmpresa);
      if (currentConfig != null) {
        final newConfig = PaymentConfig(
          id: currentConfig.id,
          idEmpresa: idEmpresa,
          pasarela: currentConfig.pasarela,
          publicKey: currentConfig.publicKey,
          secretKeyEncrypted: currentConfig.secretKeyEncrypted,
          stripeAccountId: currentConfig.stripeAccountId,
          openaiApiKey: widget.prefKey == 'openai_api_key' ? null : currentConfig.openaiApiKey,
          whatsappApiKey: widget.prefKey == 'whatsapp_api_key' ? null : currentConfig.whatsappApiKey,
          mercadopagoAccessToken: widget.prefKey == 'mercadopago_api_key' ? null : currentConfig.mercadopagoAccessToken,
          stripeSecretKey: widget.prefKey == 'stripe_api_key' ? null : currentConfig.stripeSecretKey,
          moneda: currentConfig.moneda,
          montoDefault: currentConfig.montoDefault,
          instruccionesTransferencia: currentConfig.instruccionesTransferencia,
        );
        await _supabaseService.savePaymentConfig(newConfig);
      }

      if (mounted) {
        setState(() {
          _hasExistingKey = false;
          _maskedKey = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Configuración eliminada', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          widget.title,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Reusable Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.icon, color: widget.iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.description,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Las llaves se guardan de forma encriptada y segura.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Current key status
            if (_hasExistingKey) ...[
              Text(
                'Configuración Actual',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activa y Conectada',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF22C55E),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _maskedKey ?? '',
                            style: const TextStyle(
                              color: Color(0xFF737373),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _removeKey,
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                      tooltip: 'Eliminar Configuración',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Actualizar Credenciales',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Text(
                'Ingresa tus Credenciales / Token',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Input field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                obscureText: _isObscured,
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF737373),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _isObscured = !_isObscured),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveKey,
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
                      _hasExistingKey ? 'Actualizar Integración' : 'Guardar y Activar',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 32),

            // Reusable Help Section
            if (widget.steps.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.help_outline, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '¿Cómo obtener tu Credencial?',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(widget.steps.length, (index) {
                      return _buildHelpStep('${index + 1}', widget.steps[index]);
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHelpStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              number,
              style: GoogleFonts.inter(
                color: const Color(0xFF92400E),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: const Color(0xFF92400E),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
