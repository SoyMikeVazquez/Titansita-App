class MeasurementRecord {
  final String id;
  final String userId;
  final DateTime createdAt;
  final String? photoUrl;
  final double weight;
  final double abdomen;
  final double waist;
  final double leg;
  final double chest;
  final double arm;
  final double calf;
  final double cuello;

  MeasurementRecord({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.photoUrl,
    required this.weight,
    required this.abdomen,
    required this.waist,
    required this.leg,
    required this.chest,
    required this.arm,
    required this.calf,
    required this.cuello,
  });

  factory MeasurementRecord.fromJson(Map<String, dynamic> json) {
    return MeasurementRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      photoUrl: json['photo_url'],
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      abdomen: (json['abdomen'] as num?)?.toDouble() ?? 0.0,
      waist: (json['waist'] as num?)?.toDouble() ?? 0.0,
      leg: (json['leg'] as num?)?.toDouble() ?? 0.0,
      chest: (json['chest'] as num?)?.toDouble() ?? 0.0,
      arm: (json['arm'] as num?)?.toDouble() ?? 0.0,
      calf: (json['calf'] as num?)?.toDouble() ?? 0.0,
      cuello: (json['cuello'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'photo_url': photoUrl,
      'weight': weight,
      'abdomen': abdomen,
      'waist': waist,
      'leg': leg,
      'chest': chest,
      'arm': arm,
      'calf': calf,
      'cuello': cuello,
    };
  }

  /// Helper to get double value of a specific measurement by name
  double getValueByName(String name) {
    switch (name.toLowerCase()) {
      case 'peso':
        return weight;
      case 'abdomen':
        return abdomen;
      case 'cintura':
        return waist;
      case 'pierna':
        return leg;
      case 'pecho':
        return chest;
      case 'brazo':
      case 'bicep':
        return arm;
      case 'pantorrilla':
        return calf;
      case 'cuello':
        return cuello;
      default:
        return 0.0;
    }
  }
}
