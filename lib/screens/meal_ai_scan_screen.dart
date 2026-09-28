import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';

class MealAiScanScreen extends StatefulWidget {
  const MealAiScanScreen({super.key});

  @override
  State<MealAiScanScreen> createState() => _MealAiScanScreenState();
}

class _MealAiScanScreenState extends State<MealAiScanScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();
  
  XFile? _imageFile;
  Uint8List? _imageFileBytes;
  bool _isAnalyzing = false;
  bool _showResults = false;
  bool _isSaving = false;
  
  // AI analysis checklist state
  int _analysisStep = 0;
  final List<String> _analysisSteps = [
    'Codificando y preparando fotografía...',
    'Consultando a OpenAI GPT-4o-mini Vision...',
    'Identificando ingredientes y porciones...',
    'Extrayendo calorías y macronutrientes...'
  ];

  // AI Prompt / Note
  final TextEditingController _aiNoteController = TextEditingController();

  // Results Form
  final _formKey = GlobalKey<FormState>();
  String _mealName = '';
  String _mealDescription = '';
  int _mealCalories = 0;
  double _mealProtein = 0.0;
  double _mealCarbs = 0.0;
  double _mealFat = 0.0;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? selected = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (selected != null) {
        final bytes = await selected.readAsBytes();
        setState(() {
          _imageFile = selected;
          _imageFileBytes = bytes;
          _showResults = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _runAiAnalysis() async {
    if (_imageFile == null) return;
    
    setState(() {
      _isAnalyzing = true;
      _analysisStep = 0;
      _showResults = false;
    });

    try {
      // Step 1: Prepare and convert photo
      if (mounted) {
        setState(() {
          _analysisStep = 1;
        });
      }
      final bytes = _imageFile!.path.startsWith('http')
          ? await http.readBytes(Uri.parse(_imageFile!.path))
          : await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Step 2: OpenAI query
      if (mounted) {
        setState(() {
          _analysisStep = 2;
        });
      }
      
      final apiKey = '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';
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');

      final note = _aiNoteController.text;
      final prompt = 'Analiza esta imagen de comida y proporciona información sobre el platillo. '
          'Devuelve obligatoriamente un objeto JSON que contenga los siguientes campos: '
          '"name" (nombre del platillo en español, ejemplo: "Pechuga de pollo con brócoli"), '
          '"description" (descripción detallada de los ingredientes identificados en español), '
          '"calories" (total estimado de calorías como número entero), '
          '"protein" (gramos estimados de proteína como número), '
          '"carbs" (gramos estimados de carbohidratos como número), '
          '"fat" (gramos estimados de grasa como número). '
          'El formato JSON debe ser estrictamente plano y sin anidaciones: '
          '{"name": "...", "description": "...", "calories": 350, "protein": 25.5, "carbs": 40.0, "fat": 12.0}. '
          '${note.isNotEmpty ? "Nota adicional del usuario a tener en cuenta: $note" : ""}';

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': prompt,
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
              ],
            }
          ],
          'response_format': {
            'type': 'json_object',
          },
        }),
      );

      // Step 3: Identify ingredients
      if (mounted) {
        setState(() {
          _analysisStep = 3;
        });
      }
      await Future.delayed(const Duration(milliseconds: 600));

      if (response.statusCode != 200) {
        throw Exception('Error de OpenAI: ${response.statusCode} - ${response.body}');
      }

      // Step 4: Extract calories & macros
      if (mounted) {
        setState(() {
          _analysisStep = 4;
        });
      }
      await Future.delayed(const Duration(milliseconds: 600));

      final responseData = jsonDecode(response.body);
      final contentStr = responseData['choices'][0]['message']['content'];
      final jsonResult = jsonDecode(contentStr);

      int safeParseInt(dynamic val) {
        if (val == null) return 0;
        if (val is num) return val.toInt();
        return int.tryParse(val.toString()) ?? 0;
      }

      double safeParseDouble(dynamic val) {
        if (val == null) return 0.0;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString()) ?? 0.0;
      }

      final String name = jsonResult['name'] ?? 'Platillo no identificado';
      final String description = jsonResult['description'] ?? '';
      final int calories = safeParseInt(jsonResult['calories']);
      final double protein = safeParseDouble(jsonResult['protein']);
      final double carbs = safeParseDouble(jsonResult['carbs']);
      final double fat = safeParseDouble(jsonResult['fat']);

      if (mounted) {
        setState(() {
          _mealName = name;
          _mealDescription = description;
          _mealCalories = calories;
          _mealProtein = protein;
          _mealCarbs = carbs;
          _mealFat = fat;
          
          _isAnalyzing = false;
          _showResults = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en el análisis de IA: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Upload photo to Supabase storage
      final String? photoUrl = await _supabaseService.uploadMealPhoto(_imageFile);
      
      // 2. Save meal entry to database
      final success = await _supabaseService.addMeal(
        '$_mealName ($_mealDescription)', // Save both as description/name
        _mealCalories,
        _mealProtein,
        _mealCarbs,
        _mealFat,
        imageUrl: photoUrl,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comida registrada con éxito 🎉'), backgroundColor: Colors.black),
          );
          Navigator.pop(context, true); // Pop back with success indicator
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al registrar la comida'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocurrió un error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF737373), size: 18),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Escanear Plato con IA 📸',
          style: GoogleFonts.inter(
            color: const Color(0xFF171717),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Photo Selection Box
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
                    ),
                    builder: (context) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.camera_alt, color: Colors.black),
                            title: Text('Tomar Foto con Cámara', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            onTap: () {
                              Navigator.pop(context);
                              _pickImage(ImageSource.camera);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library, color: Colors.black),
                            title: Text('Seleccionar de Galería', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            onTap: () {
                              Navigator.pop(context);
                              _pickImage(ImageSource.gallery);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_outlined, size: 36, color: Color(0xFFA3A3A3)),
                            const SizedBox(height: 8),
                            Text(
                              'Presiona aquí para agregar foto',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF737373),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: _imageFileBytes != null
                              ? Image.memory(
                                  _imageFileBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : Image.network(
                                  _imageFile!.path,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              if (_imageFile != null && !_isAnalyzing && !_showResults) ...[
                // AI Prompt Helper
                Text(
                  '¿Algún ingrediente especial o nota? (Opcional)',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF171717)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _aiNoteController,
                  style: const TextStyle(color: Color(0xFF171717)),
                  decoration: _buildInputDecoration('Ej. Tacos de asada con tortilla de maíz', Icons.edit_note),
                ),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF171717),
                        Color(0xFF3A3A3A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _runAiAnalysis,
                    icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    label: Text(
                      'Analizar Plato con IA ✨',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],

              // 2. Loading Steps Indicator
              if (_isAnalyzing) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Procesando con IA...',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Step checkoff
                      ...List.generate(_analysisSteps.length, (idx) {
                        final completed = _analysisStep > idx;
                        final active = _analysisStep == idx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Row(
                            children: [
                              Icon(
                                completed
                                    ? Icons.check_circle
                                    : active
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                color: completed
                                    ? Colors.black
                                    : active
                                        ? const Color(0xFF737373)
                                        : const Color(0xFFD4D4D4),
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _analysisSteps[idx],
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: completed
                                        ? Colors.black
                                        : active
                                            ? const Color(0xFF171717)
                                            : const Color(0xFFA3A3A3),
                                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              // 3. AI Generated Result Form
              if (_showResults) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_outlined, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '¡Análisis completado con éxito!',
                        style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Confirmar Datos del Platillo',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        initialValue: _mealName,
                        style: const TextStyle(color: Color(0xFF171717)),
                        decoration: _buildInputDecoration('Nombre detectado', Icons.restaurant),
                        validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                        onSaved: (val) => _mealName = val ?? '',
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        initialValue: _mealDescription,
                        style: const TextStyle(color: Color(0xFF171717)),
                        maxLines: 3,
                        decoration: _buildInputDecoration('Descripción de ingredientes', Icons.description),
                        validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                        onSaved: (val) => _mealDescription = val ?? '',
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _mealCalories.toString(),
                              style: const TextStyle(color: Color(0xFF171717)),
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration('Kcal', Icons.local_fire_department),
                              validator: (val) => val == null || int.tryParse(val) == null ? 'Obligatorio' : null,
                              onSaved: (val) => _mealCalories = int.tryParse(val ?? '') ?? 0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: _mealProtein.toStringAsFixed(0),
                              style: const TextStyle(color: Color(0xFF171717)),
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration('Prot (g)', Icons.egg_outlined),
                              validator: (val) => val == null || double.tryParse(val) == null ? 'Obligatorio' : null,
                              onSaved: (val) => _mealProtein = double.tryParse(val ?? '') ?? 0.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _mealCarbs.toStringAsFixed(0),
                              style: const TextStyle(color: Color(0xFF171717)),
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration('Carbs (g)', Icons.bakery_dining_outlined),
                              validator: (val) => val == null || double.tryParse(val) == null ? 'Obligatorio' : null,
                              onSaved: (val) => _mealCarbs = double.tryParse(val ?? '') ?? 0.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: _mealFat.toStringAsFixed(0),
                              style: const TextStyle(color: Color(0xFF171717)),
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration('Grasa (g)', Icons.opacity),
                              validator: (val) => val == null || double.tryParse(val) == null ? 'Obligatorio' : null,
                              onSaved: (val) => _mealFat = double.tryParse(val ?? '') ?? 0.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF171717),
                              Color(0xFF3A3A3A),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveMeal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Registrar Comida y Macronutrientes',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
