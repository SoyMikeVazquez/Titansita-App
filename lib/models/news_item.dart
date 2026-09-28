class NewsItem {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final String authorName;
  final DateTime createdAt;
  final String? idEmpresa;

  NewsItem({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.authorName,
    required this.createdAt,
    this.idEmpresa,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
      authorName: json['author_name'] ?? 'Entrenador',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      idEmpresa: json['IDEmpresa']?.toString(),
    );
  }
}
