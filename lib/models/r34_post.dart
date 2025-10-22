import 'tags_object.dart';

class R34Post {
  final String id;
  final String? previewUrl;
  final String? fileUrl;
  final String? tagsString;

  String? authUserId;
  String? authApiKey;
  TagsObject? tags;

  R34Post({
    required this.id,
    this.previewUrl,
    this.fileUrl,
    this.tagsString,
    this.authUserId,
    this.authApiKey,
    this.tags,
  });

  factory R34Post.fromJson(Map<String, dynamic> json) {
    return R34Post(
      id: json['id'].toString(),
      previewUrl: json['preview_url'],
      fileUrl: json['file_url'],
      tagsString: json['tags'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'preview_url': previewUrl,
        'file_url': fileUrl,
        'tags': tagsString,
      };

  bool get isVideo =>
      fileUrl?.toLowerCase().endsWith('.mp4') ?? false;

  bool get isWebmVideo =>
      fileUrl?.toLowerCase().endsWith('.webm') ?? false;

  bool get isAnyVideo => isVideo || isWebmVideo;

  /// Splits the space-separated tag string into a list
  List<String> get parsedTags {
    if (tagsString == null || tagsString!.isEmpty) return [];
    return tagsString!.split(' ').where((t) => t.isNotEmpty).toList();
  }
}
