import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/routine.dart';
import '../screens/workout_tab.dart';
import '../utils/cors_helper.dart';

class DailyRoutineCard extends StatelessWidget {
  final List<Routine> routines;
  final DateTime selectedDate;

  const DailyRoutineCard({
    super.key,
    required this.routines,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    // Get routines for today (up to 2)
    final todayRoutines = routines
        .where((r) {
          if (r.assignedDate == null) return false;
          final assignD = DateTime(r.assignedDate!.year, r.assignedDate!.month, r.assignedDate!.day);
          return assignD.isAtSameMomentAs(selectedDate);
        })
        .take(2)
        .toList();

    if (todayRoutines.isEmpty) {
      return SizedBox(
        height: 140,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E5E5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_outlined, color: Color(0xFFA3A3A3), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Sin rutina asignada hoy',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF737373),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rutina del Día',
            style: GoogleFonts.inter(
              color: const Color(0xFF171717),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...todayRoutines.asMap().entries.map((entry) {
            final index = entry.key;
            final routine = entry.value;
            final exerciseCount = routine.exercises.length;

            return Padding(
              padding: EdgeInsets.only(bottom: index < todayRoutines.length - 1 ? 12 : 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: index == 0 ? Colors.black : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(6),
                              border: index == 0 ? null : Border.all(color: const Color(0xFFD4D4D4)),
                            ),
                            child: Text(
                              index == 0 ? 'Rutina Principal' : 'Rutina Opcional',
                              style: GoogleFonts.inter(
                                color: index == 0 ? Colors.white : Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  routine.name,
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$exerciseCount ejercicios',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF737373),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE5E5E5)),
                            ),
                            child: Text(
                              '${exerciseCount}x',
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 12,
                                  fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (routine.exercises.isNotEmpty) ...[
                        const Divider(color: Color(0xFFE5E5E5), height: 24),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: routine.exercises.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, exIndex) {
                            final ex = routine.exercises[exIndex];
                            return Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    color: const Color(0xFFF5F5F5),
                                    child: (ex.exerciseImageUrl != null && ex.exerciseImageUrl!.isNotEmpty)
                                        ? Image.network(
                                            getCorsFriendlyUrl(ex.exerciseImageUrl!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.fitness_center, color: Color(0xFF737373), size: 24),
                                          )
                                        : const Icon(Icons.fitness_center, color: Color(0xFF737373), size: 24),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex.exerciseName,
                                        style: GoogleFonts.inter(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${ex.sets} series x ${ex.reps} reps' + (ex.seriesType != 'Normal' ? ' • ${ex.seriesType}' : ''),
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF737373),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WorkoutTab(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Ver Rutina Completa',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
