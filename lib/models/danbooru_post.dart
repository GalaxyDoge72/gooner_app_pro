import 'tags_object.dart';

class DanbooruPost {
  final int id;
  final String? previewUrl;
  final String? fileUrl;
  final String? largeFileUrl;
  final String? fileExtension;
  final String? tagStringGeneral;
  final String? tagStringArtist;
  final String? tagStringCharacter;
  final String? tagStringCopyright;

  bool isNullOrInvalidEntry;
  String? authUserId;
  String? authApiKey;
  TagsObject? tags;

  DanbooruPost({
    required this.id,
    this.previewUrl,
    this.fileUrl,
    this.largeFileUrl,
    this.fileExtension,
    this.tagStringGeneral,
    this.tagStringArtist,
    this.tagStringCharacter,
    this.tagStringCopyright,
    this.isNullOrInvalidEntry = false,
    this.authUserId,
    this.authApiKey,
    this.tags,
  });

  factory DanbooruPost.fromJson(Map<String, dynamic> json) {
    return DanbooruPost(
      id: json['id'],
      previewUrl: json['preview_file_url'],
      fileUrl: json['file_url'],
      largeFileUrl: json['large_file_url'],
      fileExtension: json['file_ext'],
      tagStringGeneral: json['tag_string_general'],
      tagStringArtist: json['tag_string_artist'],
      tagStringCharacter: json['tag_string_character'],
      tagStringCopyright: json['tag_string_copyright'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'preview_file_url': previewUrl,
        'file_url': fileUrl,
        'large_file_url': largeFileUrl,
        'file_ext': fileExtension,
        'tag_string_general': tagStringGeneral,
        'tag_string_artist': tagStringArtist,
        'tag_string_character': tagStringCharacter,
        'tag_string_copyright': tagStringCopyright,
      };

  bool get isWebmVideo =>
      fileExtension?.toLowerCase() == 'webm';

  bool get isVideo =>
      fileExtension?.toLowerCase() == 'mp4';

  bool get isAnyVideo => isVideo || isWebmVideo;

  String? get highResImageUrl =>
      (largeFileUrl?.isNotEmpty ?? false) ? largeFileUrl : fileUrl;
}
