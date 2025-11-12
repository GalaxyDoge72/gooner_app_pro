// lib/models/file_attachment.dart

class FileAttachment {
  final String name;
  final String path;
  final String fullUrl;

  FileAttachment({
    required this.name, 
    required this.path, 
    required this.fullUrl,
  });
}