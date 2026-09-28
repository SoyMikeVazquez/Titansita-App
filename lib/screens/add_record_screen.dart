import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../models/measurement_record.dart';
import '../models/user_profile.dart';

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _isLoadingProfile = true;
  UserProfile? _userProfile;

  // Selected Image
  XFile? _selectedImage;
  Uint8List? _imageBytes;

  // Input Controllers/Values
  double _height = 0.0;
  double _weight = 0.0;
  double _abdomen = 0.0;
  double _waist = 0.0;
  double _leg = 0.0;
  double _chest = 0.0;
  double _arm = 0.0;
  double _calf = 0.0;
  double _cuello = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _supabaseService.getUserProfile();
      setState(() {
        _userProfile = profile;
        _height = profile.height;
        _weight = profile.currentWeight;
        _isLoadingProfile = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    final record = MeasurementRecord(
      id: '',
      userId: _userProfile?.userID ?? '',
      createdAt: DateTime.now(),
      photoUrl: null,
      weight: _weight,
      abdomen: _abdomen,
      waist: _waist,
      leg: _leg,
      chest: _chest,
      arm: _arm,
      calf: _calf,
      cuello: _cuello,
    );

    // Height updates only if height was not set (or is different)
    final double? heightToUpdate = (_userProfile == null || _userProfile!.height != _height) ? _height : null;

    final success = await _supabaseService.addMeasurementRecord(
      record,
      imageFile: _selectedImage,
      height: heightToUpdate,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro guardado correctamente', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.black,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar el registro'),
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
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Subir tu registro',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'La fecha y hora de tu registro será establecida en el día y momento actual',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF737373),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Photo Picker Row
                    Row(
                      children: [
                        // Preview container
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 140,
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
                            child: _imageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.photo_outlined,
                                    size: 40,
                                    color: Color(0xFFD4D4D4),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Upload button container
                        Expanded(
                          flex: 1,
                          child: InkWell(
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 140,
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.file_upload_outlined,
                                    size: 32,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sube foto de tu progreso actual',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'Registra tus medidas actuales',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Es importante registrar tus medidas, para saber cuál es tu progreso real.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF737373),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Height (ask only once)
                    _buildHeightInputField(),
                    const SizedBox(height: 20),

                    // Metrics Grid (2 columns)
                    Row(
                      children: [
                        Expanded(
                          child: _buildDoubleField(
                            label: '¿Cuál es tu peso actual?',
                            suffix: 'kg',
                            initialValue: _weight > 0 ? _weight.toString() : '0',
                            onSaved: (val) => _weight = val,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDoubleField(
                            label: 'Medida de Abdomen',
                            suffix: 'cm',
                            initialValue: '0',
                            onSaved: (val) => _abdomen = val,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDoubleField(
                            label: 'Medida de cintura',
                            suffix: 'cm',
                            initialValue: '0',
                            onSaved: (val) => _waist = val,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDoubleField(
                            label: 'Medida de pierna',
                            suffix: 'cm',
                            initialValue: '0',
                            onSaved: (val) => _leg = val,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDoubleField(
                            label: 'Medida de brazo',
                            suffix: 'cm',
                            initialValue: '0',
                            onSaved: (val) => _arm = val,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDoubleField(
                            label: 'Medida de pantorrilla',
                            suffix: 'cm',
                            initialValue: '0',
                            onSaved: (val) => _calf = val,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDoubleField(
                            label: 'Medida de pecho',
                            suffix: 'cm',
                            initialValue: '0',
                            onSaved: (val) => _chest = val,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDoubleField(
                            label: 'Medida de cuello',
                            suffix: 'cm',
                            initialValue: '0',
                            onSaved: (val) => _cuello = val,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveRecord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Guardar Registro',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeightInputField() {
    // Height input field. Let's make it look prominent.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDoubleField(
          label: 'Altura',
          suffix: 'cm',
          initialValue: _height > 0 ? _height.toStringAsFixed(0) : '0',
          onSaved: (val) => _height = val,
        ),
        const SizedBox(height: 4),
        Text(
          'Altura en cm (Solo se pregunta una vez)',
          style: GoogleFonts.inter(
            color: const Color(0xFF737373),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDoubleField({
    required String label,
    required String suffix,
    required String initialValue,
    required Function(double) onSaved,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: initialValue == '0' || initialValue == '0.0' ? '' : initialValue,
          style: GoogleFonts.inter(color: Colors.black, fontSize: 15),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            hintText: '0',
            suffixText: suffix,
            suffixStyle: GoogleFonts.inter(color: const Color(0xFF737373), fontWeight: FontWeight.bold),
            labelStyle: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.black),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Ingresa un valor';
            }
            if (double.tryParse(val) == null) {
              return 'Número inválido';
            }
            return null;
          },
          onSaved: (val) {
            onSaved(double.parse(val ?? '0.0'));
          },
        ),
      ],
    );
  }
}
