class ClientAiChat {
  final String id;
  final String clientId;
  final String coachId;
  final String question;
  final String answer;
  final DateTime createdAt;

  ClientAiChat({
    required this.id,
    required this.clientId,
    required this.coachId,
    required this.question,
    required this.answer,
    required this.createdAt,
  });

  factory ClientAiChat.fromJson(Map<String, dynamic> json) {
    return ClientAiChat(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      coachId: json['coach_id']?.toString() ?? '',
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'coach_id': coachId,
      'question': question,
      'answer': answer,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
