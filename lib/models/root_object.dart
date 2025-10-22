import 'e621_post.dart';

class RootObject {
  final List<E621Post> posts;

  RootObject({required this.posts});

  factory RootObject.fromJson(Map<String, dynamic> json) {
    final posts = (json['posts'] as List<dynamic>?)
            ?.map((p) => E621Post.fromJson(p))
            .toList() ??
        [];
    return RootObject(posts: posts);
  }

  Map<String, dynamic> toJson() => {
        'posts': posts.map((p) => p.toJson()).toList(),
      };
}
