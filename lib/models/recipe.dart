class Recipe {
  final String id;
  final String title;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String time;
  final String difficulty;
  final String? imageUrl;
  final List<String> ingredients;
  final List<String> steps;
  final DateTime createdAt;
  final String idEmpresa;

  Recipe({
    required this.id,
    required this.title,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.time,
    required this.difficulty,
    this.imageUrl,
    required this.ingredients,
    required this.steps,
    required this.createdAt,
    this.idEmpresa = '',
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Sin título',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      time: json['time'] ?? '15 min',
      difficulty: json['difficulty'] ?? 'Fácil',
      imageUrl: json['image_url'],
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      idEmpresa: json['IDEmpresa']?.toString() ?? json['idEmpresa']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'time': time,
      'difficulty': difficulty,
      'image_url': imageUrl,
      'ingredients': ingredients,
      'steps': steps,
      'IDEmpresa': idEmpresa,
    };
  }
}
