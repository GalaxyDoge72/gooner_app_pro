
class PostUrl {
  final String url;

  PostUrl({required this.url});

  factory PostUrl.fromJson(Map<String, dynamic> json) {
    return PostUrl(
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
      };
}
