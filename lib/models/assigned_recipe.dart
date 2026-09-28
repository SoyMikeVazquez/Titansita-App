import 'recipe.dart';

class AssignedRecipe {
  final String id;
  final String userId;
  final String recipeId;
  final DateTime assignedDate;
  final DateTime createdAt;
  final Recipe? recipe;

  final String? notes;

  AssignedRecipe({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.assignedDate,
    required this.createdAt,
    this.recipe,
    this.notes,
  });

  factory AssignedRecipe.fromJson(Map<String, dynamic> json, {Recipe? recipe}) {
    return AssignedRecipe(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      recipeId: json['recipe_id']?.toString() ?? '',
      assignedDate: json['assigned_date'] != null
          ? DateTime.parse(json['assigned_date'])
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      recipe: recipe ?? (json['recipes'] != null ? Recipe.fromJson(json['recipes']) : null),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'recipe_id': recipeId,
      'assigned_date': '${assignedDate.year}-${assignedDate.month.toString().padLeft(2, '0')}-${assignedDate.day.toString().padLeft(2, '0')}',
      'notes': notes,
    };
  }
}
