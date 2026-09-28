class EstablishedExercise {
  final String id;
  final String userId;
  final String name;
  final int sets;
  final int reps;
  final double weight;
  final String dayOfWeek;
  final DateTime createdAt;
  bool isCompleted;

  EstablishedExercise({
    required this.id,
    required this.userId,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.dayOfWeek,
    required this.createdAt,
    this.isCompleted = false,
  });

  factory EstablishedExercise.fromJson(Map<String, dynamic> json) {
    return EstablishedExercise(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name'] ?? '',
      sets: (json['sets'] as num?)?.toInt() ?? 3,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      dayOfWeek: json['day_of_week'] ?? 'Lunes',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
}
