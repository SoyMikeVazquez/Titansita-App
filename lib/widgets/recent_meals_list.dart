import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/meal_item.dart';
import 'package:intl/intl.dart';

class RecentMealsList extends StatelessWidget {
  final List<MealItem> meals;
  final VoidCallback onAddMeal;
  final VoidCallback onScanMealIA;
  final VoidCallback onViewHistory;

  const RecentMealsList({
    super.key, 
    required this.meals,
    required this.onAddMeal,
    required this.onScanMealIA,
    required this.onViewHistory,
  });

  /// Filter meals to only show today's meals
  List<MealItem> get _todayMeals {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return meals.where((meal) {
      return meal.consumedAt.isAfter(startOfToday) ||
          (meal.consumedAt.year == now.year &&
              meal.consumedAt.month == now.month &&
              meal.consumedAt.day == now.day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final todayMeals = _todayMeals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Comidas del Día',
            style: GoogleFonts.inter(
              color: const Color(0xFF171717),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (todayMeals.isEmpty)
          Container(
            height: 100,
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: const Color(0xFFE5E5E5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant_outlined, color: Color(0xFFA3A3A3), size: 24),
                const SizedBox(height: 6),
                Text(
                  'No has registrado comidas hoy',
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
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: todayMeals.length,
            itemBuilder: (context, index) {
              final meal = todayMeals[index];
              final timeStr = DateFormat('hh:mm a').format(meal.consumedAt);

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18.0),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Photo thumbnail
                    if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty) ...[
                      Container(
                        width: 52,
                        height: 52,
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
                      const SizedBox(width: 14),
                    ] else ...[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: const Icon(Icons.restaurant, color: Color(0xFFA3A3A3), size: 22),
                      ),
                      const SizedBox(width: 14),
                    ],
                    // Name + time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.name,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF171717),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeStr,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFA3A3A3),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: onViewHistory,
            icon: const Icon(Icons.history, color: Colors.black, size: 16),
            label: Text(
              'Ver historial completo',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}
