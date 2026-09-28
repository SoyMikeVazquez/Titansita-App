import 'routine_exercise.dart';

class Routine {
  final String id;
  final String userId;
  final String name;
  final DateTime? assignedDate;
  final DateTime createdAt;
  final List<RoutineExercise> exercises;
  final String? shareCode;
  final String? idEmpresa;

  Routine({
    required this.id,
    required this.userId,
    required this.name,
    this.assignedDate,
    required this.createdAt,
    this.exercises = const [],
    this.shareCode,
    this.idEmpresa,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    List<RoutineExercise> exercisesList = [];
    if (json['rutina_ejercicios'] != null) {
      if (json['rutina_ejercicios'] is List) {
        exercisesList = (json['rutina_ejercicios'] as List)
            .map((ex) => RoutineExercise.fromJson(ex))
            .toList();
      }
    }

    return Routine(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name'] ?? '',
      assignedDate: json['assigned_date'] != null
          ? DateTime.parse(json['assigned_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      exercises: exercisesList,
      shareCode: json['share_code']?.toString(),
      idEmpresa: json['IDEmpresa']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'assigned_date': assignedDate?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'share_code': shareCode,
      'IDEmpresa': idEmpresa,
    };
  }
}
