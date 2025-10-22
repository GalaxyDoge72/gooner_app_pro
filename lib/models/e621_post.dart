import 'post_url.dart';
import 'tags_object.dart';

class E621Post {
  final String id;
  final PostUrl? preview;
  final PostUrl? file;
  final TagsObject? tags;

  bool isInvalidOrNullEntry;

  E621Post({
    required this.id,
    this.preview,
    this.file,
    this.tags,
    this.isInvalidOrNullEntry = false,
  });

  factory E621Post.fromJson(Map<String, dynamic> json) {
    return E621Post(
      id: json['id'].toString(),
      preview: json['preview'] != null
          ? PostUrl.fromJson(json['preview'])
          : null,
      file: json['file'] != null
          ? PostUrl.fromJson(json['file'])
          : null,
      tags: json['tags'] != null
          ? TagsObject.fromJson(json['tags'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'preview': preview?.toJson(),
        'file': file?.toJson(),
        'tags': tags?.toJson(),
      };

  String? get previewUrl => preview?.url;
  String? get fileUrl => file?.url;

  bool get isWebmVideo =>
      fileUrl?.toLowerCase().endsWith('.webm') ?? false;

  bool get isVideo =>
      fileUrl?.toLowerCase().endsWith('.mp4') ?? false;

  bool get isAnyVideo => isVideo || isWebmVideo;
}
