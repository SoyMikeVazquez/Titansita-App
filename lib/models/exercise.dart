class Exercise {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String? category;
  final DateTime createdAt;

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.category,
    required this.createdAt,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      category: json['categoria'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'categoria': category,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
