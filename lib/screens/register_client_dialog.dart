import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../models/registration_question.dart';

class RegisterClientDialog extends StatefulWidget {
  const RegisterClientDialog({super.key});

  @override
  State<RegisterClientDialog> createState() => _RegisterClientDialogState();
}

class _RegisterClientDialogState extends State<RegisterClientDialog> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  int _currentStep = 0;
  bool _isLoadingQuestions = true;
  bool _isRegistering = false;

  // Step 1: Cuenta y Perfil
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Step 2: Cuestionario
  List<RegistrationQuestion> _questions = [];
  final Map<String, TextEditingController> _questionControllers = {};

  // Step 3: Medidas y Foto (Opcional)
  final _cuelloController = TextEditingController();
  final _pechoController = TextEditingController();
  final _brazoController = TextEditingController();
  final _abdomenController = TextEditingController();
  final _cinturaController = TextEditingController();
  final _piernaController = TextEditingController();
  final _pantorrillaController = TextEditingController();

  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    for (var controller in _questionControllers.values) {
      controller.dispose();
    }
    _cuelloController.dispose();
    _pechoController.dispose();
    _brazoController.dispose();
    _abdomenController.dispose();
    _cinturaController.dispose();
    _piernaController.dispose();
    _pantorrillaController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _supabaseService.getRegistrationQuestions();
      if (mounted) {
        setState(() {
          _questions = questions;
          for (var q in questions) {
            _questionControllers[q.id] = TextEditingController();
          }
          _isLoadingQuestions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingQuestions = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _selectedPhoto = photo;
        _selectedPhotoBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final age = int.parse(_ageController.text.trim());
      final height = double.parse(_heightController.text.trim());
      final weight = double.parse(_weightController.text.trim());

      // Collect questionnaire answers
      final List<Map<String, dynamic>> answers = [];
      for (var q in _questions) {
        answers.add({
          'question_id': q.id,
          'question_text': q.questionText,
          'answer_text': _questionControllers[q.id]?.text.trim() ?? '',
        });
      }

      // Collect optional measurements
      final double? abdomen = double.tryParse(_abdomenController.text.trim());
      final double? waist = double.tryParse(_cinturaController.text.trim());
      final double? leg = double.tryParse(_piernaController.text.trim());
      final double? chest = double.tryParse(_pechoController.text.trim());
      final double? arm = double.tryParse(_brazoController.text.trim());
      final double? calf = double.tryParse(_pantorrillaController.text.trim());
      final double? cuello = double.tryParse(_cuelloController.text.trim());

      final success = await _supabaseService.registerClient(
        email: email,
        password: password,
        name: name,
        weight: weight,
        height: height,
        age: age,
        questionnaireAnswers: answers,
        abdomen: abdomen,
        waist: waist,
        leg: leg,
        chest: chest,
        arm: arm,
        calf: calf,
        cuello: cuello,
        imageFile: _selectedPhoto,
      );

      if (mounted) {
        setState(() => _isRegistering = false);
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente $name registrado con éxito 🏋️‍♂️'),
              backgroundColor: Colors.black,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al registrar el cliente'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  InputDecoration _buildInputDeco(String label, [IconData? icon]) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500),
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF9CA3AF), size: 18) : null,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepNode(0, 'Cuenta', Icons.badge_outlined),
              _buildStepLine(1),
              _buildStepNode(1, 'Cuestionario', Icons.assignment_outlined),
              _buildStepLine(2),
              _buildStepNode(2, 'Medidas', Icons.scale_outlined),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: const Color(0xFFF3F4F6),
              color: Colors.black,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index, String label, IconData icon) {
    final isActive = _currentStep >= index;
    final isCurrent = _currentStep == index;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isCurrent 
                ? Colors.black 
                : isActive 
                    ? const Color(0xFFE5E7EB) 
                    : const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
            border: isCurrent 
                ? Border.all(color: Colors.black, width: 2) 
                : null,
          ),
          child: Icon(
            icon,
            color: isCurrent 
                ? Colors.white 
                : isActive 
                    ? Colors.black 
                    : const Color(0xFF9CA3AF),
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.black : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int nextIndex) {
    final isActive = _currentStep >= nextIndex;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          color: isActive ? Colors.black : const Color(0xFFF3F4F6),
        ),
      ),
    );
  }

  void _nextPage() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'Dar de Alta Cliente',
          style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: _isLoadingQuestions
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildStepIndicator(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() {
                          _currentStep = page;
                        });
                      },
                      children: [
                        // Page 1: Cuenta
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Información de la Cuenta',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Introduce los datos de acceso y perfil del nuevo cliente.',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _nameController,
                                style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                decoration: _buildInputDeco('Nombre Completo', Icons.person_outline),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el nombre' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                keyboardType: TextInputType.emailAddress,
                                decoration: _buildInputDeco('Correo Electrónico', Icons.email_outlined),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el correo' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                obscureText: true,
                                decoration: _buildInputDeco('Contraseña de acceso', Icons.lock_outline),
                                validator: (val) => val == null || val.trim().length < 6 ? 'Mínimo 6 caracteres' : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _ageController,
                                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                      keyboardType: TextInputType.number,
                                      decoration: _buildInputDeco('Edad (años)', Icons.cake_outlined),
                                      validator: (val) => val == null || int.tryParse(val.trim()) == null ? 'Edad inválida' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _heightController,
                                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: _buildInputDeco('Estatura (cm)', Icons.height),
                                      validator: (val) => val == null || double.tryParse(val.trim()) == null ? 'Estatura inválida' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _weightController,
                                style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _buildInputDeco('Peso Inicial (kg)', Icons.scale_outlined),
                                validator: (val) => val == null || double.tryParse(val.trim()) == null ? 'Peso inválido' : null,
                              ),
                            ],
                          ),
                        ),

                        // Page 2: Cuestionario
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Formulario de Ingreso',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Completa las preguntas para personalizar el plan del cliente.',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 20),
                              ..._questions.map((q) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 18.0),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        q.questionText,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _questionControllers[q.id],
                                        style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                        maxLines: 3,
                                        decoration: InputDecoration(
                                          hintText: 'Escribe la respuesta aquí...',
                                          hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 13),
                                          filled: true,
                                          fillColor: const Color(0xFFF9FAFB),
                                          contentPadding: const EdgeInsets.all(12),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                          ),
                                        ),
                                        validator: (val) => q.isRequired && (val == null || val.trim().isEmpty)
                                            ? 'Esta respuesta es requerida'
                                            : null,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        // Page 3: Medidas y Fotos
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Fotos y Medidas (Opcional)',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Añade el registro físico inicial. Puedes dejarlo en blanco.',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 20),
                              GestureDetector(
                                onTap: _pickPhoto,
                                child: Container(
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: _selectedPhotoBytes != null
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: Image.memory(
                                                _selectedPhotoBytes!,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              right: 12,
                                              bottom: 12,
                                              child: FloatingActionButton.small(
                                                onPressed: _pickPhoto,
                                                backgroundColor: Colors.white,
                                                foregroundColor: Colors.black,
                                                child: const Icon(Icons.edit, size: 16),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFF3F4F6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.add_a_photo_outlined, size: 28, color: Color(0xFF4B5563)),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Subir foto de estado inicial',
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4B5563)),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Medidas Corporales (cm)',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cuelloController,
                                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                      decoration: _buildInputDeco('Cuello'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _pechoController,
                                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                      decoration: _buildInputDeco('Pecho'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _brazoController,
                                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                      decoration: _buildInputDeco('Brazo'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _abdomenController,
                                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                      decoration: _buildInputDeco('Abdomen'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cinturaController,
                                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                      decoration: _buildInputDeco('Cintura'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _piernaController,
                                      style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                      decoration: _buildInputDeco('Pierna'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pantorrillaController,
                                style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                decoration: _buildInputDeco('Pantorrilla'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bottom controls bar
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _prevPage,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: Color(0xFFD4D4D4)),
                              ),
                              child: Text('Atrás', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        if (_currentStep > 0) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isRegistering ? null : _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isRegistering
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    _currentStep == 2 ? 'Registrar Cliente' : 'Siguiente',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
