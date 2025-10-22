import 'dart:convert';

class Comment {
  final String id;
  final String? creator;
  final String body;
  final DateTime createdAt;

  Comment({
    required this.id,
    this.creator,
    required this.body,
    required this.createdAt,
  });

  String get postedTime {
    // Formats as "dd/MM/yyyy HH:mm"
    final local = createdAt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
           '${local.month.toString().padLeft(2, '0')}/'
           '${local.year} ${local.hour.toString().padLeft(2, '0')}:'
           '${local.minute.toString().padLeft(2, '0')}';
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'].toString(),
      creator: json['creator'],
      body: json['body'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creator': creator,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };

  /// Strips Danbooru/BBCode-style markup for display
  String get cleanBody {
    var text = body
        .replaceAll(RegExp(r'\[expand\].*?\[\/expand\]', dotAll: true), '')
        .replaceAll(RegExp(r'\[table\].*?\[\/table\]', dotAll: true), '')
        .replaceAll(RegExp(r'\[\/?(tn|b|i|u|url)[^\]]*\]', caseSensitive: false), '');
    return text.trim();
  }

  static List<Comment> listFromJson(String jsonStr) {
    final data = json.decode(jsonStr);
    return List<Comment>.from(data.map((x) => Comment.fromJson(x)));
  }
}
