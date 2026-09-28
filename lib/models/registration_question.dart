class RegistrationQuestion {
  final String id;
  final String questionText;
  final bool isRequired;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final String? createdBy;
  final String? idEmpresa;

  RegistrationQuestion({
    required this.id,
    required this.questionText,
    required this.isRequired,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    this.createdBy,
    this.idEmpresa,
  });

  factory RegistrationQuestion.fromJson(Map<String, dynamic> json) {
    return RegistrationQuestion(
      id: json['id']?.toString() ?? '',
      questionText: json['question_text'] ?? '',
      isRequired: json['is_required'] ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      createdBy: json['created_by']?.toString(),
      idEmpresa: json['IDEmpresa']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_text': questionText,
      'is_required': isRequired,
      'sort_order': sortOrder,
      'is_active': isActive,
      'IDEmpresa': idEmpresa,
    };
  }
}
