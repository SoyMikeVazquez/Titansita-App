import 'package:flutter/material.dart';
import '../models/established_exercise.dart';
import '../utils/exercise_gifs.dart';

class ExercisesList extends StatefulWidget {
  final List<EstablishedExercise> exercises;
  const ExercisesList({super.key, required this.exercises});

  @override
  State<ExercisesList> createState() => _ExercisesListState();
}

class _ExercisesListState extends State<ExercisesList> {
  void _showExerciseDetails(
    BuildContext context,
    EstablishedExercise exercise,
    String? gifUrl,
  ) {
    final instructions = ExerciseGifs.getInstructions(exercise.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Large GIF Demo
                      if (gifUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18.0),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Image.network(
                              gifUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: const Color(0xFFF5F5F5),
                                    child: const Icon(
                                      Icons.fitness_center,
                                      size: 40,
                                      color: Color(0xFF737373),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Exercise Title
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          color: Color(0xFF171717),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tags Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMetricTag(
                            '${exercise.sets} Series',
                            Icons.grid_view_rounded,
                          ),
                          _buildMetricTag(
                            '${exercise.reps} Reps',
                            Icons.repeat_rounded,
                          ),
                          if (exercise.weight > 0)
                            _buildMetricTag(
                              '${exercise.weight.toStringAsFixed(0)} kg',
                              Icons.fitness_center_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE5E5E5)),
                      const SizedBox(height: 12),
                      // Instructions Title
                      const Text(
                        'Guía de Ejecución',
                        style: TextStyle(
                          color: Color(0xFF171717),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Instructions List
                      ...instructions.map(
                        (step) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6.0, right: 10.0),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: Colors.black,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  step,
                                  style: const TextStyle(
                                    color: Color(0xFF525252),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF737373)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF171717),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Container(
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: const Text(
            'No tienes ejercicios establecidos para hoy',
            style: TextStyle(color: Color(0xFF737373)),
          ),
        ),
      );
    }

    final completedCount = widget.exercises.where((e) => e.isCompleted).length;
    final totalCount = widget.exercises.length;
    final completionPercentage = totalCount > 0
        ? completedCount / totalCount
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ejercicios Establecidos',
                    style: TextStyle(
                      color: Color(0xFF171717),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Completados: $completedCount de $totalCount (${(completionPercentage * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      color: Color(0xFF737373),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: completionPercentage,
                      strokeWidth: 3.5,
                      backgroundColor: const Color(0xFFE5E5E5),
                      color: Colors.black,
                    ),
                    Text(
                      '${(completionPercentage * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          itemCount: widget.exercises.length,
          itemBuilder: (context, index) {
            final exercise = widget.exercises[index];
            final gifUrl = ExerciseGifs.getGifUrl(exercise.name);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: exercise.isCompleted
                    ? const Color(0xFFF5F5F5)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18.0),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        exercise.isCompleted = !exercise.isCompleted;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: exercise.isCompleted
                            ? Colors.black
                            : Colors.transparent,
                        border: Border.all(
                          color: exercise.isCompleted
                              ? Colors.black
                              : const Color(0xFFD4D4D4),
                          width: 2.0,
                        ),
                      ),
                      child: exercise.isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          _showExerciseDetails(context, exercise, gifUrl),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style: TextStyle(
                                    color: exercise.isCompleted
                                        ? const Color(0xFFA3A3A3)
                                        : const Color(0xFF171717),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    decoration: exercise.isCompleted
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${exercise.sets} series x ${exercise.reps} reps',
                                      style: TextStyle(
                                        color: exercise.isCompleted
                                            ? const Color(0xFFD4D4D4)
                                            : const Color(0xFF737373),
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (exercise.weight > 0) ...[
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: exercise.isCompleted
                                              ? const Color(0xFFD4D4D4)
                                              : const Color(0xFFA3A3A3),
                                        ),
                                      ),
                                      Text(
                                        '${exercise.weight.toStringAsFixed(0)} kg',
                                        style: TextStyle(
                                          color: exercise.isCompleted
                                              ? const Color(0xFFD4D4D4)
                                              : const Color(0xFF171717),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: const Color(0xFFE5E5E5),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10.0),
                              child: gifUrl != null
                                  ? Image.network(
                                      gifUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.fitness_center,
                                                color: Color(0xFF737373),
                                                size: 18,
                                              ),
                                    )
                                  : const Icon(
                                      Icons.fitness_center,
                                      color: Color(0xFF737373),
                                      size: 18,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
