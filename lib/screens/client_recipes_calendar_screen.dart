import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/assigned_recipe.dart';
import '../models/recipe.dart';
import '../services/supabase_service.dart';

class ClientRecipesCalendarScreen extends StatefulWidget {
  final String? clientUserId; // If null, loads current logged in client's recipes

  const ClientRecipesCalendarScreen({
    key,
    this.clientUserId,
  }) : super(key: key);

  @override
  State<ClientRecipesCalendarScreen> createState() => _ClientRecipesCalendarScreenState();
}

class _ClientRecipesCalendarScreenState extends State<ClientRecipesCalendarScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  DateTime _selectedDate = DateTime.now();
  List<AssignedRecipe> _assignedRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedRecipes();
  }

  Future<void> _loadAssignedRecipes() async {
    setState(() => _isLoading = true);
    try {
      final recipes = await _supabaseService.getAssignedRecipes(
        userId: widget.clientUserId,
        date: _selectedDate,
      );
      setState(() {
        _assignedRecipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar recetas: $e')),
      );
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadAssignedRecipes();
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
              const SizedBox(height: 20),
              if (recipe.ingredients.isNotEmpty) ...[
                Text(
                  'Ingredientes',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                ...recipe.ingredients.map((ing) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6.0, right: 8.0),
                            child: Icon(Icons.circle, size: 6, color: Colors.black54),
                          ),
                          Expanded(
                            child: Text(
                              ing,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF525252),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 24),
              ],
              if (recipe.steps.isNotEmpty) ...[
                Text(
                  'Preparación',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                ...recipe.steps.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final step = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$idx',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF525252),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Recetas Asignadas',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Dynamic Weekly Horizontal Calendar view
          _buildCalendarHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _buildRecipesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final now = DateTime.now();
    // Generate dates around today (-3 to +10 days)
    final List<DateTime> dates = List.generate(
      14,
      (index) => DateUtils.dateOnly(now.subtract(const Duration(days: 3)).add(Duration(days: index))),
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              DateFormat('MMMM yyyy', 'es').format(_selectedDate).toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF737373),
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                final dayName = DateFormat('E', 'es').format(date).substring(0, 1).toUpperCase();
                final dayNumber = DateFormat('d').format(date);

                return GestureDetector(
                  onTap: () => _onDateSelected(date),
                  child: Container(
                    width: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? Colors.black : const Color(0xFFE5E5E5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white70 : const Color(0xFF737373),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayNumber,
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
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

  Widget _buildRecipesList() {
    if (_assignedRecipes.isEmpty) {
      return RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _loadAssignedRecipes,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.4,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restaurant_menu_outlined, size: 48, color: Color(0xFFD4D4D4)),
                  const SizedBox(height: 12),
                  Text(
                    'No hay recetas asignadas para esta fecha.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF737373),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: _loadAssignedRecipes,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: _assignedRecipes.length,
      itemBuilder: (context, index) {
        final assigned = _assignedRecipes[index];
        final recipe = assigned.recipe;

        if (recipe == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: const Color(0xFFE5E5E5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _showRecipeDetails(recipe),
                borderRadius: BorderRadius.circular(18.0),
                child: Row(
                  children: [
                    if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.network(
                          recipe.imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFFF5F5F5),
                            child: const Icon(Icons.restaurant, color: Colors.grey, size: 24),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: const Icon(Icons.restaurant, color: Colors.grey, size: 24),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  ],
                ),
              ),
              if (assigned.notes != null && assigned.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          assigned.notes!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF92400E),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Coach note editing controls
              if (widget.clientUserId != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final ctrl = TextEditingController(text: assigned.notes ?? '');
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.white,
                          title: Text(
                            'Notas extras para la receta',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          content: TextField(
                            controller: ctrl,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Ej. Consumir antes de entrenar, o cambiar camote por arroz...',
                              hintStyle: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 13),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancelar', style: GoogleFonts.inter(color: const Color(0xFF737373))),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final text = ctrl.text.trim();
                                Navigator.pop(context);
                                setState(() => _isLoading = true);
                                final ok = await _supabaseService.updateAssignedRecipeNotes(
                                  assignmentId: assigned.id,
                                  notes: text,
                                );
                                if (ok) {
                                  _loadAssignedRecipes();
                                } else {
                                  setState(() => _isLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Error al guardar notas de receta'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                              child: Text(
                                'Guardar',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_note_outlined, size: 16, color: Colors.black),
                    label: Text(
                      assigned.notes != null && assigned.notes!.isNotEmpty ? 'Editar Nota' : 'Agregar Nota',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
    );
  }
}
