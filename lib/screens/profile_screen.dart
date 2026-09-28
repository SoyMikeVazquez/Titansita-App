import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../models/trainer.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _currentWeightController;
  late TextEditingController _targetWeightController;

  UserProfile? _profile;
  Trainer? _trainer;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _useMock = false;

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    _useMock = _supabaseService.useMockData;
    final profile = _supabaseService.loggedInUserProfile;
    if (profile != null) {
      _profile = profile;
      _nameController = TextEditingController(text: profile.name);
      _ageController = TextEditingController(text: profile.age.toString());
      _heightController = TextEditingController(text: profile.height.toStringAsFixed(0));
      _currentWeightController = TextEditingController(text: profile.currentWeight.toStringAsFixed(1));
      _targetWeightController = TextEditingController(text: profile.targetWeight.toStringAsFixed(1));
      
      if (profile.isAdmin) {
        _trainer = await _supabaseService.getTrainerProfile();
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_useMock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La edición de perfil solo está permitida para cuentas reales (no disponible en modo Demo).'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedImage = image;
          _pickedImageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_useMock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La edición de perfil solo está permitida para cuentas reales (no disponible en modo Demo).',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? avatarUrl = _profile?.avatarUrl;

      // 1. Upload new image if picked
      if (_pickedImage != null) {
        final uploadedUrl = await _supabaseService.uploadProfilePhoto(_pickedImage);
        if (uploadedUrl != null) {
          avatarUrl = uploadedUrl;
        }
      }

      // 2. Prepare data
      final name = _nameController.text.trim();
      final double? weight = _profile!.isAdmin ? null : double.tryParse(_currentWeightController.text.trim());
      final double? targetWeight = _profile!.isAdmin ? null : double.tryParse(_targetWeightController.text.trim());
      final double? height = _profile!.isAdmin ? null : double.tryParse(_heightController.text.trim());
      final int? age = _profile!.isAdmin ? null : int.tryParse(_ageController.text.trim());

      // 3. Save to Supabase
      final success = await _supabaseService.updateUserProfile(
        name: name,
        weight: weight,
        targetWeight: targetWeight,
        height: height,
        age: age,
        avatarUrl: avatarUrl,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Perfil actualizado correctamente ✅', style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: Colors.black,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar los cambios en el servidor.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Perfil')),
        body: const Center(child: Text('No se pudo cargar el perfil.')),
      );
    }

    final isAdmin = _profile!.isAdmin;

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
          'Editar Perfil',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Demo Warning Banner
            if (_useMock)
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  border: Border(bottom: BorderSide(color: Color(0xFFFED7AA))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Modo Demo Activo: La edición está deshabilitada. Inicia sesión con una cuenta real para guardar cambios.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9A3412),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar view with change picture overlay
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black.withOpacity(0.08), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: const Color(0xFFF3F4F6),
                                backgroundImage: _pickedImageBytes != null
                                    ? MemoryImage(_pickedImageBytes!) as ImageProvider
                                    : (_profile!.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty
                                        ? NetworkImage(_profile!.avatarUrl!)
                                        : const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200')) as ImageProvider,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Fields: General
                    _buildSectionHeader('DATOS DE LA CUENTA'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nombre completo',
                      hint: 'Ej. Mateo Fernández',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    // Read only email
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Correo electrónico (No editable)',
                            style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profile!.email,
                            style: GoogleFonts.inter(color: const Color(0xFF525252), fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Client stats
                    if (!isAdmin) ...[
                      _buildSectionHeader('COMPOSICIÓN FISICA'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _ageController,
                              label: 'Edad (años)',
                              hint: 'Ej. 28',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Obligatorio';
                                if (int.tryParse(v) == null) return 'Entero';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _heightController,
                              label: 'Estatura (cm)',
                              hint: 'Ej. 180',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Obligatorio';
                                if (double.tryParse(v) == null) return 'Número';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _currentWeightController,
                              label: 'Peso Actual (kg)',
                              hint: 'Ej. 78.5',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Obligatorio';
                                if (double.tryParse(v) == null) return 'Decimal';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _targetWeightController,
                              label: 'Peso Objetivo (kg)',
                              hint: 'Ej. 72.0',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Obligatorio';
                                if (double.tryParse(v) == null) return 'Decimal';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ] else ...[
                      // Admin payment information display
                      if (_trainer != null && !kIsWeb && Platform.isAndroid) ...[
                        _buildSectionHeader('INFORMACIÓN DE COBRO Y SUSCRIPCIÓN'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.01),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPaymentDetailRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'Fecha de Pago Inicial',
                                value: _trainer!.fechaPago != null
                                    ? DateFormat('dd/MM/yyyy').format(_trainer!.fechaPago!)
                                    : 'No establecida',
                              ),
                              const Divider(height: 24, color: Color(0xFFF3F4F6)),
                              _buildPaymentDetailRow(
                                icon: Icons.sync_outlined,
                                label: 'Modalidad de Pago',
                                value: _trainer!.modalidadPago != null
                                    ? _trainer!.modalidadPago!.toUpperCase()
                                    : 'No establecida',
                              ),
                              const Divider(height: 24, color: Color(0xFFF3F4F6)),
                              _buildPaymentDetailRow(
                                icon: Icons.event_repeat_outlined,
                                label: 'Próxima Fecha de Pago',
                                value: _trainer!.proximoPago != null
                                    ? DateFormat('dd/MM/yyyy').format(_trainer!.proximoPago!)
                                    : 'No establecida',
                                isHighlight: true,
                              ),
                              const Divider(height: 24, color: Color(0xFFF3F4F6)),
                              _buildPaymentDetailRow(
                                icon: Icons.monetization_on_outlined,
                                label: 'Monto de Cobro Mensual',
                                value: '\$${_trainer!.montodecobroMensual.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],

                    // Save Button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
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
                              'Guardar Cambios',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF737373),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 13),
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPaymentDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isHighlight ? Colors.redAccent : const Color(0xFF737373)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF737373),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? Colors.redAccent : const Color(0xFF171717),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
