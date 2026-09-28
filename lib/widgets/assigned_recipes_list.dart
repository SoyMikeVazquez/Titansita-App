import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/assigned_recipe.dart';
import '../models/recipe.dart';
import '../screens/client_recipes_calendar_screen.dart';

class AssignedRecipesList extends StatelessWidget {
  final List<AssignedRecipe> assignedRecipes;
  final VoidCallback onRefresh;
  final Function(Recipe recipe) onLogRecipe;

  const AssignedRecipesList({
    super.key,
    required this.assignedRecipes,
    required this.onRefresh,
    required this.onLogRecipe,
  });

  void _showRecipeDetails(BuildContext context, Recipe recipe) {
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
              const SizedBox(height: 24),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Recetas del Plan Asignadas',
            style: GoogleFonts.inter(
              color: const Color(0xFF171717),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClientRecipesCalendarScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: const Color(0xFFE5E5E5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: const Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calendario de Recetas',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF171717),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Explora tus recetas por día',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF737373),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFFA3A3A3),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (assignedRecipes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: Color(0xFFA3A3A3),
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No tienes recetas asignadas para hoy',
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
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: assignedRecipes.length,
            itemBuilder: (context, index) {
              final assigned = assignedRecipes[index];
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
                child: InkWell(
                  onTap: () => _showRecipeDetails(context, recipe),
                  borderRadius: BorderRadius.circular(18.0),
                  child: Row(
                    children: [
                      // Photo
                      if (recipe.imageUrl != null &&
                          recipe.imageUrl!.isNotEmpty) ...[
                        Container(
                          width: 56,
                          height: 56,
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
                                  const Icon(
                                    Icons.restaurant,
                                    color: Color(0xFF737373),
                                    size: 22,
                                  ),
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
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            color: Color(0xFFA3A3A3),
                            size: 24,
                          ),
                        ),
                      ],
                      const SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.title,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF171717),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${recipe.calories} kcal • P: ${recipe.protein.toStringAsFixed(0)}g • C: ${recipe.carbs.toStringAsFixed(0)}g • G: ${recipe.fat.toStringAsFixed(0)}g',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF737373),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Log Consumption Button
                      Tooltip(
                        message: 'Registrar como comida consumida',
                        child: Material(
                          color: const Color(0xFFF5F5F5),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(
                              Icons.add_task_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                            onPressed: () => onLogRecipe(recipe),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
