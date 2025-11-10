class KemonoTag {
  final String tag;
  final int postCount;

  KemonoTag({required this.tag, required this.postCount});

  factory KemonoTag.fromJson(Map<String, dynamic> json) {
    return KemonoTag(
      tag: json['tag'] as String,
      postCount: json['post_count'] as int
    );
  }
}