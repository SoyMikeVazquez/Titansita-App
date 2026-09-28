class CommunityPost {
  final String id;
  final String imageUrl;
  final String title;
  final String description;
  final String userId;
  final int views;
  final int likes;
  final DateTime createdAt;

  CommunityPost({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.userId,
    required this.views,
    required this.likes,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      userId: json['id_user']?.toString() ?? '',
      views: json['visualizaciones'] ?? 0,
      likes: json['likes'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
