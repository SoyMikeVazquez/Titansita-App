import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/routine_exercise.dart';
import '../utils/exercise_gifs.dart';

class AdminExercisesScreen extends StatefulWidget {
  const AdminExercisesScreen({super.key});

  @override
  State<AdminExercisesScreen> createState() => _AdminExercisesScreenState();
}

class _AdminExercisesScreenState extends State<AdminExercisesScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  late TabController _tabController;

  bool _isLoadingExercises = true;
  bool _isLoadingRoutines = true;
  List<Exercise> _exercises = [];
  List<Routine> _routines = [];

  String _searchQueryExercises = '';
  String _searchQueryRoutines = '';
  String _selectedExerciseCategory = 'Todos';

  String? _errorExercises;
  String? _errorRoutines;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild to swap FAB and search behaviors
      }
    });
    _loadExercises();
    _loadRoutines();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoadingExercises = true;
      _errorExercises = null;
    });
    try {
      final list = await _supabaseService.getExercises();
      if (mounted) {
        setState(() {
          _exercises = list;
          _isLoadingExercises = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorExercises = 'Error al cargar ejercicios: $e';
          _isLoadingExercises = false;
        });
      }
    }
  }

  Future<void> _loadRoutines() async {
    setState(() {
      _isLoadingRoutines = true;
      _errorRoutines = null;
    });
    try {
      final list = await _supabaseService.getRoutines();
      if (mounted) {
        setState(() {
          _routines = list;
          _isLoadingRoutines = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorRoutines = 'Error al cargar rutinas: $e';
          _isLoadingRoutines = false;
        });
      }
    }
  }

  void _showAddEditExerciseDialog({Exercise? exercise}) {
    final formKey = GlobalKey<FormState>();
    String name = exercise?.name ?? '';
    String description = exercise?.description ?? '';
    String imageUrl = exercise?.imageUrl ?? '';
    String category = exercise?.category ?? '';

    XFile? pickedFile;
    Uint8List? pickedFileBytes;
    bool isUploading = false;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget previewWidget;
            if (pickedFileBytes != null) {
              previewWidget = Image.memory(
                pickedFileBytes!,
                fit: BoxFit.cover,
              );
            } else if (imageUrl.isNotEmpty) {
              previewWidget = Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.fitness_center,
                  color: Color(0xFF737373),
                  size: 30,
                ),
              );
            } else {
              previewWidget = const Icon(
                Icons.fitness_center,
                color: Color(0xFF737373),
                size: 30,
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                exercise == null ? 'Nuevo Ejercicio' : 'Editar Ejercicio',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF171717),
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Preview Box
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: previewWidget,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Image picker button
                      OutlinedButton.icon(
                        onPressed: isUploading
                            ? null
                            : () async {
                                try {
                                  final XFile? file = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 85,
                                  );
                                  if (file != null) {
                                    final bytes = await file.readAsBytes();
                                    setStateDialog(() {
                                      pickedFile = file;
                                      pickedFileBytes = bytes;
                                    });
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error al seleccionar archivo: $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: Text(
                          pickedFile == null
                              ? 'Seleccionar GIF / Imagen'
                              : 'Cambiar GIF / Imagen',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Color(0xFFD4D4D4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: name,
                        style: const TextStyle(color: Color(0xFF171717)),
                        decoration: _buildInputDecoration(
                          'Nombre del ejercicio',
                          Icons.fitness_center,
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Obligatorio' : null,
                        onSaved: (val) => name = val ?? '',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: description,
                        style: const TextStyle(color: Color(0xFF171717)),
                        maxLines: 3,
                        decoration: _buildInputDecoration(
                          'Descripción',
                          Icons.description,
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Obligatorio' : null,
                        onSaved: (val) => description = val ?? '',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: imageUrl,
                        style: const TextStyle(color: Color(0xFF171717)),
                        decoration: _buildInputDecoration(
                          'O ingresa URL de la imagen',
                          Icons.link,
                        ),
                        onSaved: (val) => imageUrl = val ?? '',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: category,
                        style: const TextStyle(color: Color(0xFF171717)),
                        decoration: _buildInputDecoration(
                          'Categoría (ej: Pecho, Biceps, Piernas)',
                          Icons.folder_open,
                        ),
                        onSaved: (val) => category = val ?? '',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(color: const Color(0xFF737373)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          formKey.currentState!.save();

                          setStateDialog(() {
                            isUploading = true;
                          });

                          String? finalImageUrl = imageUrl;
                          if (pickedFile != null) {
                            final uploadUrl = await _supabaseService
                                .uploadExerciseGif(pickedFile);
                            if (uploadUrl != null) {
                              finalImageUrl = uploadUrl;
                            } else {
                              setStateDialog(() {
                                isUploading = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Error al subir el GIF a Supabase Storage',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }
                          }

                          Navigator.pop(context);

                          setState(() => _isLoadingExercises = true);
                          bool success;
                          if (exercise == null) {
                            success = await _supabaseService.addExercise(
                              name,
                              description,
                              finalImageUrl.isEmpty ? null : finalImageUrl,
                              category: category.trim(),
                            );
                          } else {
                            success = await _supabaseService.updateExercise(
                              exercise.id,
                              name,
                              description,
                              finalImageUrl.isEmpty ? null : finalImageUrl,
                              category: category.trim(),
                            );
                          }

                          if (success) {
                            _loadExercises();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  exercise == null
                                      ? 'Ejercicio creado'
                                      : 'Ejercicio actualizado',
                                ),
                                backgroundColor: Colors.black,
                              ),
                            );
                          } else {
                            setState(() => _isLoadingExercises = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error al guardar el ejercicio'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Guardar',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteExercise(Exercise exercise) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Eliminar Ejercicio',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171717),
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar "${exercise.name}"? Se quitará permanentemente del catálogo global.',
            style: GoogleFonts.inter(color: const Color(0xFF525252)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(color: const Color(0xFF737373)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoadingExercises = true);
                final success = await _supabaseService.deleteExercise(
                  exercise.id,
                );
                if (success) {
                  _loadExercises();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ejercicio eliminado del catálogo'),
                      backgroundColor: Colors.black,
                    ),
                  );
                } else {
                  setState(() => _isLoadingExercises = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al eliminar el ejercicio'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Eliminar',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddExerciseToRoutineDialog(Exercise exercise) {
    if (_routines.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Agregar a Rutina',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF171717),
              ),
            ),
            content: Text(
              'No tienes rutinas creadas aún. Por favor, crea una rutina primero en la pestaña "Rutinas".',
              style: GoogleFonts.inter(color: const Color(0xFF525252)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Aceptar',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    Routine selectedRoutine = _routines.first;
    int sets = 4;
    int reps = 12;
    double weight = 0.0;
    String seriesType = 'Normal';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Agregar a Rutina',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF171717),
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Selecciona la rutina y la prescripción para "${exercise.name}":',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF525252),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Routine Dropdown
                      DropdownButtonFormField<Routine>(
                        value: selectedRoutine,
                        decoration: _buildInputDecoration(
                          'Rutina',
                          Icons.folder_open,
                        ),
                        dropdownColor: Colors.white,
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        items: _routines.map((r) {
                          return DropdownMenuItem<Routine>(
                            value: r,
                            child: Text(
                              r.name,
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() {
                              selectedRoutine = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // Sets & Reps side by side
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: sets.toString(),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Color(0xFF171717)),
                              decoration: _buildInputDecoration(
                                'Series',
                                Icons.repeat,
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty)
                                  return 'Requerido';
                                final n = int.tryParse(val);
                                if (n == null || n <= 0) return 'Inválido';
                                return null;
                              },
                              onSaved: (val) => sets = int.parse(val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: reps.toString(),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Color(0xFF171717)),
                              decoration: _buildInputDecoration(
                                'Reps',
                                Icons.fitness_center,
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty)
                                  return 'Requerido';
                                final n = int.tryParse(val);
                                if (n == null || n <= 0) return 'Inválido';
                                return null;
                              },
                              onSaved: (val) => reps = int.parse(val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Weight
                      TextFormField(
                        initialValue: weight.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(color: Color(0xFF171717)),
                        decoration: _buildInputDecoration(
                          'Peso Inicial (kg)',
                          Icons.monitor_weight_outlined,
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Requerido';
                          final n = double.tryParse(val);
                          if (n == null || n < 0) return 'Inválido';
                          return null;
                        },
                        onSaved: (val) => weight = double.parse(val!),
                      ),
                      const SizedBox(height: 12),
                      // Series Type
                      DropdownButtonFormField<String>(
                        value: seriesType,
                        decoration: _buildInputDecoration(
                          'Tipo de Serie',
                          Icons.merge_type,
                        ),
                        dropdownColor: Colors.white,
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        items: ['Normal', 'Biserie', 'Triserie', 'Superset']
                            .map((type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(
                                  type,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              );
                            })
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() {
                              seriesType = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(color: const Color(0xFF737373)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    formKey.currentState!.save();

                    Navigator.pop(context);
                    setState(() {
                      _isLoadingRoutines = true;
                    });

                    final routineEx = RoutineExercise(
                      id: '',
                      routineId: selectedRoutine.id,
                      exerciseId: exercise.id,
                      sets: sets,
                      reps: reps,
                      seriesWeights: List<double>.filled(sets, weight),
                      seriesType: seriesType,
                      exerciseName: exercise.name,
                      exerciseDescription: exercise.description,
                      exerciseImageUrl: exercise.imageUrl,
                    );

                    final success = await _supabaseService.addRoutineExercise(
                      routineEx,
                    );
                    if (success) {
                      await _loadRoutines();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '"${exercise.name}" agregado a ${selectedRoutine.name}',
                          ),
                          backgroundColor: Colors.black,
                        ),
                      );
                    } else {
                      setState(() {
                        _isLoadingRoutines = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Error al agregar el ejercicio a la rutina',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Agregar',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddRoutineDialog() {
    final formKey = GlobalKey<FormState>();
    String routineName = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Nueva Rutina',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171717),
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              style: const TextStyle(color: Color(0xFF171717)),
              decoration: _buildInputDecoration(
                'Nombre de la rutina',
                Icons.folder_open,
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Obligatorio' : null,
              onSaved: (val) => routineName = val ?? '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(color: const Color(0xFF737373)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();

                Navigator.pop(context);
                setState(() {
                  _isLoadingRoutines = true;
                });

                final userId =
                    _supabaseService.client.auth.currentUser?.id ??
                    'mock-user-123';
                final success = await _supabaseService.addRoutine(
                  routineName,
                  userId,
                );

                if (success) {
                  await _loadRoutines();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rutina "$routineName" creada con éxito'),
                      backgroundColor: Colors.black,
                    ),
                  );
                } else {
                  setState(() {
                    _isLoadingRoutines = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al crear la rutina'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Crear',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDuplicateRoutineDialog(Routine routine) {
    final formKey = GlobalKey<FormState>();
    String newRoutineName = 'Copia de ${routine.name}';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Duplicar Rutina',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171717),
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: newRoutineName,
              style: const TextStyle(color: Color(0xFF171717)),
              decoration: _buildInputDecoration(
                'Nombre de la nueva rutina',
                Icons.copy,
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Obligatorio' : null,
              onSaved: (val) => newRoutineName = val ?? '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(color: const Color(0xFF737373)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();

                Navigator.pop(dialogContext);
                setState(() {
                  _isLoadingRoutines = true;
                });

                final success = await _supabaseService.duplicateRoutine(
                  routine,
                  newRoutineName,
                );

                if (success) {
                  await _loadRoutines();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rutina duplicada con éxito como "$newRoutineName"'),
                      backgroundColor: Colors.black,
                    ),
                  );
                } else {
                  setState(() {
                    _isLoadingRoutines = false;
                  });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al duplicar la rutina'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Duplicar',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteRoutine(Routine routine) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Eliminar Rutina',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171717),
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar la rutina "${routine.name}"? Los ejercicios dentro de ella ya no estarán agrupados en esta carpeta.',
            style: GoogleFonts.inter(color: const Color(0xFF525252)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(color: const Color(0xFF737373)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoadingRoutines = true);
                final success = await _supabaseService.deleteRoutine(
                  routine.id,
                );
                if (success) {
                  _loadRoutines();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rutina eliminada con éxito'),
                      backgroundColor: Colors.black,
                    ),
                  );
                } else {
                  setState(() => _isLoadingRoutines = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al eliminar la rutina'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Eliminar',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemoveExerciseFromRoutine(RoutineExercise rEx) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Quitar Ejercicio',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171717),
            ),
          ),
          content: Text(
            '¿Deseas quitar "${rEx.exerciseName}" de esta rutina?',
            style: GoogleFonts.inter(color: const Color(0xFF525252)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(color: const Color(0xFF737373)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoadingRoutines = true);
                final success = await _supabaseService.deleteRoutineExercise(
                  rEx.id,
                );
                if (success) {
                  _loadRoutines();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"${rEx.exerciseName}" quitado de la rutina',
                      ),
                      backgroundColor: Colors.black,
                    ),
                  );
                } else {
                  setState(() => _isLoadingRoutines = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al quitar el ejercicio'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Quitar',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddExerciseDirectlyDialog(Routine routine) {
    final formKey = GlobalKey<FormState>();
    Exercise? selectedExercise;
    String searchExQuery = '';

    int sets = 4;
    int reps = 12;
    double weight = 0.0;
    String seriesType = 'Normal';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filteredExs = _exercises.where((e) {
              return e.name.toLowerCase().contains(
                    searchExQuery.toLowerCase(),
                  ) ||
                  e.description.toLowerCase().contains(
                    searchExQuery.toLowerCase(),
                  );
            }).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                selectedExercise == null
                    ? 'Seleccionar Ejercicio'
                    : 'Configurar Ejercicio',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF171717),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: selectedExercise == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Box
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5E5E5),
                              ),
                            ),
                            child: TextField(
                              onChanged: (val) {
                                setStateDialog(() {
                                  searchExQuery = val;
                                });
                              },
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Buscar ejercicio...',
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFFA3A3A3),
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF737373),
                                  size: 18,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Exercises List
                          Flexible(
                            child: filteredExs.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: Text(
                                      'No se encontraron ejercicios.',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF737373),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: filteredExs.length,
                                    itemBuilder: (context, idx) {
                                      final ex = filteredExs[idx];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child:
                                                ex.imageUrl != null &&
                                                    ex.imageUrl!.isNotEmpty
                                                ? Image.network(
                                                    ex.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) => const Icon(
                                                          Icons.fitness_center,
                                                          size: 18,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.fitness_center,
                                                    size: 18,
                                                  ),
                                          ),
                                        ),
                                        title: Text(
                                          ex.name,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.black,
                                          ),
                                        ),
                                        subtitle: Text(
                                          ex.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF737373),
                                          ),
                                        ),
                                        onTap: () {
                                          setStateDialog(() {
                                            selectedExercise = ex;
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      )
                    : Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Prescripción para "${selectedExercise!.name}":',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF525252),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: sets.toString(),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      color: Color(0xFF171717),
                                    ),
                                    decoration: _buildInputDecoration(
                                      'Series',
                                      Icons.repeat,
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty)
                                        return 'Requerido';
                                      final n = int.tryParse(val);
                                      if (n == null || n <= 0)
                                        return 'Inválido';
                                      return null;
                                    },
                                    onSaved: (val) => sets = int.parse(val!),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: reps.toString(),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      color: Color(0xFF171717),
                                    ),
                                    decoration: _buildInputDecoration(
                                      'Reps',
                                      Icons.fitness_center,
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty)
                                        return 'Requerido';
                                      final n = int.tryParse(val);
                                      if (n == null || n <= 0)
                                        return 'Inválido';
                                      return null;
                                    },
                                    onSaved: (val) => reps = int.parse(val!),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: weight.toString(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(color: Color(0xFF171717)),
                              decoration: _buildInputDecoration(
                                'Peso Inicial (kg)',
                                Icons.monitor_weight_outlined,
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty)
                                  return 'Requerido';
                                final n = double.tryParse(val);
                                if (n == null || n < 0) return 'Inválido';
                                return null;
                              },
                              onSaved: (val) => weight = double.parse(val!),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: seriesType,
                              decoration: _buildInputDecoration(
                                'Tipo de Serie',
                                Icons.merge_type,
                              ),
                              dropdownColor: Colors.white,
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              items:
                                  [
                                    'Normal',
                                    'Biserie',
                                    'Triserie',
                                    'Superset',
                                  ].map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(
                                        type,
                                        style: const TextStyle(
                                          color: Colors.black,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setStateDialog(() {
                                    seriesType = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
              ),
              actions: [
                if (selectedExercise != null)
                  TextButton(
                    onPressed: () {
                      setStateDialog(() {
                        selectedExercise = null;
                      });
                    },
                    child: Text(
                      'Atrás',
                      style: GoogleFonts.inter(color: const Color(0xFF737373)),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(color: const Color(0xFF737373)),
                  ),
                ),
                if (selectedExercise != null)
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      formKey.currentState!.save();

                      Navigator.pop(context);
                      setState(() {
                        _isLoadingRoutines = true;
                      });

                      final routineEx = RoutineExercise(
                        id: '',
                        routineId: routine.id,
                        exerciseId: selectedExercise!.id,
                        sets: sets,
                        reps: reps,
                        seriesWeights: List<double>.filled(sets, weight),
                        seriesType: seriesType,
                        exerciseName: selectedExercise!.name,
                        exerciseDescription: selectedExercise!.description,
                        exerciseImageUrl: selectedExercise!.imageUrl,
                      );

                      final success = await _supabaseService.addRoutineExercise(
                        routineEx,
                      );
                      if (success) {
                        await _loadRoutines();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '"${selectedExercise!.name}" agregado a ${routine.name}',
                            ),
                            backgroundColor: Colors.black,
                          ),
                        );
                      } else {
                        setState(() {
                          _isLoadingRoutines = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Error al agregar el ejercicio a la rutina',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Guardar',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      labelText: hint,
      labelStyle: GoogleFonts.inter(
        color: const Color(0xFF737373),
        fontSize: 13,
      ),
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

  Widget _buildExercisesTab() {
    final categories = ['Todos'];
    for (final e in _exercises) {
      final cat = e.category ?? 'General';
      if (cat.trim().isNotEmpty && !categories.contains(cat)) {
        categories.add(cat);
      }
    }

    final filtered = _exercises.where((e) {
      final matchesCategory = _selectedExerciseCategory == 'Todos' ||
          (e.category ?? 'General').toLowerCase() == _selectedExerciseCategory.toLowerCase();
      final matchesSearch = e.name.toLowerCase().contains(
            _searchQueryExercises.toLowerCase(),
          ) ||
          e.description.toLowerCase().contains(
            _searchQueryExercises.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();

    if (_isLoadingExercises) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_errorExercises != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _errorExercises!,
                style: GoogleFonts.inter(color: const Color(0xFF737373)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadExercises,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: Text(
                  'Reintentar',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQueryExercises = val),
              style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar ejercicios por nombre o descripción...',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF737373),
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // Category Selector Chips Row
        Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedExerciseCategory.toLowerCase() == cat.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(
                    cat,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF737373),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Colors.black,
                  backgroundColor: const Color(0xFFF5F5F5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? Colors.black : const Color(0xFFE5E5E5),
                      width: 1,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedExerciseCategory = cat;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),

        // Exercises List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fitness_center_outlined,
                        size: 48,
                        color: Color(0xFFD4D4D4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _exercises.isEmpty
                            ? 'No hay ejercicios en el catálogo global.'
                            : 'No se encontraron coincidencias.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Colors.black,
                  onRefresh: _loadExercises,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final exercise = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // Exercise details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            exercise.name,
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF171717),
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            exercise.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF737373),
                                              fontSize: 12,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Actions popup menu
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Color(0xFF737373),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      onSelected: (value) {
                                        if (value == 'add_to_routine') {
                                          _showAddExerciseToRoutineDialog(
                                            exercise,
                                          );
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        PopupMenuItem<String>(
                                          value: 'add_to_routine',
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.folder_open,
                                                color: Colors.black,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Agregar a Rutina',
                                                style: GoogleFonts.inter(
                                                  color: Colors.black,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),

                                    // Exercise image (on the right)
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE5E5E5),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: () {
                                          final gifUrl = ExerciseGifs.getGifUrl(exercise.name);
                                          final displayUrl = gifUrl ?? exercise.imageUrl;
                                          if (displayUrl != null && displayUrl.isNotEmpty) {
                                            return Image.network(
                                              displayUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Icon(
                                                    Icons.fitness_center,
                                                    color: Color(0xFF737373),
                                                  ),
                                              loadingBuilder:
                                                  (context, child, progress) {
                                                    if (progress == null)
                                                      return child;
                                                    return const Center(
                                                      child: SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                              color: Colors
                                                                  .black,
                                                              strokeWidth: 2,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                            );
                                          } else {
                                            return const Icon(
                                              Icons.fitness_center,
                                              color: Color(0xFF737373),
                                            );
                                          }
                                        }(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRoutinesTab() {
    final filtered = _routines.where((r) {
      return r.name.toLowerCase().contains(_searchQueryRoutines.toLowerCase());
    }).toList();

    if (_isLoadingRoutines) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_errorRoutines != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _errorRoutines!,
                style: GoogleFonts.inter(color: const Color(0xFF737373)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRoutines,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: Text(
                  'Reintentar',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQueryRoutines = val),
              style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar rutinas...',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF737373),
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // Routines List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 48,
                        color: Color(0xFFD4D4D4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _routines.isEmpty
                            ? 'No hay rutinas creadas.'
                            : 'No se encontraron coincidencias.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Colors.black,
                  onRefresh: _loadRoutines,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final routine = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: const Icon(
                              Icons.folder_open,
                              color: Colors.black,
                              size: 24,
                            ),
                            title: Text(
                              routine.name,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF171717),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              routine.exercises.isEmpty
                                  ? 'Sin ejercicios'
                                  : '${routine.exercises.length} ${routine.exercises.length == 1 ? "ejercicio" : "ejercicios"}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF737373),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Color(0xFF737373),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onSelected: (val) {
                                    if (val == 'delete') {
                                      _confirmDeleteRoutine(routine);
                                    } else if (val == 'share') {
                                      final shareCode = routine.shareCode ?? routine.id;
                                      final deepLink = 'workoutpro://routine?id=$shareCode';
                                      final shareText = '''
¡Tu entrenador te ha compartido una rutina! Ábrela en Workout Pro dando clic aquí: $deepLink

Si aún no tienes la app, descárgala primero: https://apps.apple.com/mx/app/workout-pro/id6787178135
''';
                                      Clipboard.setData(ClipboardData(text: deepLink));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('¡Enlace de rutina copiado al portapapeles!', style: TextStyle(color: Colors.white)),
                                          backgroundColor: Colors.black,
                                        ),
                                      );
                                      Share.share(shareText);
                                    } else if (val == 'duplicate') {
                                      _showDuplicateRoutineDialog(routine);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'share',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.share_outlined,
                                            color: Colors.black,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Compartir Rutina',
                                            style: GoogleFonts.inter(
                                              color: Colors.black,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'duplicate',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.copy_outlined,
                                            color: Colors.black,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Duplicar Rutina',
                                            style: GoogleFonts.inter(
                                              color: Colors.black,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Eliminar Rutina',
                                            style: GoogleFonts.inter(
                                              color: Colors.redAccent,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                            children: [
                              const Divider(
                                height: 1,
                                color: Color(0xFFE5E5E5),
                              ),
                              if (routine.exercises.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.fitness_center_outlined,
                                        color: Color(0xFFD4D4D4),
                                        size: 36,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Esta rutina aún no tiene ejercicios.',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF737373),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: routine.exercises.length,
                                  itemBuilder: (context, i) {
                                    final rEx = routine.exercises[i];
                                    return _buildRoutineExerciseTile(rEx);
                                  },
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  16,
                                ),
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showAddExerciseDirectlyDialog(routine),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(
                                    'Agregar Ejercicio',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    side: const BorderSide(
                                      color: Color(0xFFD4D4D4),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRoutineExerciseTile(RoutineExercise rEx) {
    final double defaultWeight = rEx.seriesWeights.isNotEmpty
        ? rEx.seriesWeights.first
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: () {
                final gifUrl = ExerciseGifs.getGifUrl(rEx.exerciseName);
                final displayUrl = gifUrl ?? rEx.exerciseImageUrl;
                if (displayUrl != null && displayUrl.isNotEmpty) {
                  return Image.network(
                    displayUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.fitness_center,
                      color: Color(0xFF737373),
                      size: 20,
                    ),
                  );
                }
                return const Icon(
                  Icons.fitness_center,
                  color: Color(0xFF737373),
                  size: 20,
                );
              }(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rEx.exerciseName,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF171717),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${rEx.sets}x${rEx.reps}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${defaultWeight} kg',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (rEx.seriesType != 'Normal') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rEx.seriesType.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.redAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFFA3A3A3), size: 18),
            onPressed: () => _confirmRemoveExerciseFromRoutine(rEx),
            tooltip: 'Quitar ejercicio de la rutina',
          ),
        ],
      ),
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Biblioteca de Ejercicios',
          style: GoogleFonts.inter(
            color: const Color(0xFF171717),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: const Color(0xFF737373),
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Rutinas'),
            Tab(text: 'Ejercicios'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                _showAddRoutineDialog();
              },
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [_buildRoutinesTab(), _buildExercisesTab()],
        ),
      ),
    );
  }
}
