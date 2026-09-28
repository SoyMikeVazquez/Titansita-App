import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import '../models/workout_log.dart';
import '../models/meal_item.dart';
import '../models/assigned_recipe.dart';

class ClientDailyManagementScreen extends StatefulWidget {
  final UserProfile client;
  const ClientDailyManagementScreen({super.key, required this.client});

  @override
  State<ClientDailyManagementScreen> createState() => _ClientDailyManagementScreenState();
}

class _ClientDailyManagementScreenState extends State<ClientDailyManagementScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  String? _error;

  List<WorkoutLog> _allWorkoutLogs = [];
  List<MealItem> _allMeals = [];
  List<AssignedRecipe> _allAssignedRecipes = [];
  late DateTime _selectedDate;
  late List<DateTime> _dateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _generateDateRange();
    _loadData();
  }

  void _generateDateRange() {
    // Generate last 14 days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _dateRange = List.generate(14, (index) {
      return today.subtract(Duration(days: 13 - index));
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final logs = await _supabaseService.getWorkoutLogs(userId: widget.client.userID);
      final meals = await _supabaseService.getAllMeals(userId: widget.client.userID);
      final assigned = await _supabaseService.getAssignedRecipes(userId: widget.client.userID);

      if (mounted) {
        setState(() {
          _allWorkoutLogs = logs;
          _allMeals = meals;
          _allAssignedRecipes = assigned;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar datos: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<WorkoutLog> _getFilteredWorkoutLogs() {
    return _allWorkoutLogs.where((log) {
      final logDate = DateTime(log.completedAt.year, log.completedAt.month, log.completedAt.day);
      return logDate.isAtSameMomentAs(_selectedDate);
    }).toList();
  }

  List<MealItem> _getFilteredMeals() {
    return _allMeals.where((meal) {
      final mealDate = DateTime(meal.consumedAt.year, meal.consumedAt.month, meal.consumedAt.day);
      return mealDate.isAtSameMomentAs(_selectedDate);
    }).toList();
  }

  List<AssignedRecipe> _getFilteredAssignedRecipes() {
    return _allAssignedRecipes.where((ar) {
      final arDate = DateTime(ar.assignedDate.year, ar.assignedDate.month, ar.assignedDate.day);
      return arDate.isAtSameMomentAs(_selectedDate);
    }).toList();
  }

  Map<String, double> _calculateTotalMacros(List<MealItem> meals) {
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (var meal in meals) {
      calories += meal.calories;
      protein += meal.protein;
      carbs += meal.carbs;
      fat += meal.fat;
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _getFilteredWorkoutLogs();
    final filteredMeals = _getFilteredMeals();
    final filteredAssignedRecipes = _getFilteredAssignedRecipes();
    final totals = _calculateTotalMacros(filteredMeals);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Gestión de ${widget.client.name}',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Seguimiento diario detallado',
              style: GoogleFonts.inter(
                color: const Color(0xFF737373),
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black, size: 20),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Color(0xFF737373)), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                          child: const Text('Reintentar'),
                        )
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Horizontal Calendar Selector
                    _buildHorizontalCalendar(),

                    Expanded(
                      child: RefreshIndicator(
                        color: Colors.black,
                        backgroundColor: Colors.white,
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Resumen de Macros del Día
                              _buildMacrosSummaryCard(totals),
                              const SizedBox(height: 24),

                              // 2. Sección Ejercicios Completados
                              _buildSectionHeader('Entrenamientos Realizados', Icons.fitness_center),
                              const SizedBox(height: 12),
                              _buildWorkoutSection(filteredLogs),
                              const SizedBox(height: 24),

                              // 3. Sección Comidas del Día
                              _buildSectionHeader('Comidas Consumidas', Icons.restaurant),
                              const SizedBox(height: 12),
                              _buildMealsSection(filteredMeals),
                              const SizedBox(height: 24),

                              // 4. Sección Plan de Alimentación (Recetas Asignadas)
                              _buildSectionHeader('Plan de Alimentación (Recetas)', Icons.assignment_outlined),
                              const SizedBox(height: 12),
                              _buildAssignedRecipesSection(filteredAssignedRecipes),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHorizontalCalendar() {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final selectedMonthYear = "${months[_selectedDate.month - 1]} ${_selectedDate.year}";

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedMonthYear,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Desliza para ver más días',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF737373),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 74,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _dateRange.length,
              itemBuilder: (context, index) {
                final date = _dateRange[index];
                final isSelected = date.isAtSameMomentAs(_selectedDate);
                final dayOfWeek = _getDayOfWeekAbbr(date.weekday);
                final isToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
                    .isAtSameMomentAs(date);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    width: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.black 
                            : isToday 
                                ? Colors.black.withOpacity(0.3)
                                : const Color(0xFFE5E5E5),
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayOfWeek,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${date.day}',
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
        ],
      ),
    );
  }

  String _getDayOfWeekAbbr(int weekday) {
    switch (weekday) {
      case 1: return 'Lun';
      case 2: return 'Mar';
      case 3: return 'Mié';
      case 4: return 'Jue';
      case 5: return 'Vie';
      case 6: return 'Sáb';
      case 7: return 'Dom';
      default: return '';
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildMacrosSummaryCard(Map<String, double> totals) {
    final calories = totals['calories'] ?? 0;
    final protein = totals['protein'] ?? 0;
    final carbs = totals['carbs'] ?? 0;
    final fat = totals['fat'] ?? 0;

    // Target values
    const targetCalories = 2200.0;
    const targetProtein = 150.0;
    const targetCarbs = 200.0;
    const targetFat = 70.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consumo Nutricional',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                '${calories.toStringAsFixed(0)} / ${targetCalories.toStringAsFixed(0)} kcal',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF737373),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Calories linear progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: calories > 0 ? (calories / targetCalories).clamp(0.0, 1.0) : 0,
              backgroundColor: const Color(0xFFF5F5F5),
              color: Colors.black,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroProgressColumn('Proteínas', protein, targetProtein, 'g', Colors.redAccent),
              _buildMacroProgressColumn('Carbos', carbs, targetCarbs, 'g', Colors.amber),
              _buildMacroProgressColumn('Grasas', fat, targetFat, 'g', Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroProgressColumn(String label, double value, double target, String unit, Color color) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF737373),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFF5F5F5),
                color: color,
                strokeWidth: 5,
              ),
              Center(
                child: Text(
                  '${value.toStringAsFixed(0)}$unit',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'meta: ${target.toStringAsFixed(0)}g',
          style: GoogleFonts.inter(
            fontSize: 9,
            color: const Color(0xFFA3A3A3),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutSection(List<WorkoutLog> logs) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          children: [
            const Icon(Icons.fitness_center, color: Color(0xFFD4D4D4), size: 36),
            const SizedBox(height: 8),
            Text(
              'Sin entrenamientos registrados para este día.',
              style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final durationMinutes = log.durationSeconds ~/ 60;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      log.routineName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF737373)),
                        const SizedBox(width: 4),
                        Text(
                          '$durationMinutes min',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF737373), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Volumen total: ${log.totalVolume.toStringAsFixed(0)} kg • ${log.totalSets} series totales',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF737373)),
              ),
              const Divider(height: 20, color: Color(0xFFE5E5E5)),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: log.loggedExercises.length,
                itemBuilder: (context, exIdx) {
                  final ex = log.loggedExercises[exIdx];
                  final exName = ex['exercise_name'] ?? 'Ejercicio';
                  final setsList = ex['sets'] as List?;
                  final completedSets = setsList?.where((s) => s['completed'] == true).length ?? 0;
                  final totalSets = setsList?.length ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            exName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF171717),
                            ),
                          ),
                        ),
                        Text(
                          '$completedSets/$totalSets series',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF737373),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMealsSection(List<MealItem> meals) {
    if (meals.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          children: [
            const Icon(Icons.restaurant, color: Color(0xFFD4D4D4), size: 36),
            const SizedBox(height: 8),
            Text(
              'Sin comidas registradas para este día.',
              style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final meal = meals[index];
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
              if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty) ...[
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
                      meal.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.restaurant, color: Color(0xFF737373), size: 20),
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
                      meal.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF171717),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${meal.calories} kcal • P: ${meal.protein.toStringAsFixed(0)}g • C: ${meal.carbs.toStringAsFixed(0)}g • G: ${meal.fat.toStringAsFixed(0)}g',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${meal.consumedAt.hour.toString().padLeft(2, '0')}:${meal.consumedAt.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFFA3A3A3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssignedRecipesSection(List<AssignedRecipe> assignedList) {
    if (assignedList.isEmpty) {
      return Container(
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
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assignedList.length,
      itemBuilder: (context, index) {
        final assigned = assignedList[index];
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
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.restaurant, color: Color(0xFF737373), size: 20),
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
                        fontSize: 11,
                        color: const Color(0xFF737373),
                      ),
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
    );
  }
}
