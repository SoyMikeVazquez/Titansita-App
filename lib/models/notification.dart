class Notification {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String type; // 'payment', 'event', 'community', 'achievement', 'reminder'
  final DateTime createdAt;
  final DateTime? actionDate;
  final String? actionUrl;
  final bool isRead;
  final String? authorName;
  final String? metadata; // JSON string for additional data

  Notification({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.type,
    required this.createdAt,
    this.actionDate,
    this.actionUrl,
    this.isRead = false,
    this.authorName,
    this.metadata,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      type: json['type'] ?? 'reminder',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      actionDate: json['action_date'] != null
          ? DateTime.parse(json['action_date'] as String)
          : null,
      actionUrl: json['action_url'],
      isRead: json['is_read'] ?? false,
      authorName: json['author_name'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'action_date': actionDate?.toIso8601String(),
      'action_url': actionUrl,
      'is_read': isRead,
      'author_name': authorName,
      'metadata': metadata,
    };
  }

  String getEmoji() {
    return '';
  }

  String getTypeLabel() {
    switch (type) {
      case 'payment':
        return 'Pago';
      case 'event':
        return 'Evento';
      case 'community':
        return 'Comunidad';
      case 'achievement':
        return 'Logro';
      case 'reminder':
        return 'Recordatorio';
      default:
        return 'Notificación';
    }
  }
}
