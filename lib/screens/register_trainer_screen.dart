import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class RegisterTrainerScreen extends StatefulWidget {
  const RegisterTrainerScreen({super.key});

  @override
  State<RegisterTrainerScreen> createState() => _RegisterTrainerScreenState();
}

class _RegisterTrainerScreenState extends State<RegisterTrainerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specialtyController = TextEditingController();

  XFile? _selectedImage;
  bool _isSaving = false;
  bool _useMock = false;
  bool _isSuperAdmin = false;
  DateTime? _fechaPago;
  String _modalidadPago = 'mensual';
  final _montoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _useMock = SupabaseService().useMockData;
    _fechaPago = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _registerTrainer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_useMock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El registro de entrenadores solo está permitido para cuentas reales (no disponible en modo Demo).',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final specialty = _specialtyController.text.trim();

    final monto = double.tryParse(_montoController.text.trim()) ?? 0.0;

    DateTime proximoPago = _fechaPago ?? DateTime.now();
    if (_modalidadPago == 'mensual') {
      proximoPago = DateTime(proximoPago.year, proximoPago.month + 1, proximoPago.day);
    } else if (_modalidadPago == 'bimestral') {
      proximoPago = DateTime(proximoPago.year, proximoPago.month + 2, proximoPago.day);
    } else if (_modalidadPago == 'trimestral') {
      proximoPago = DateTime(proximoPago.year, proximoPago.month + 3, proximoPago.day);
    } else if (_modalidadPago == 'semestral') {
      proximoPago = DateTime(proximoPago.year, proximoPago.month + 6, proximoPago.day);
    } else if (_modalidadPago == 'anual') {
      proximoPago = DateTime(proximoPago.year + 1, proximoPago.month, proximoPago.day);
    }

    try {
      final success = await SupabaseService().registerTrainer(
        email: email,
        password: password,
        name: name,
        phone: phone,
        specialty: specialty,
        imageFile: _selectedImage,
        isSuperAdmin: _isSuperAdmin,
        fechaPago: _fechaPago,
        modalidadPago: _modalidadPago,
        proximoPago: proximoPago,
        montodecobroMensual: monto,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Entrenador registrado exitosamente ✅',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: Colors.black,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          _nameController.clear();
          _emailController.clear();
          _passwordController.clear();
          _phoneController.clear();
          _specialtyController.clear();
          _montoController.clear();
          setState(() {
            _selectedImage = null;
            _isSuperAdmin = false;
            _fechaPago = DateTime.now();
            _modalidadPago = 'mensual';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al dar de alta el entrenador.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = pickedFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Dar de Alta Entrenador',
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
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Crea una cuenta para un nuevo coach. Se creará con accesos administrativos en el sistema.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF737373),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildPhotoSelector(),
                    const SizedBox(height: 20),

                    // SuperAdmin toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: _isSuperAdmin ? const Color(0xFF92400E) : const Color(0xFF737373),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Super Administrador',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  'Otorga acceso total al sistema',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF737373),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isSuperAdmin,
                            onChanged: (val) {
                              setState(() {
                                _isSuperAdmin = val;
                              });
                            },
                            activeColor: Colors.black,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildSectionHeader('DATOS DE REGISTRO'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nombre completo *',
                      hint: 'Ej. Carlos Méndez',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Correo electrónico *',
                      hint: 'carlos@entrenador.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obligatorio';
                        if (!v.contains('@') || !v.contains('.'))
                          return 'Correo no válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Teléfono *',
                      hint: '+56 9 1234 5678',
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _specialtyController,
                      label: 'Especialidad *',
                      hint: 'Ej. Fitness, Musculación, Crossfit',
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Contraseña',
                      hint: 'Min. 6 caracteres',
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obligatorio';
                        if (v.trim().length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader('INFORMACIÓN DE COBRO'),
                    const SizedBox(height: 12),

                    // Fecha de pago picker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fecha de Pago Inicial',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF737373),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _fechaPago != null
                                    ? DateFormat('dd/MM/yyyy').format(_fechaPago!)
                                    : 'Selecciona una fecha',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _fechaPago ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Colors.black,
                                        onPrimary: Colors.white,
                                        onSurface: Colors.black,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _fechaPago = picked;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_month, color: Colors.black, size: 18),
                            label: Text(
                              'Elegir',
                              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Modalidad de pago dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      child: DropdownButtonFormField<String>(
                        value: _modalidadPago,
                        style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Modalidad de Pago',
                          labelStyle: GoogleFonts.inter(
                            color: const Color(0xFF737373),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                          DropdownMenuItem(value: 'bimestral', child: Text('Bimestral')),
                          DropdownMenuItem(value: 'trimestral', child: Text('Trimestral')),
                          DropdownMenuItem(value: 'semestral', child: Text('Semestral')),
                          DropdownMenuItem(value: 'anual', child: Text('Anual')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _modalidadPago = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monto de cobro textfield
                    _buildTextField(
                      controller: _montoController,
                      label: 'Monto de Cobro Mensual (\$) *',
                      hint: 'Ej. 500.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obligatorio';
                        if (double.tryParse(v.trim()) == null) return 'Monto inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _registerTrainer,
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
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Dar de Alta Entrenador',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
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
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
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
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: const Color(0xFF737373),
            fontSize: 13,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFFA3A3A3),
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSelector() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: _selectedImage == null
            ? Column(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: const Color(0xFF737373),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Foto de perfil',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF737373),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap para seleccionar una imagen',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFA3A3A3),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _selectedImage!.path,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap para cambiar',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF737373),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
