import 'routine_exercise.dart';

class AssignedRoutine {
  final String id;
  final String userId;
  final String routineId;
  final DateTime assignedDate;
  final DateTime createdAt;
  final List<RoutineExercise> customExercises;
  final String? idEmpresa;
  final String routineName;

  AssignedRoutine({
    required this.id,
    required this.userId,
    required this.routineId,
    required this.assignedDate,
    required this.createdAt,
    this.customExercises = const [],
    this.idEmpresa,
    required this.routineName,
  });

  factory AssignedRoutine.fromJson(Map<String, dynamic> json, {String? templateName}) {
    List<RoutineExercise> customExs = [];
    if (json['custom_exercises'] != null && json['custom_exercises'] is List) {
      customExs = (json['custom_exercises'] as List)
          .map((e) => RoutineExercise.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Handle nested routines relation if populated by supabase select
    String name = templateName ?? '';
    if (json['rutinas'] != null && json['rutinas'] is Map) {
      name = json['rutinas']['name']?.toString() ?? '';
    }

    return AssignedRoutine(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      routineId: json['routine_id']?.toString() ?? '',
      assignedDate: json['assigned_date'] != null
          ? DateTime.parse(json['assigned_date'])
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      customExercises: customExs,
      idEmpresa: (json['idempresa'] ?? json['IDEmpresa'])?.toString(),
      routineName: name.isNotEmpty ? name : 'Rutina',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'routine_id': routineId,
      'assigned_date': '${assignedDate.year}-${assignedDate.month.toString().padLeft(2, '0')}-${assignedDate.day.toString().padLeft(2, '0')}',
      'created_at': createdAt.toIso8601String(),
      'custom_exercises': customExercises.map((e) => e.toJson()).toList(),
      'idempresa': idEmpresa,
    };
  }
}
