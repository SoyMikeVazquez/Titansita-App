import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import '../models/routine.dart';
import '../models/routine_exercise.dart';
import '../models/meal_item.dart';
import '../models/exercise.dart';
import '../models/recipe.dart';
import '../models/assigned_recipe.dart';
import '../models/assigned_routine.dart';
import '../models/client_objective.dart';
import '../models/measurement_record.dart';
import '../models/workout_log.dart';
import '../models/client_ai_chat.dart';
import 'client_recipes_calendar_screen.dart';

class ManageClientScreen extends StatefulWidget {
  final UserProfile client;
  const ManageClientScreen({super.key, required this.client});

  @override
  State<ManageClientScreen> createState() => _ManageClientScreenState();
}

class _ManageClientScreenState extends State<ManageClientScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;

  List<Routine> _routines = [];
  List<AssignedRoutine> _clientAssignedRoutines = [];
  List<ClientObjective> _objectives = [];
  List<MealItem> _meals = [];
  List<Exercise> _catalogExercises = [];
  List<WorkoutLog> _todayWorkoutLogs = [];
  List<WorkoutLog> _allWorkoutLogs = [];
  List<MealItem> _todayMeals = [];
  List<MealItem> _allMeals = [];
  List<AssignedRecipe> _allAssignedRecipes = [];
  List<AssignedRecipe> _todayAssignedRecipes = [];
  DateTime _selectedMealDate = DateTime.now();
  DateTime _selectedRoutineDate = DateTime.now();
  List<MeasurementRecord> _records = [];
  List<Recipe> _recipes = [];
  List<Routine> _templateRoutines = [];
  String? _selectedTemplateRoutineId;
  bool _createFromScratch = false;

  // AI Chat and Analysis State
  List<ClientAiChat> _aiChats = [];
  bool _isGeneratingAiAnalysis = false;

  // Active Progress Tab Metric to plot
  String _activeMetric = 'Peso';
  final List<Map<String, String>> _metricsList = [
    {'name': 'Peso', 'unit': 'Kg'},
    {'name': 'Abdomen', 'unit': 'cm'},
    {'name': 'Cintura', 'unit': 'cm'},
    {'name': 'Pierna', 'unit': 'cm'},
    {'name': 'Pecho', 'unit': 'cm'},
    {'name': 'Bicep', 'unit': 'cm'},
    {'name': 'Pantorrilla', 'unit': 'cm'},
    {'name': 'Cuello', 'unit': 'cm'},
  ];

  // Client Finances cutoff date state
  DateTime? _nextPaymentDate;

  // Search queries
  String _searchQueryRecipes = '';

  // New Routine Form State
  final _routineFormKey = GlobalKey<FormState>();
  String _newRoutineName = '';

  // Add Exercise to Routine Form State (per routine)
  String? _routineIdForAddingExercise;
  String? _selectedExerciseId;
  int _exSets = 4;
  int _exReps = 12;
  String _exSeriesType = 'Normal';
  final List<TextEditingController> _weightControllers = [];

  // Add Meal Form State
  final _mealFormKey = GlobalKey<FormState>();
  String _mealName = '';
  int _mealCalories = 250;
  double _mealProtein = 20.0;
  double _mealCarbs = 20.0;
  double _mealFat = 5.0;

  @override
  void initState() {
    super.initState();
    _nextPaymentDate = widget.client.nextPaymentDate;
    _loadData();
  }

  @override
  void dispose() {
    for (var ctrl in _weightControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _updateWeightControllers(int setsCount) {
    for (var ctrl in _weightControllers) {
      ctrl.dispose();
    }
    _weightControllers.clear();
    for (int i = 0; i < setsCount; i++) {
      _weightControllers.add(TextEditingController(text: '0.0'));
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Wrap each call so one failure doesn't break all data loading
      Future<T> _safe<T>(Future<T> future, T fallback) async {
        try {
          return await future;
        } catch (e) {
          print('_loadData safe wrapper caught: $e');
          return fallback;
        }
      }

      final results = await Future.wait([
        _safe(_supabaseService.getRoutines(userId: widget.client.userID), <Routine>[]),
        _safe(_supabaseService.getRecentMeals(userId: widget.client.userID), <MealItem>[]),
        _safe(_supabaseService.getExercises(), <Exercise>[]),
        _safe(_supabaseService.getWorkoutLogs(userId: widget.client.userID), <WorkoutLog>[]),
        _safe(_supabaseService.getAllMeals(userId: widget.client.userID), <MealItem>[]),
        _safe(_supabaseService.getMeasurementRecords(userId: widget.client.userID), <MeasurementRecord>[]),
        _safe(_supabaseService.getRecipes(), <Recipe>[]),
        _safe(_supabaseService.getRoutines(), <Routine>[]), // Coach template routines
        _safe(_supabaseService.getClientAiChats(widget.client.userID), <ClientAiChat>[]),
        _safe(_supabaseService.getAssignedRecipes(userId: widget.client.userID), <AssignedRecipe>[]),
        _safe(_supabaseService.getAssignedRoutines(userId: widget.client.userID), <AssignedRoutine>[]),
        _safe(_supabaseService.getClientObjectives(widget.client.userID), <ClientObjective>[]),
      ]);

      if (mounted) {
        setState(() {
          _routines = results[0] as List<Routine>;
          _meals = results[1] as List<MealItem>;
          _catalogExercises = results[2] as List<Exercise>;
          final workoutLogs = results[3] as List<WorkoutLog>;
          _allWorkoutLogs = workoutLogs;
          _allMeals = results[4] as List<MealItem>;
          _records = results[5] as List<MeasurementRecord>;
          _recipes = results[6] as List<Recipe>;
          _templateRoutines = results[7] as List<Routine>;
          _aiChats = results[8] as List<ClientAiChat>;
          _allAssignedRecipes = results[9] as List<AssignedRecipe>;
          _clientAssignedRoutines = results[10] as List<AssignedRoutine>;
          _objectives = results[11] as List<ClientObjective>;

          print('_loadData: recipes=${_recipes.length}, assignedRecipes=${_allAssignedRecipes.length}, routines=${_routines.length}');

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          _todayWorkoutLogs = workoutLogs.where((log) {
            final logDate = DateTime(
              log.completedAt.year,
              log.completedAt.month,
              log.completedAt.day,
            );
            return logDate.isAtSameMomentAs(today);
          }).toList();

          _todayMeals = _allMeals.where((meal) {
            return DateUtils.isSameDay(meal.consumedAt, _selectedMealDate);
          }).toList();

          _todayAssignedRecipes = _allAssignedRecipes.where((ar) {
            return DateUtils.isSameDay(ar.assignedDate, _selectedMealDate);
          }).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      print('_loadData FATAL error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _submitRoutine() async {
    if (!_routineFormKey.currentState!.validate()) return;
    _routineFormKey.currentState!.save();

    final success = await _supabaseService.addRoutine(
      _newRoutineName,
      widget.client.userID,
    );

    if (success && mounted) {
      _routineFormKey.currentState!.reset();
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rutina creada con éxito'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  Future<void> _submitAssignTemplateRoutine() async {
    if (_selectedTemplateRoutineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una rutina de la biblioteca'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final template = _templateRoutines.firstWhere(
      (r) => r.id == _selectedTemplateRoutineId,
    );

    // Multi-selection dialog for dates
    final List<DateTime>? pickedDates = await showDialog<List<DateTime>>(
      context: context,
      builder: (context) {
        List<DateTime> tempSelected = [];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                'Selecciona fechas para asignar',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 320,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors.black,
                            onPrimary: Colors.white,
                            onSurface: Colors.black,
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                          onDateChanged: (date) {
                            setDialogState(() {
                              final dateOnly = DateUtils.dateOnly(date);
                              final sameDayIndex = tempSelected.indexWhere(
                                (d) => DateUtils.isSameDay(d, dateOnly),
                              );
                              if (sameDayIndex != -1) {
                                tempSelected.removeAt(sameDayIndex);
                              } else {
                                tempSelected.add(dateOnly);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    if (tempSelected.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Seleccionadas (${tempSelected.length}):',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: tempSelected.map((date) {
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE5E5E5)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    DateFormat('dd/MM').format(date),
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.black),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        tempSelected.remove(date);
                                      });
                                    },
                                    child: const Icon(Icons.close, size: 12, color: Color(0xFF737373)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
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
                  onPressed: tempSelected.isEmpty
                      ? null
                      : () => Navigator.pop(context, tempSelected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[200],
                  ),
                  child: Text(
                    'Asignar',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedDates == null || pickedDates.isEmpty) return;

    setState(() => _isLoading = true);

    // Fetch full routine exercises from database first to make sure we have them
    final fullExs = await _supabaseService.getRoutineExercises(template.id);

    final success = await _supabaseService.assignRoutineToDates(
      userId: widget.client.userID,
      routineId: template.id,
      dates: pickedDates,
      customExercises: fullExs,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _selectedTemplateRoutineId = null;
      });

      if (success) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rutina "${template.name}" asignada para ${pickedDates.length} fechas con éxito'),
            backgroundColor: Colors.black,
          ),
        );
      } else {
        final err = _supabaseService.errorMessage ?? 'Error desconocido';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al asignar la rutina: $err'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoutine(String routineId) async {
    final success = await _supabaseService.deleteRoutine(routineId);
    if (success && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rutina eliminada con éxito'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  Future<void> _scheduleRoutine(Routine routine) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: routine.assignedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
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

    if (picked != null && mounted) {
      setState(() => _isLoading = true);
      final success = await _supabaseService.scheduleRoutine(
        routineId: routine.id,
        date: picked,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rutina programada para el ${DateFormat('dd/MM/yyyy').format(picked)}'),
              backgroundColor: Colors.black,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al programar la rutina'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _unscheduleRoutine(Routine routine) async {
    setState(() => _isLoading = true);
    final success = await _supabaseService.scheduleRoutine(
      routineId: routine.id,
      date: null,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fecha de la rutina removida'),
            backgroundColor: Colors.black,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al remover la fecha de la rutina'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showScheduleOptions(Routine routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Programar Rutina: ${routine.name}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.black),
                title: Text(
                  routine.assignedDate != null ? 'Cambiar Fecha' : 'Seleccionar Fecha',
                  style: GoogleFonts.inter(color: Colors.black),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _scheduleRoutine(routine);
                },
              ),
              if (routine.assignedDate != null)
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined, color: Colors.redAccent),
                  title: Text(
                    'Quitar Programación (Enviar a biblioteca)',
                    style: GoogleFonts.inter(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _unscheduleRoutine(routine);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close, color: Color(0xFF737373)),
                title: Text(
                  'Cancelar',
                  style: GoogleFonts.inter(color: const Color(0xFF737373)),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitRoutineExercise(String routineId) async {
    if (_selectedExerciseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un ejercicio'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final List<double> weights = _weightControllers.map((ctrl) {
      return double.tryParse(ctrl.text) ?? 0.0;
    }).toList();

    final newEx = RoutineExercise(
      id: '',
      routineId: routineId,
      exerciseId: _selectedExerciseId!,
      sets: _exSets,
      reps: _exReps,
      seriesWeights: weights,
      seriesType: _exSeriesType,
    );

    final success = await _supabaseService.addRoutineExercise(newEx);

    if (success && mounted) {
      setState(() {
        _routineIdForAddingExercise = null;
        _selectedExerciseId = null;
      });
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ejercicio asignado con éxito'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  Future<void> _deleteRoutineExercise(String routineExId) async {
    final success = await _supabaseService.deleteRoutineExercise(routineExId);
    if (success && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ejercicio quitado con éxito'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  Future<void> _submitMeal() async {
    if (!_mealFormKey.currentState!.validate()) return;
    _mealFormKey.currentState!.save();

    final consumedAt = DateTime(
      _selectedMealDate.year,
      _selectedMealDate.month,
      _selectedMealDate.day,
      DateTime.now().hour,
      DateTime.now().minute,
      DateTime.now().second,
    );

    final success = await _supabaseService.addMeal(
      _mealName,
      _mealCalories,
      _mealProtein,
      _mealCarbs,
      _mealFat,
      userId: widget.client.userID,
      consumedAt: consumedAt,
    );

    if (success && mounted) {
      _mealFormKey.currentState!.reset();
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comida registrada con éxito'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  Future<void> _confirmDeleteMeal(MealItem meal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Eliminar Registro de Comida',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar este registro de comida?',
          style: GoogleFonts.inter(color: const Color(0xFF525252)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(color: const Color(0xFF737373)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _supabaseService.deleteMeal(
        meal.id,
        userId: widget.client.userID,
      );
      if (success && mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comida eliminada correctamente'),
            backgroundColor: Colors.black,
          ),
        );
      }
    }
  }

  Future<void> _extendPaymentDate() async {
    final currentPaymentDate = _nextPaymentDate ?? DateTime.now();
    final newDate = currentPaymentDate.add(const Duration(days: 30));

    setState(() => _isLoading = true);

    final success = await _supabaseService.updateNextPaymentDate(
      widget.client.userID,
      newDate,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        setState(() {
          _nextPaymentDate = newDate;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fecha de corte extendida hasta el ${_formatDate(newDate)} ✅',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar la fecha de corte'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteProgressRecord(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Eliminar Registro de Medidas',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar este registro de medidas? Esta acción no se puede deshacer.',
          style: GoogleFonts.inter(color: const Color(0xFF525252)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(color: const Color(0xFF737373)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _supabaseService.deleteMeasurementRecord(id);
      if (success && mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro de progreso eliminado'),
            backgroundColor: Colors.black,
          ),
        );
      }
    }
  }

  Future<void> _assignRecipeToClientPlan(Recipe recipe) async {
    final List<DateTime>? pickedDates = await showDialog<List<DateTime>>(
      context: context,
      builder: (context) => MultiDatePickerDialog(initialMonth: DateTime.now()),
    );

    if (pickedDates != null && pickedDates.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      final futures = pickedDates.map((date) {
        return _supabaseService.assignRecipe(
          userId: widget.client.userID,
          recipeId: recipe.id,
          date: date,
        );
      });

      final results = await Future.wait(futures);
      final allSuccess = results.every((success) => success);

      if (mounted) {
        Navigator.pop(context); // Dismiss spinner
        if (allSuccess) {
          Navigator.pop(context); // Close recipe details sheet
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '¡Receta asignada con éxito al plan para ${pickedDates.length} días! 📅',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: Colors.black,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          final err = _supabaseService.errorMessage ?? 'Error desconocido';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al asignar la receta: $err'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _logRecipeAsClientMeal(Recipe recipe) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    final success = await _supabaseService.addMeal(
      recipe.title,
      recipe.calories,
      recipe.protein,
      recipe.carbs,
      recipe.fat,
      imageUrl: recipe.imageUrl,
      userId: widget.client.userID,
    );

    if (mounted) {
      Navigator.pop(context); // Dismiss spinner
      if (success) {
        Navigator.pop(context); // Close recipe detail bottom sheet
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Receta registrada como comida para ${widget.client.name}! 🍽️',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar la comida'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showRecipeDetails(Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24.0),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                    ? Image.network(
                        recipe.imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: const Color(0xFFF5F5F5),
                          child: const Icon(
                            Icons.restaurant,
                            color: Colors.grey,
                            size: 50,
                          ),
                        ),
                      )
                    : Container(
                        height: 200,
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(
                          Icons.restaurant,
                          color: Colors.grey,
                          size: 50,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                recipe.title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTag('${recipe.calories} kcal', Colors.redAccent),
                  const SizedBox(width: 6),
                  _buildTag(
                    '${recipe.protein.toStringAsFixed(0)}g P',
                    Colors.green,
                  ),
                  const SizedBox(width: 6),
                  _buildTag(
                    '${recipe.carbs.toStringAsFixed(0)}g C',
                    Colors.amber,
                  ),
                  const SizedBox(width: 6),
                  _buildTag('${recipe.fat.toStringAsFixed(0)}g G', Colors.blue),
                ],
              ),
              const Divider(height: 32, color: Color(0xFFE5E5E5)),
              Text(
                'Ingredientes',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(recipe.ingredients.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          recipe.ingredients[index],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF525252),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 32, color: Color(0xFFE5E5E5)),
              Text(
                'Instrucciones de Preparación',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(recipe.steps.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          recipe.steps[index],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF525252),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 40, color: Color(0xFFE5E5E5)),
              ElevatedButton.icon(
                onPressed: () => _assignRecipeToClientPlan(recipe),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  'Asignar al Plan de Alimentación 📅',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return "${date.day} de ${months[date.month - 1]}, ${date.year}";
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

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF737373),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF171717),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(width: 1, height: 24, color: const Color(0xFFE5E5E5));
  }

  Widget _buildClientHeaderCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFF5F5F5),
                backgroundImage:
                    widget.client.avatarUrl != null &&
                        widget.client.avatarUrl!.isNotEmpty
                    ? NetworkImage(widget.client.avatarUrl!)
                    : null,
                child:
                    widget.client.avatarUrl == null ||
                        widget.client.avatarUrl!.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: Color(0xFF737373),
                        size: 32,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.client.name,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF171717),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.client.age} años • ${widget.client.height.toStringAsFixed(0)} cm de estatura',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E5E5)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                'Inicial',
                '${widget.client.initialWeight.toStringAsFixed(1)} kg',
              ),
              _buildMetricDivider(),
              _buildMetricItem(
                'Actual',
                '${widget.client.currentWeight.toStringAsFixed(1)} kg',
              ),
              _buildMetricDivider(),
              _buildMetricItem(
                'Meta',
                '${widget.client.targetWeight.toStringAsFixed(1)} kg',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color, {TextStyle? textStyle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style:
            textStyle ??
            GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
      ),
    );
  }

  Widget _buildResumenTab() {
    double totalCalories = 0;
    double totalProtein = 0;

    for (var meal in _todayMeals) {
      totalCalories += meal.calories;
      totalProtein += meal.protein;
    }

    final workoutsCount = _todayWorkoutLogs.length;

    double weightVal = widget.client.currentWeight;
    double cuelloVal = 0.0;
    double chestVal = 0.0;
    double bicepVal = 0.0;
    double abdomenVal = 0.0;
    double waistVal = 0.0;
    double legVal = 0.0;
    double calfVal = 0.0;
    String? latestPhotoUrl;

    if (_records.isNotEmpty) {
      final sortedRecords = List<MeasurementRecord>.from(_records)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latest = sortedRecords.first;
      weightVal = latest.weight;
      cuelloVal = latest.cuello;
      chestVal = latest.chest;
      bicepVal = latest.arm;
      abdomenVal = latest.abdomen;
      waistVal = latest.waist;
      legVal = latest.leg;
      calfVal = latest.calf;
      latestPhotoUrl = latest.photoUrl;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AI Analysis (Black Card at the top for maximum prominence)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Análisis con Inteligencia Artificial',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Genera reportes de progreso o haz consultas sobre este cliente',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isGeneratingAiAnalysis
                            ? null
                            : () => _generateGeneralAiAnalysis(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Análisis General',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isGeneratingAiAnalysis
                            ? null
                            : () => _showCustomQuestionDialog(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Hacer Pregunta',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isGeneratingAiAnalysis) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'La IA está analizando comidas, rutinas y medidas de ${widget.client.name}...',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Medidas Corporales Recientes',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClientProgressChartScreen(
                        clientName: widget.client.name,
                        records: _records,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.show_chart, size: 16, color: Colors.black),
                label: Text(
                  'Ver Gráficas',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _buildResumenMetricBox(
                'Peso',
                '${weightVal.toStringAsFixed(1)} kg',
                Icons.scale,
              ),
              _buildResumenMetricBox(
                'Cuello',
                '${cuelloVal.toStringAsFixed(1)} cm',
                Icons.line_weight,
              ),
              _buildResumenMetricBox(
                'Pecho',
                '${chestVal.toStringAsFixed(1)} cm',
                Icons.accessibility,
              ),
              _buildResumenMetricBox(
                'Bíceps',
                '${bicepVal.toStringAsFixed(1)} cm',
                Icons.fitness_center,
              ),
              _buildResumenMetricBox(
                'Abdomen',
                '${abdomenVal.toStringAsFixed(1)} cm',
                Icons.center_focus_strong,
              ),
              _buildResumenMetricBox(
                'Cintura',
                '${waistVal.toStringAsFixed(1)} cm',
                Icons.airline_seat_recline_normal,
              ),
              _buildResumenMetricBox(
                'Pierna',
                '${legVal.toStringAsFixed(1)} cm',
                Icons.directions_run,
              ),
              _buildResumenMetricBox(
                'Pantorrilla',
                '${calfVal.toStringAsFixed(1)} cm',
                Icons.sports_gymnastics,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Novedades y Actividad',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (latestPhotoUrl != null)
                Text(
                  'Última foto adjuntada',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF737373),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActivityItem(
                      'Últimas Comidas',
                      _meals.isEmpty
                          ? 'No hay comidas registradas recientemente.'
                          : _meals.first.name,
                      Icons.restaurant,
                    ),
                    const SizedBox(height: 8),
                    _buildActivityItem(
                      'Últimos Entrenamientos',
                      _todayWorkoutLogs.isEmpty
                          ? 'No ha realizado entrenamientos hoy.'
                          : _todayWorkoutLogs
                                .map((w) => w.routineName)
                                .join(', '),
                      Icons.fitness_center,
                    ),
                    const SizedBox(height: 8),
                    _buildActivityItem(
                      'Registros de Medidas',
                      _records.isEmpty
                          ? 'Sin registros en el historial.'
                          : 'Se tienen ${_records.length} registros cargados en el historial de progreso.',
                      Icons.history,
                    ),
                  ],
                ),
              ),
              if (latestPhotoUrl != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Image.network(
                        latestPhotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 24,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (_aiChats.isNotEmpty) ...[
            Text(
              'Consultas Guardadas',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _aiChats.length,
              itemBuilder: (context, index) {
                final chat = _aiChats[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.help_outline,
                            color: Color(0xFF737373),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              chat.question,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(chat.createdAt.toLocal()),
                            style: GoogleFonts.inter(
                              color: const Color(0xFF737373),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFF5F5F5)),
                      const SizedBox(height: 10),
                      Text(
                        chat.answer,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF404040),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenMetricBox(String label, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF737373)),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF737373),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF737373)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF737373),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateGeneralAiAnalysis() async {
    setState(() => _isGeneratingAiAnalysis = true);

    try {
      final answer = await _supabaseService.askAiAboutClient(
        widget.client,
        _records,
        _meals,
        _todayWorkoutLogs,
      );

      final targetId = widget.client.userID;
      final coachId =
          _supabaseService.client.auth.currentUser?.id ?? 'mock-coach-123';

      await _supabaseService.saveClientAiChat(
        targetId,
        coachId,
        'Análisis general de progreso del cliente',
        answer,
      );

      final updatedChats = await _supabaseService.getClientAiChats(targetId);

      if (mounted) {
        setState(() {
          _aiChats = updatedChats;
          _isGeneratingAiAnalysis = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Análisis generado correctamente con IA ⚡',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingAiAnalysis = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar análisis: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showCustomQuestionDialog() {
    final queryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 8),
            Text(
              'Preguntar a la I.A. ⚡',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Haz una pregunta específica sobre el peso, medidas, comidas o rutinas de ${widget.client.name}.',
              style: GoogleFonts.inter(
                color: const Color(0xFF737373),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: TextField(
                controller: queryController,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black),
                decoration: InputDecoration(
                  hintText:
                      '¿Cómo consideras que va su consumo calórico y de proteína según sus comidas recientes?',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFFA3A3A3),
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
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
            onPressed: () {
              final query = queryController.text.trim();
              if (query.isNotEmpty) {
                Navigator.pop(context);
                _runCustomAiQuery(query);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Preguntar',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runCustomAiQuery(String question) async {
    setState(() => _isGeneratingAiAnalysis = true);

    try {
      final answer = await _supabaseService.askAiAboutClient(
        widget.client,
        _records,
        _meals,
        _todayWorkoutLogs,
        customQuestion: question,
      );

      final targetId = widget.client.userID;
      final coachId =
          _supabaseService.client.auth.currentUser?.id ?? 'mock-coach-123';

      await _supabaseService.saveClientAiChat(
        targetId,
        coachId,
        question,
        answer,
      );

      final updatedChats = await _supabaseService.getClientAiChats(targetId);

      if (mounted) {
        setState(() {
          _aiChats = updatedChats;
          _isGeneratingAiAnalysis = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Consulta respondida por IA ⚡',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingAiAnalysis = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al consultar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- TAB 0: COMIDAS ---
  Widget _buildComidasTab() {
    double totalCalories = 0;
    double totalProtein = 0;

    for (var meal in _todayMeals) {
      totalCalories += meal.calories;
      totalProtein += meal.protein;
    }

    final workoutsCount = _todayWorkoutLogs.length;

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Horizontal calendar strip
          Container(
            height: 74,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 15,
              itemBuilder: (context, index) {
                final date = DateTime.now().subtract(Duration(days: 7 - index));
                final isSelected = DateUtils.isSameDay(date, _selectedMealDate);
                final dayName = DateFormat('E', 'es').format(date).toUpperCase();
                final dayNumber = date.day.toString();

                 return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMealDate = date;
                      _todayMeals = _allMeals.where((meal) {
                        return DateUtils.isSameDay(meal.consumedAt, date);
                      }).toList();
                      _todayAssignedRecipes = _allAssignedRecipes.where((ar) {
                        return DateUtils.isSameDay(ar.assignedDate, date);
                      }).toList();
                    });
                  },
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.black : const Color(0xFFE5E5E5),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white70 : const Color(0xFF737373),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayNumber,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Text(
            'Comidas Consumidas',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171717),
            ),
          ),
          const SizedBox(height: 12),

          if (_todayMeals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.restaurant_outlined,
                      size: 40,
                      color: Color(0xFFD4D4D4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay comidas registradas.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF737373),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayMeals.length,
              itemBuilder: (context, index) {
                final meal = _todayMeals[index];
                final mealDate = DateFormat(
                  'd MMM, h:mm a',
                  'es',
                ).format(meal.consumedAt);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty) {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.all(16),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    InteractiveViewer(
                                      panEnabled: true,
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      child: Image.network(
                                        meal.imageUrl!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                                ? Image.network(
                                    meal.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.restaurant, size: 24),
                                  )
                                : const Icon(
                                    Icons.restaurant,
                                    color: Color(0xFF737373),
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF171717),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _confirmDeleteMeal(meal),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 24),
          Text(
            'Plan de Alimentación (Recetas)',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171717),
            ),
          ),
          const SizedBox(height: 12),

          if (_todayAssignedRecipes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.assignment_outlined, color: Color(0xFFD4D4D4), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Sin recetas asignadas para este día.',
                    style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayAssignedRecipes.length,
              itemBuilder: (context, index) {
                final assigned = _todayAssignedRecipes[index];
                final recipe = assigned.recipe;

                if (recipe == null) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) ...[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11.0),
                            child: Image.network(
                              recipe.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.restaurant, color: Color(0xFF737373), size: 20),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(child: Icon(Icons.restaurant, color: Colors.white, size: 20)),
                        ),
                      ],
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF171717),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${recipe.calories} kcal • P: ${recipe.protein.toStringAsFixed(0)}g • C: ${recipe.carbs.toStringAsFixed(0)}g • G: ${recipe.fat.toStringAsFixed(0)}g',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: const Color(0xFF737373)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                          );
                          final success = await _supabaseService.unassignRecipe(assignmentId: assigned.id);
                          if (context.mounted) {
                            Navigator.pop(context); // Pop spinner
                            if (success) {
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '¡Receta removida del plan! 🗑️',
                                    style: GoogleFonts.inter(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.black,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ),
    );
  }

  // --- TAB 1: RUTINAS ---
  Widget _buildRutinasTab() {
    final todayRoutines = _clientAssignedRoutines.where((r) {
      return DateUtils.isSameDay(r.assignedDate, _selectedRoutineDate);
    }).toList();

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Horizontal calendar strip
          Container(
            height: 74,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 15,
              itemBuilder: (context, index) {
                final date = DateTime.now().subtract(Duration(days: 7 - index));
                final isSelected = DateUtils.isSameDay(date, _selectedRoutineDate);
                final dayName = DateFormat('E', 'es').format(date).toUpperCase();
                final dayNumber = date.day.toString();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRoutineDate = date;
                    });
                  },
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.black : const Color(0xFFE5E5E5),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white70 : const Color(0xFF737373),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayNumber,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Create/Assign routine panel
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E5E5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Asignar Rutina',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                iconColor: Colors.black,
                collapsedIconColor: Colors.black,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (_templateRoutines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No tienes rutinas en tu biblioteca de ejercicios. Puedes crearlas en la sección "Biblioteca de Ejercicios" para usarlas aquí como plantillas.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF737373),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      value: _selectedTemplateRoutineId,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF171717),
                        fontSize: 13,
                      ),
                      decoration: _buildInputDecoration(
                        'Selecciona rutina plantilla',
                        Icons.assignment_turned_in,
                      ),
                      dropdownColor: Colors.white,
                      items: _templateRoutines.map((r) {
                        return DropdownMenuItem<String>(
                          value: r.id,
                          child: Text(
                            '${r.name} (${r.exercises.length} ejercicios)',
                            style: const TextStyle(color: Colors.black),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedTemplateRoutineId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _submitAssignTemplateRoutine,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Asignar Rutina',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Rutinas Asignadas por Fecha',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF171717),
            ),
          ),
          const SizedBox(height: 12),

          if (todayRoutines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.assignment_outlined,
                      size: 40,
                      color: Color(0xFFD4D4D4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay rutinas asignadas en esta fecha para este cliente.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF737373),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayRoutines.length,
              itemBuilder: (context, index) {
                final assigned = todayRoutines[index];
                final hasCustom = assigned.customExercises.isNotEmpty;
                
                // Find matching workout log
                WorkoutLog? matchingLog;
                for (var log in _allWorkoutLogs) {
                  if (log.routineId == assigned.id) {
                    matchingLog = log;
                    break;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.black,
                        size: 24,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              assigned.routineName,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF171717),
                              ),
                            ),
                          ),
                          if (matchingLog != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'REALIZADA',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        'Fecha: ${DateFormat('dd/MM/yyyy').format(assigned.assignedDate)} • ${assigned.customExercises.length} ejercicios',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF737373),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              await _supabaseService.deleteAssignedRoutine(assigned.id);
                              _loadData();
                            },
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        const Divider(height: 1, color: Color(0xFFE5E5E5)),
                        
                        if (matchingLog != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4), // light green
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('ESTADO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                                    const SizedBox(height: 2),
                                    Text('Completado ✅', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('DURACIÓN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                                    const SizedBox(height: 2),
                                    Text('${(matchingLog.durationSeconds / 60).floor()}m ${matchingLog.durationSeconds % 60}s', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text('VOLUMEN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                                    const SizedBox(height: 2),
                                    Text('${matchingLog.totalVolume.toStringAsFixed(0)} kg', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        if (assigned.customExercises.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            child: Text(
                              'No hay ejercicios asignados a esta rutina.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFA3A3A3),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: assigned.customExercises.length,
                            itemBuilder: (context, i) {
                              final re = assigned.customExercises[i];

                              // Find logged exercise
                              Map<String, dynamic>? loggedEx;
                              if (matchingLog != null) {
                                for (var le in matchingLog.loggedExercises) {
                                  if (le['exercise_name'] == re.exerciseName) {
                                    loggedEx = le as Map<String, dynamic>?;
                                    break;
                                  }
                                }
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFF5F5F5),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.fitness_center,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            re.exerciseName,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF171717),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                'Asignado: ',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF737373),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  '${re.sets} series x ${re.reps} reps • ${re.seriesWeights.map((w) => "${w.toStringAsFixed(0)} kg").join(", ")} • ${re.seriesType}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color: const Color(0xFF737373),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (loggedEx != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Completado:',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF15803D),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ... (loggedEx['sets'] as List).asMap().entries.map((setEntry) {
                                              final setIdx = setEntry.key;
                                              final setData = setEntry.value;
                                              final isCompleted = setData['completed'] == true;
                                              return Padding(
                                                padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      isCompleted ? Icons.check_circle : Icons.cancel,
                                                      size: 12,
                                                      color: isCompleted ? Colors.green : Colors.redAccent,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Serie ${setIdx + 1}: ${setData['weight']} kg x ${setData['reps']} reps',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            if (loggedEx['notes'] != null && loggedEx['notes'].toString().trim().isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8.0, top: 4),
                                                child: Text(
                                                  'Nota del cliente: "${loggedEx['notes']}"',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (matchingLog == null)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: Colors.black,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _showEditAssignedExerciseParamsDialog(assigned, re, i);
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
    );
  }

  void _showEditAssignedExerciseParamsDialog(AssignedRoutine assigned, RoutineExercise re, int exerciseIndex) {
    int sets = re.sets;
    int reps = re.reps;
    String seriesType = re.seriesType;
    List<double> weights = List.from(re.seriesWeights);

    // Keep weight length matching sets
    void adjustWeights() {
      if (weights.length < sets) {
        weights.addAll(List.generate(sets - weights.length, (_) => 0.0));
      } else if (weights.length > sets) {
        weights = weights.sublist(0, sets);
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Personalizar: ${re.exerciseName}',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: sets.toString(),
                        style: const TextStyle(color: Colors.black),
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration('Series', Icons.repeat),
                        onChanged: (val) {
                          final parsed = int.tryParse(val) ?? 1;
                          setDialogState(() {
                            sets = parsed > 0 ? parsed : 1;
                            adjustWeights();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: reps.toString(),
                        style: const TextStyle(color: Colors.black),
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration('Reps', Icons.replay),
                        onChanged: (val) {
                          final parsed = int.tryParse(val) ?? 1;
                          setDialogState(() {
                            reps = parsed > 0 ? parsed : 1;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: seriesType,
                  style: GoogleFonts.inter(color: Colors.black, fontSize: 13),
                  decoration: _buildInputDecoration('Tipo', Icons.star_border),
                  dropdownColor: Colors.white,
                  items: ['Normal', 'Biserie', 'Triserie', 'Superset'].map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type, style: const TextStyle(color: Colors.black)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      seriesType = val ?? 'Normal';
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Carga por serie (kg):',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF737373)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(sets, (idx) {
                    if (weights.length <= idx) {
                      weights.add(0.0);
                    }
                    return SizedBox(
                      width: 65,
                      child: TextFormField(
                        initialValue: weights[idx].toString(),
                        style: GoogleFonts.inter(color: Colors.black, fontSize: 12),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixText: '#${idx + 1}: ',
                          prefixStyle: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 11),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                          ),
                        ),
                        onChanged: (val) {
                          final w = double.tryParse(val) ?? 0.0;
                          weights[idx] = w;
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.inter(color: const Color(0xFF737373))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);

                // Update the custom exercises list
                final updatedExercises = List<RoutineExercise>.from(assigned.customExercises);
                final oldEx = updatedExercises[exerciseIndex];
                updatedExercises[exerciseIndex] = RoutineExercise(
                  id: oldEx.id,
                  routineId: oldEx.routineId,
                  exerciseId: oldEx.exerciseId,
                  sets: sets,
                  reps: reps,
                  seriesWeights: weights,
                  seriesType: seriesType,
                  exerciseName: oldEx.exerciseName,
                  exerciseDescription: oldEx.exerciseDescription,
                  exerciseImageUrl: oldEx.exerciseImageUrl,
                );

                final success = await _supabaseService.updateAssignedRoutineParams(
                  assignedRoutineId: assigned.id,
                  customExercises: updatedExercises,
                );

                if (success) {
                  _loadData();
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al actualizar los parámetros de la rutina'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: Text('Guardar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: RECETAS ---
  Widget _buildRecetasTab() {
    final filtered = _recipes.where((r) {
      return r.title.toLowerCase().contains(_searchQueryRecipes.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Calendar view navigation button for coach
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientRecipesCalendarScreen(
                    clientUserId: widget.client.userID,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 18),
            label: Text(
              'Ver Calendario de Recetas Asignadas',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        // Search Box
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQueryRecipes = val),
              style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar recetas...',
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

        // List View
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.restaurant_menu_outlined,
                        size: 40,
                        color: Color(0xFFD4D4D4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _recipes.isEmpty
                            ? 'No hay recetas en el catálogo.'
                            : 'No se encontraron coincidencias.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final recipe = filtered[index];
                    return GestureDetector(
                      onTap: () => _showRecipeDetails(recipe),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Recipe Thumbnail
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child:
                                    recipe.imageUrl != null &&
                                        recipe.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        recipe.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.restaurant),
                                      )
                                    : const Icon(
                                        Icons.restaurant,
                                        color: Color(0xFF737373),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipe.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF171717),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _buildTag(
                                        '${recipe.calories} kcal',
                                        Colors.redAccent,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildTag(
                                        '${recipe.protein.toStringAsFixed(0)}g P',
                                        Colors.green,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Color(0xFFA3A3A3),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 3: PROGRESO ---
  Widget _buildProgresoTab() {
    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Horizontal cards carousel of measurement records
            if (_records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.show_chart,
                        size: 40,
                        color: Color(0xFFD4D4D4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'El cliente no ha subido fotos ni medidas de progreso.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_records.isNotEmpty) ...[
              SizedBox(
                height: 420,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    return _buildRecordCard(record);
                  },
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Progreso en ${_activeMetric.toLowerCase()}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // Metrics selection chips
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _metricsList.length,
                  itemBuilder: (context, index) {
                    final metric = _metricsList[index]['name']!;
                    final isSelected = _activeMetric == metric;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          metric,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.black,
                        backgroundColor: const Color(0xFFF5F5F5),
                        disabledColor: Colors.transparent,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.black
                              : const Color(0xFFE5E5E5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _activeMetric = metric);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Chart container
              _buildProgressChart(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(MeasurementRecord record) {
    final dateStr = DateFormat('d MMM, yyyy', 'es').format(record.createdAt);

    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image / Photo
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
            child: SizedBox(
              height: 120,
              child: record.photoUrl != null && record.photoUrl!.isNotEmpty
                  ? Image.network(
                      record.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(
                          Icons.fitness_center,
                          color: Color(0xFF737373),
                          size: 36,
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFF5F5F5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFFA3A3A3),
                            size: 30,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sin foto de progreso',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF737373),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Measurement list
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRecordItem(
                    'Peso',
                    '${record.weight.toStringAsFixed(1)} Kg',
                  ),
                  _buildRecordItem(
                    'Cuello',
                    '${record.cuello.toStringAsFixed(0)} cm',
                  ),
                  _buildRecordItem(
                    'Pecho',
                    '${record.chest.toStringAsFixed(0)} cm',
                  ),
                  _buildRecordItem(
                    'Bicep',
                    '${record.arm.toStringAsFixed(0)} cm',
                  ),
                  _buildRecordItem(
                    'Abdomen',
                    '${record.abdomen.toStringAsFixed(0)} cm',
                  ),
                  _buildRecordItem(
                    'Cintura',
                    '${record.waist.toStringAsFixed(0)} cm',
                  ),
                  _buildRecordItem(
                    'Pierna',
                    '${record.leg.toStringAsFixed(0)} cm',
                  ),
                  _buildRecordItem(
                    'Pantorrilla',
                    '${record.calf.toStringAsFixed(0)} cm',
                  ),
                  const Divider(color: Color(0xFFF5F5F5), height: 16),
                  _buildRecordItem('Fecha', dateStr, isBoldValue: true),
                ],
              ),
            ),
          ),

          // Delete button
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            child: TextButton(
              onPressed: () => _deleteProgressRecord(record.id),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 32),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                'Eliminar registro',
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(
    String label,
    String value, {
    bool isBoldValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            color: const Color(0xFF171717),
            fontSize: 13,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Color(0xFF737373)),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressChart() {
    if (_records.length < 2) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'El cliente necesita registrar al menos 2 medidas para visualizar su progreso.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF737373),
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    final sortedRecords = List<MeasurementRecord>.from(_records)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    List<FlSpot> spots = [];
    double minY = double.maxFinite;
    double maxY = double.minPositive;

    for (int i = 0; i < sortedRecords.length; i++) {
      final val = sortedRecords[i].getValueByName(_activeMetric);
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    final rangeY = maxY - minY;
    if (rangeY == 0) {
      minY = minY - 5;
      maxY = maxY + 5;
    } else {
      minY = (minY - (rangeY * 0.15)).clamp(0, double.maxFinite);
      maxY = maxY + (rangeY * 0.15);
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 24, right: 20, left: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Color(0xFFF5F5F5), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            value.toStringAsFixed(1),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF737373),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < sortedRecords.length) {
                          final showTick =
                              sortedRecords.length <= 5 ||
                              idx == 0 ||
                              idx == sortedRecords.length - 1 ||
                              idx == (sortedRecords.length / 2).floor();

                          if (showTick) {
                            final date = sortedRecords[idx].createdAt;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('d MMM', 'es').format(date),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF737373),
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (sortedRecords.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: Colors.black,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.00),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedBarSpot) => Colors.black,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = sortedRecords[spot.x.toInt()].createdAt;
                        final formattedDate = DateFormat(
                          'd MMM, yyyy',
                          'es',
                        ).format(date);
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} ${_metricsList.firstWhere((m) => m['name'] == _activeMetric)['unit']}\n$formattedDate',
                          GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Y: $_activeMetric  •  X: Tiempo',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFA3A3A3),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: FINANZAS ---
  Widget _buildFinanzasTab() {
    final now = DateTime.now();
    final nowDateOnly = DateTime(now.year, now.month, now.day);

    int daysRemaining = 0;
    bool isUrgent = false;
    String formattedDate = 'Sin fecha registrada';

    if (_nextPaymentDate != null) {
      final nextPaymentDateOnly = DateTime(
        _nextPaymentDate!.year,
        _nextPaymentDate!.month,
        _nextPaymentDate!.day,
      );
      daysRemaining = nextPaymentDateOnly.difference(nowDateOnly).inDays;
      isUrgent = daysRemaining <= 5;
      formattedDate = _formatDate(_nextPaymentDate!);
    }

    final paymentHistory = [
      {
        'date': _nextPaymentDate != null
            ? _nextPaymentDate!.subtract(const Duration(days: 30))
            : now.subtract(const Duration(days: 30)),
        'amount': '\$499.00 MXN',
        'method': 'Visa •••• 8842',
        'status': 'Aprobado',
      },
      {
        'date': _nextPaymentDate != null
            ? _nextPaymentDate!.subtract(const Duration(days: 60))
            : now.subtract(const Duration(days: 60)),
        'amount': '\$499.00 MXN',
        'method': 'Visa •••• 8842',
        'status': 'Aprobado',
      },
      {
        'date': _nextPaymentDate != null
            ? _nextPaymentDate!.subtract(const Duration(days: 90))
            : now.subtract(const Duration(days: 90)),
        'amount': '\$499.00 MXN',
        'method': 'Visa •••• 8842',
        'status': 'Aprobado',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cutoff date alert card
          if (_nextPaymentDate != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isUrgent
                      ? [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)]
                      : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUrgent
                      ? const Color(0xFFFCA5A5).withOpacity(0.5)
                      : const Color(0xFF86EFAC).withOpacity(0.5),
                ),
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
                              ? const Color(0xFFEF4444).withOpacity(0.1)
                              : const Color(0xFF22C55E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: isUrgent
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF22C55E),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRÓXIMA FECHA DE CORTE',
                              style: GoogleFonts.inter(
                                color: isUrgent
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF15803D),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? const Color(0xFFEF4444).withOpacity(0.08)
                          : const Color(0xFF22C55E).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      daysRemaining > 0
                          ? 'Faltan $daysRemaining días para la fecha de corte'
                          : daysRemaining == 0
                          ? '¡El pago vence hoy!'
                          : 'Pago vencido por ${-daysRemaining} días',
                      style: GoogleFonts.inter(
                        color: isUrgent
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF15803D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],



          // Payment History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historial de Pagos',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFF737373),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paymentHistory.length,
            itemBuilder: (context, index) {
              final payment = paymentHistory[index];
              final date = payment['date'] as DateTime;
              final dateStr = "${date.day}/${date.month}/${date.year}";

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF22C55E),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Membresía Mensual',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$dateStr • ${payment['method']}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF737373),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          payment['amount'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          payment['status'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF22C55E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Action Button
          ElevatedButton.icon(
            onPressed: _extendPaymentDate,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text(
              'Extender 30 días de Acceso',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjetivosTab() {
    final completedCount = _objectives.where((obj) => obj.completed).length;
    final totalCount = _objectives.length;
    final averagePercent = totalCount > 0 ? (completedCount / totalCount) * 100 : 0.0;

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cumplimiento General',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedCount de $totalCount objetivos logrados',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: totalCount > 0 ? completedCount / totalCount : 0.0,
                            backgroundColor: Colors.white.withOpacity(0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${averagePercent.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lista de Objetivos',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddObjectiveDialog,
                  icon: const Icon(Icons.add, size: 18, color: Colors.black),
                  label: Text(
                    'Nuevo Objetivo',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Objectives list
            if (_objectives.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.playlist_add_check,
                        size: 44,
                        color: Color(0xFFD4D4D4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay objetivos creados para este cliente.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF737373),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _objectives.length,
                itemBuilder: (context, index) {
                  final obj = _objectives[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: CheckboxListTile(
                      value: obj.completed,
                      activeColor: Colors.black,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        obj.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: obj.completed ? const Color(0xFFA3A3A3) : const Color(0xFF171717),
                          decoration: obj.completed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: obj.description != null && obj.description!.isNotEmpty
                          ? Text(
                              obj.description!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF737373),
                              ),
                            )
                          : null,
                      secondary: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _deleteObjective(obj.id),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          _toggleObjective(obj.id, val);
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _toggleObjective(String id, bool completed) async {
    setState(() => _isLoading = true);
    final success = await _supabaseService.toggleObjectiveStatus(id, completed);
    if (success) {
      _loadData();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cambiar el estado del objetivo'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _deleteObjective(String id) async {
    setState(() => _isLoading = true);
    final success = await _supabaseService.deleteObjective(id);
    if (success) {
      _loadData();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al eliminar el objetivo'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showAddObjectiveDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Nuevo Objetivo',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.black),
              decoration: _buildInputDecoration('Título del objetivo', Icons.bookmark_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.black),
              decoration: _buildInputDecoration('Descripción (opcional)', Icons.description_outlined),
            ),
          ],
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
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                final success = await _supabaseService.addObjective(
                  userId: widget.client.userID,
                  title: title,
                  description: descController.text.trim(),
                );

                if (success) {
                  _loadData();
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al agregar el objetivo'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (err) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error crítico: $err'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: Text(
              'Crear',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
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
            'Gestionar Cliente',
            style: GoogleFonts.inter(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.black,
            labelColor: Colors.black,
            unselectedLabelColor: const Color(0xFF737373),
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.normal,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Resumen'),
              Tab(text: 'Comidas'),
              Tab(text: 'Objetivos'),
              Tab(text: 'Rutinas'),
              Tab(text: 'Recetas'),
              Tab(text: 'Progreso'),
              Tab(text: 'Finanzas'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black),
              )
            : Column(
                children: [
                  _buildClientHeaderCard(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildResumenTab(),
                        _buildComidasTab(),
                        _buildObjetivosTab(),
                        _buildRutinasTab(),
                        _buildRecetasTab(),
                        _buildProgresoTab(),
                        _buildFinanzasTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class MultiDatePickerDialog extends StatefulWidget {
  final DateTime initialMonth;
  const MultiDatePickerDialog({super.key, required this.initialMonth});

  @override
  State<MultiDatePickerDialog> createState() => _MultiDatePickerDialogState();
}

class _MultiDatePickerDialogState extends State<MultiDatePickerDialog> {
  late DateTime _currentMonth;
  final Set<DateTime> _selectedDates = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  void _toggleDate(DateTime date) {
    setState(() {
      final normalized = DateTime(date.year, date.month, date.day);
      if (_selectedDates.contains(normalized)) {
        _selectedDates.remove(normalized);
      } else {
        _selectedDates.add(normalized);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final monthName = DateFormat('MMMM yyyy', 'es').format(_currentMonth);

    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    final firstWeekday = firstDayOfMonth.weekday - 1;
    final totalGridCells = daysInMonth + firstWeekday;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
              });
            },
          ),
          Text(
            monthName[0].toUpperCase() + monthName.substring(1),
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.black),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        height: 310,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['LU', 'MA', 'MI', 'JU', 'VI', 'SÁ', 'DO'].map((day) {
                return SizedBox(
                  width: 38,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF737373),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: totalGridCells,
                itemBuilder: (context, index) {
                  if (index < firstWeekday) {
                    return const SizedBox();
                  }

                  final day = index - firstWeekday + 1;
                  final date = DateTime(year, month, day);
                  final normalized = DateTime(year, month, day);
                  final isSelected = _selectedDates.contains(normalized);
                  final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

                  return GestureDetector(
                    onTap: isPast ? null : () => _toggleDate(date),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        day.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : isPast
                                  ? const Color(0xFFD4D4D4)
                                  : Colors.black,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, <DateTime>[]),
          child: Text(
            'Cancelar',
            style: GoogleFonts.inter(color: const Color(0xFF737373)),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedDates.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedDates.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE5E5E5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            'Asignar (${_selectedDates.length})',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class ClientProgressChartScreen extends StatefulWidget {
  final String clientName;
  final List<MeasurementRecord> records;

  const ClientProgressChartScreen({
    super.key,
    required this.clientName,
    required this.records,
  });

  @override
  State<ClientProgressChartScreen> createState() => _ClientProgressChartScreenState();
}

class _ClientProgressChartScreenState extends State<ClientProgressChartScreen> {
  String _activeMetric = 'Peso';
  final List<Map<String, String>> _metricsList = [
    {'name': 'Peso', 'unit': 'Kg'},
    {'name': 'Abdomen', 'unit': 'cm'},
    {'name': 'Cintura', 'unit': 'cm'},
    {'name': 'Pierna', 'unit': 'cm'},
    {'name': 'Pecho', 'unit': 'cm'},
    {'name': 'Bicep', 'unit': 'cm'},
    {'name': 'Pantorrilla', 'unit': 'cm'},
    {'name': 'Cuello', 'unit': 'cm'},
  ];

  @override
  Widget build(BuildContext context) {
    final sortedRecords = List<MeasurementRecord>.from(widget.records)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
          'Progreso: ${widget.clientName}',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Metric selector chips row
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _metricsList.length,
                itemBuilder: (context, index) {
                  final metric = _metricsList[index];
                  final isSelected = _activeMetric == metric['name'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        '${metric['name']} (${metric['unit']})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF737373),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.black,
                      backgroundColor: Colors.white,
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
                            _activeMetric = metric['name']!;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            if (sortedRecords.length < 2)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'El cliente necesita registrar al menos 2 medidas para visualizar su progreso.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF737373),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              )
            else
              _buildChartCard(sortedRecords),
            const SizedBox(height: 24),
            Text(
              'Historial de Medidas',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            if (sortedRecords.isEmpty)
              Center(
                child: Text(
                  'No hay medidas registradas.',
                  style: GoogleFonts.inter(color: const Color(0xFF737373)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedRecords.length,
                itemBuilder: (context, index) {
                  final record = sortedRecords[sortedRecords.length - 1 - index];
                  final val = record.getValueByName(_activeMetric);
                  final unit = _metricsList.firstWhere((m) => m['name'] == _activeMetric)['unit'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy').format(record.createdAt),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF171717),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${val.toStringAsFixed(1)} $unit',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(List<MeasurementRecord> sortedRecords) {
    List<FlSpot> spots = [];
    double minY = double.maxFinite;
    double maxY = double.minPositive;

    for (int i = 0; i < sortedRecords.length; i++) {
      final val = sortedRecords[i].getValueByName(_activeMetric);
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    final rangeY = maxY - minY;
    if (rangeY == 0) {
      minY = minY - 5;
      maxY = maxY + 5;
    } else {
      minY = (minY - (rangeY * 0.15)).clamp(0, double.maxFinite);
      maxY = maxY + (rangeY * 0.15);
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.only(top: 24, right: 20, left: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                const FlLine(color: Color(0xFFF5F5F5), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      value.toStringAsFixed(1),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF737373),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < sortedRecords.length) {
                    final showTick =
                        sortedRecords.length <= 5 ||
                        idx == 0 ||
                        idx == sortedRecords.length - 1 ||
                        idx == (sortedRecords.length / 2).floor();

                    if (showTick) {
                      final date = sortedRecords[idx].createdAt;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('d MMM', 'es').format(date),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF737373),
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sortedRecords.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.black,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.08),
                    Colors.black.withOpacity(0.00),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedBarSpot) => Colors.black,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = sortedRecords[spot.x.toInt()].createdAt;
                  final unit = _metricsList.firstWhere((m) => m['name'] == _activeMetric)['unit'];
                  return LineTooltipItem(
                    '${DateFormat('dd/MM/yyyy').format(date)}\n${spot.y.toStringAsFixed(1)} $unit',
                    GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
