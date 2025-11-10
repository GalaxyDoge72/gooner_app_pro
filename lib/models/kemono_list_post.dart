// kemono_list_post.dart

class KemonoListPost {
  final String id;
  final String userId;
  final String service;
  final String title;
  final String? previewPath;
  final String fullUrl; // Full URL of the image/preview

  KemonoListPost({
    required this.id,
    required this.userId,
    required this.service,
    required this.title,
    this.previewPath,
    required this.fullUrl,
  });

  factory KemonoListPost.fromJson(Map<String, dynamic> json, String apiBaseUrl) {
    String? path;
    if (json['file'] != null && json['file']['path'] != null) {
      path = json['file']['path'];
    } else if (json['attachments'] != null && json['attachments'].isNotEmpty) {
      // Fallback to the first attachment if main 'file' is missing
      path = json['attachments'][0]['path'];
    }

    // Kemono uses a relative path, so we prepend the base URL to create a full URL.
    final fullUrl = (path != null && path.isNotEmpty) ? (apiBaseUrl + path) : '';

    return KemonoListPost(
      id: json['id'].toString(),
      userId: json['user'].toString(),
      service: json['service'] ?? 'unknown',
      title: json['title'] ?? 'Untitled Post',
      previewPath: path,
      fullUrl: fullUrl,
    );
  }
}