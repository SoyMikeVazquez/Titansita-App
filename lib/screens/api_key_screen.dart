import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../models/payment_config.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  static const String prefKey = 'openai_api_key';

  static Future<String?> getApiKey() async {
    try {
      final supabaseService = SupabaseService();
      final trainer = await supabaseService.getTrainerProfile();
      final idEmpresa = trainer?.id ?? 'GENERAL';
      
      final config = await supabaseService.getPaymentConfigByEmpresa(idEmpresa);
      if (config?.openaiApiKey != null && config!.openaiApiKey!.isNotEmpty) {
        return config.openaiApiKey;
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${idEmpresa}_$prefKey') ?? prefs.getString(prefKey);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(prefKey);
    }
  }

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
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

    final config = await _supabaseService.getPaymentConfigByEmpresa(idEmpresa);
    String? key = config?.openaiApiKey;

    if (key == null || key.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      key = prefs.getString('${idEmpresa}_${ApiKeyScreen.prefKey}') ?? prefs.getString(ApiKeyScreen.prefKey);
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${idEmpresa}_${ApiKeyScreen.prefKey}', key);
      await prefs.setString(ApiKeyScreen.prefKey, key);

      final currentConfig = await _supabaseService.getPaymentConfigByEmpresa(idEmpresa);
      final newConfig = PaymentConfig(
        id: currentConfig?.id ?? '',
        idEmpresa: idEmpresa,
        pasarela: currentConfig?.pasarela ?? 'manual',
        publicKey: currentConfig?.publicKey,
        secretKeyEncrypted: currentConfig?.secretKeyEncrypted,
        stripeAccountId: currentConfig?.stripeAccountId,
        openaiApiKey: key,
        whatsappApiKey: currentConfig?.whatsappApiKey,
        mercadopagoAccessToken: currentConfig?.mercadopagoAccessToken,
        stripeSecretKey: currentConfig?.stripeSecretKey,
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
            'API Key guardada correctamente ✅',
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
          'Eliminar API Key',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar tu API Key de OpenAI? El escaneo con IA dejará de funcionar.',
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiKeyScreen.prefKey, '');
      if (mounted) {
        setState(() {
          _hasExistingKey = false;
          _maskedKey = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API Key eliminada', style: GoogleFonts.inter(color: Colors.white)),
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
          'API de OpenAI',
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
            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A1A2E).withValues(alpha: 0.3),
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
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inteligencia Artificial',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'OpenAI GPT-4o Vision',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Configura tu propia API Key de OpenAI para habilitar el escaneo inteligente de comidas con IA.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: Color(0xFFA78BFA), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tu API Key se almacena de forma local en tu dispositivo.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFA78BFA),
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
                'API Key Actual',
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
                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
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
                        color: const Color(0xFF22C55E).withValues(alpha: 0.1),
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
                            'Conectada',
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
                      tooltip: 'Eliminar API Key',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Actualizar API Key',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Text(
                'Ingresa tu API Key',
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
                    color: Colors.black.withValues(alpha: 0.04),
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
                  hintText: 'sk-proj-...',
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
                      _hasExistingKey ? 'Actualizar API Key' : 'Guardar API Key',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 32),

            // Help section
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
                        '¿Cómo obtener tu API Key?',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF92400E),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildHelpStep('1', 'Ve a platform.openai.com'),
                  _buildHelpStep('2', 'Inicia sesión o crea una cuenta'),
                  _buildHelpStep('3', 'Ve a "API Keys" en el menú lateral'),
                  _buildHelpStep('4', 'Haz clic en "Create new secret key"'),
                  _buildHelpStep('5', 'Copia la key y pégala aquí'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
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
