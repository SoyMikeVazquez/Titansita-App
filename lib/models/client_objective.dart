class ClientObjective {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final bool completed;
  final DateTime createdAt;
  final String? idEmpresa;

  ClientObjective({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.completed,
    required this.createdAt,
    this.idEmpresa,
  });

  factory ClientObjective.fromJson(Map<String, dynamic> json) {
    return ClientObjective(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      completed: json['completed'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      idEmpresa: json['IDEmpresa']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'completed': completed,
      'created_at': createdAt.toIso8601String(),
      'IDEmpresa': idEmpresa,
    };
  }

  ClientObjective copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    bool? completed,
    DateTime? createdAt,
    String? idEmpresa,
  }) {
    return ClientObjective(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      idEmpresa: idEmpresa ?? this.idEmpresa,
    );
  }
}
