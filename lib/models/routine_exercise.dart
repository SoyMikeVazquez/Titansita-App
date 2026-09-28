class RoutineExercise {
  final String id;
  final String routineId;
  final String exerciseId;
  final int sets;
  final int reps;
  final List<double> seriesWeights;
  final String seriesType; // 'Normal', 'Biserie', 'Triserie', 'Superset'
  final String exerciseName;
  final String exerciseDescription;
  final String? exerciseImageUrl;

  RoutineExercise({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.seriesWeights,
    this.seriesType = 'Normal',
    this.exerciseName = '',
    this.exerciseDescription = '',
    this.exerciseImageUrl,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    List<double> weightsList = [];
    if (json['series_weights'] != null) {
      if (json['series_weights'] is List) {
        weightsList = (json['series_weights'] as List)
            .map((w) => (w as num).toDouble())
            .toList();
      }
    }
    
    // Fallback if weightsList is shorter than sets
    final numSets = (json['sets'] as num?)?.toInt() ?? 3;
    final int targetLength = numSets > 0 ? numSets : 3;
    if (weightsList.length < targetLength) {
      final defaultWeight = weightsList.isNotEmpty ? weightsList.first : 0.0;
      weightsList = List<double>.filled(targetLength, defaultWeight);
    }

    // Access nested joined exercise fields if they exist
    final exerciseMap = json['ejercicios'] as Map<String, dynamic>?;

    return RoutineExercise(
      id: json['id']?.toString() ?? '',
      routineId: json['routine_id']?.toString() ?? '',
      exerciseId: json['exercise_id']?.toString() ?? '',
      sets: numSets,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
      seriesWeights: weightsList,
      seriesType: json['series_type'] ?? 'Normal',
      exerciseName: exerciseMap?['name'] ?? json['exercise_name'] ?? 'Ejercicio',
      exerciseDescription: exerciseMap?['description'] ?? json['exercise_description'] ?? '',
      exerciseImageUrl: exerciseMap?['image_url'] ?? json['exercise_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routine_id': routineId,
      'exercise_id': exerciseId,
      'sets': sets,
      'reps': reps,
      'series_weights': seriesWeights,
      'series_type': seriesType,
    };
  }
}
