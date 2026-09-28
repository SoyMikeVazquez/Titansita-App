import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/recipe.dart';
import '../services/supabase_service.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _recipeController = TextEditingController();

  XFile? _pickedFile;
  Uint8List? _pickedFileBytes;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _recipeController.dispose();
    super.dispose();
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final calories = int.tryParse(_caloriesController.text.trim()) ?? 0;
    final recipeText = _recipeController.text.trim();

    setState(() => _isSaving = true);

    String? finalImageUrl;
    if (_pickedFile != null) {
      finalImageUrl = await SupabaseService().uploadRecipePhoto(_pickedFile);
    }

    // Split text by newline to populate separate steps
    final steps = recipeText
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (steps.isEmpty) {
      steps.add(recipeText);
    }

    final recipe = Recipe(
      id: '',
      title: title,
      calories: calories,
      protein: 0.0,
      carbs: 0.0,
      fat: 0.0,
      time: '15 min',
      difficulty: 'Fácil',
      imageUrl: finalImageUrl,
      ingredients: const ['Ver preparación de la receta'],
      steps: steps,
      createdAt: DateTime.now(),
    );

    final success = await SupabaseService().createRecipe(recipe);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Receta guardada con éxito ✅',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar la receta en Supabase'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget previewWidget;
    if (_pickedFileBytes != null) {
      previewWidget = Image.memory(_pickedFileBytes!, fit: BoxFit.cover);
    } else {
      previewWidget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_a_photo_outlined,
            color: Color(0xFF737373),
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            'Subir foto de la receta',
            style: GoogleFonts.inter(
              color: const Color(0xFF737373),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

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
          'Nueva Receta',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Upload Area
                    GestureDetector(
                      onTap: () async {
                        try {
                          final XFile? file = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (file != null) {
                            final bytes = await file.readAsBytes();
                            setState(() {
                              _pickedFile = file;
                              _pickedFileBytes = bytes;
                            });
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al seleccionar archivo: $e'),
                            ),
                          );
                        }
                      },
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: previewWidget,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    _buildTextField(
                      controller: _titleController,
                      label: 'Título de la receta',
                      hint: 'Ej. Tazón de Salmón y Quinoa',
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'El título es obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Calories
                    _buildTextField(
                      controller: _caloriesController,
                      label: 'Calorías aproximadas (kcal)',
                      hint: 'Ej. 450',
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty || int.tryParse(v) == null
                          ? 'Ingresa un número válido de calorías'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Recipe Text
                    _buildTextField(
                      controller: _recipeController,
                      label: 'Escribe la receta aquí',
                      hint: 'Instrucciones paso a paso, ingredientes...',
                      maxLines: 12,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'La receta es obligatoria'
                          : null,
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    ElevatedButton(
                      onPressed: _saveRecipe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Guardar Receta',
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
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
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
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
}
