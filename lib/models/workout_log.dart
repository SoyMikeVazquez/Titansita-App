class WorkoutLog {
  final String id;
  final String userId;
  final String? routineId;
  final String routineName;
  final DateTime completedAt;
  final int durationSeconds;
  final double totalVolume;
  final int totalSets;
  final List<Map<String, dynamic>> loggedExercises; // [{exercise_name, sets: [{weight, reps, completed}]}]

  WorkoutLog({
    required this.id,
    required this.userId,
    this.routineId,
    required this.routineName,
    required this.completedAt,
    required this.durationSeconds,
    required this.totalVolume,
    required this.totalSets,
    required this.loggedExercises,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> exercisesList = [];
    if (json['logged_exercises'] != null) {
      if (json['logged_exercises'] is List) {
        exercisesList = List<Map<String, dynamic>>.from(
          (json['logged_exercises'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
    }

    return WorkoutLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      routineId: json['routine_id']?.toString(),
      routineName: json['routine_name'] ?? 'Entrenamiento',
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : DateTime.now(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      totalVolume: (json['total_volume'] as num?)?.toDouble() ?? 0.0,
      totalSets: (json['total_sets'] as num?)?.toInt() ?? 0,
      loggedExercises: exercisesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'routine_id': routineId,
      'routine_name': routineName,
      'completed_at': completedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'total_volume': totalVolume,
      'total_sets': totalSets,
      'logged_exercises': loggedExercises,
    };
  }
}
