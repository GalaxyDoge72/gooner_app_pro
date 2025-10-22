class KemonoPost {
  final String id;
  final String title;
  final String published;
  final List<KemonoAttachment> attachments;
  final String? content;
  final String service;
  
  KemonoPost({
    required this.id,
    required this.title,
    required this.published,
    required this.attachments,
    required this.service,
    this.content,
  });

  factory KemonoPost.fromJson(Map<String, dynamic> json) {
    return KemonoPost(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      published: json['published'] ?? '',
      service: json['service'] ?? '',
      content: json['content'],
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => KemonoAttachment.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'published': published,
    'service': service,
    'content': content,
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };
}

class KemonoAttachment {
  final String name;
  final String path;
  final bool sharedFile;
  
  KemonoAttachment({
    required this.name,
    required this.path,
    required this.sharedFile,
  });

  factory KemonoAttachment.fromJson(Map<String, dynamic> json) {
    return KemonoAttachment(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      sharedFile: json['shared_file'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'shared_file': sharedFile,
  };
}
