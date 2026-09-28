class UserProfile {
  final String userID;
  final String email;
  final String name;
  final double currentWeight;
  final double targetWeight;
  final double initialWeight;
  final double height;
  final int age;
  final bool isAdmin;
  final DateTime updatedAt;
  final DateTime? nextPaymentDate;
  final List<Map<String, dynamic>> questionnaireAnswers;
  final String? avatarUrl;
  final String? idEmpresa;
  final bool isSuperAdmin;

  UserProfile({
    required this.userID,
    required this.email,
    required this.name,
    required this.currentWeight,
    required this.targetWeight,
    required this.initialWeight,
    required this.height,
    required this.age,
    required this.isAdmin,
    required this.updatedAt,
    this.nextPaymentDate,
    this.questionnaireAnswers = const [],
    this.avatarUrl,
    this.idEmpresa,
    this.isSuperAdmin = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userID: json['userID']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? 'Usuario',
      currentWeight: (json['weight'] as num?)?.toDouble() ?? 70.0,
      targetWeight: (json['target_weight'] as num?)?.toDouble() ?? 65.0,
      initialWeight: (json['initial_weight'] as num?)?.toDouble() ?? 75.0,
      height: (json['height'] as num?)?.toDouble() ?? 170.0,
      age: (json['age'] as num?)?.toInt() ?? 25,
      isAdmin: json['is_admin'] ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      nextPaymentDate: json['next_payment_date'] != null
          ? DateTime.parse(json['next_payment_date'])
          : null,
      questionnaireAnswers: json['questionnaire_answers'] != null
          ? List<Map<String, dynamic>>.from(
              (json['questionnaire_answers'] as List).map((e) => Map<String, dynamic>.from(e)),
            )
          : [],
      avatarUrl: json['avatar_url'],
      idEmpresa: json['IDEmpresa']?.toString(),
      isSuperAdmin: json['superAdmin'] == true,
    );
  }

  double get progressPercentage {
    final totalDelta = (initialWeight - targetWeight).abs();
    if (totalDelta == 0) return 0.0;
    final completedDelta = (initialWeight - currentWeight).abs();
    return (completedDelta / totalDelta).clamp(0.0, 1.0);
  }
}
