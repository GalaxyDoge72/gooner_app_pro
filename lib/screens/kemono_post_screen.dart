import 'dart:convert';
import 'dart:developer'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Helper Models (Unchanged) ---
class FileAttachment {
  final String name;
  final String path;
  final String fullUrl;

  FileAttachment({required this.name, required this.path, required this.fullUrl});
}

class KemonoPostDetails {
  final String id;
  final String title;
  final String published;
  final String content;
  final List<FileAttachment> attachments;
  final FileAttachment? mainFile;

  KemonoPostDetails({
    required this.id,
    required this.title,
    required this.published,
    required this.content,
    this.attachments = const [],
    this.mainFile,
  });

  // This factory method correctly parses the structure of the *nested* post object.
  factory KemonoPostDetails.fromJson(Map<String, dynamic> json, String apiBaseUrl) {
    // 1. Parse main file
    final mainFileJson = json['file'];
    FileAttachment? mainFile;
    if (mainFileJson != null && mainFileJson['path'] != null) {
      mainFile = FileAttachment(
        name: mainFileJson['name'] ?? 'Main File',
        path: mainFileJson['path'],
        fullUrl: apiBaseUrl + mainFileJson['path'],
      );
    }

    // 2. Parse attachments list
    final List<dynamic> attachmentList = json['attachments'] ?? [];
    final List<FileAttachment> attachments = attachmentList.map((att) {
      return FileAttachment(
        name: att['name'] ?? 'Attachment',
        path: att['path'] ?? '',
        fullUrl: att['path'] != null ? apiBaseUrl + att['path'] : '',
      );
    }).toList();

    return KemonoPostDetails(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled Post',
      published: json['published'] ?? 'Unknown Date',
      content: json['content'] ?? 'No content provided.',
      attachments: attachments,
      mainFile: mainFile,
    );
  }
}


// --- Post Detail Screen ---

class KemonoPostScreen extends StatefulWidget {
  final String postId;
  final String creatorId;
  final String service;
  
  final String apiBaseUrl = 'https://kemono.cr';
  final String apiVersionPath = '/api/v1';

  const KemonoPostScreen({
    super.key,
    required this.postId,
    required this.creatorId,
    required this.service,
  });

  @override
  State<KemonoPostScreen> createState() => _KemonoPostScreenState();
}

class _KemonoPostScreenState extends State<KemonoPostScreen> {
  KemonoPostDetails? _postDetails;
  bool _isLoading = true;
  String? _error;
  final http.Client _httpClient = http.Client();

  @override
  void initState() {
    super.initState();
    _fetchPostDetails();
  }
  
  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }


  Future<void> _fetchPostDetails() async {
    final String service = widget.service;
    final String creatorId = widget.creatorId;
    final String postId = widget.postId;

    final String path = '${widget.apiVersionPath}/$service/user/$creatorId/post/$postId';
    
    final Uri uri = Uri.https(
      widget.apiBaseUrl.replaceAll('https://', ''), 
      path, 
    );
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      log("KemonoPostScreen FETCHING URL: $uri");
      
      final response = await _httpClient.get(
        uri,
        headers: {'Accept': 'text/css'}, 
      );

      log("KemonoPostScreen Response Status: ${response.statusCode}");


      if (response.statusCode == 200) {
        final Map<String, dynamic> rawJsonResponse = jsonDecode(response.body);
        
        // ⭐ FIX: Extract the nested "post" object from the root JSON
        final Map<String, dynamic>? postJson = rawJsonResponse['post'];
        
        if (postJson == null) {
           log('KemonoPostScreen PARSING ERROR: "post" key not found in response.');
           setState(() {
              _error = 'Failed to parse post details: missing "post" object.';
              _isLoading = false;
           });
           return;
        }

        log("KemonoPostScreen SUCCESS: Parsed post details for '${postJson['title']}'");
        
        setState(() {
          // Pass the NECESSARY nested object to the parser
          _postDetails = KemonoPostDetails.fromJson(postJson, widget.apiBaseUrl); 
          _isLoading = false;
        });
      } else {
        log('KemonoPostScreen API ERROR: Status ${response.statusCode}, Body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...');
        setState(() {
          _error = 'Failed to load post. HTTP ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      log('KemonoPostScreen CATCH ERROR: $e\n$stack');
      setState(() {
        _error = 'A network error occurred: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file URL: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_postDetails?.title ?? 'Post Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Title & Metadata ---
                      Text(
                        _postDetails!.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Published: ${_postDetails!.published}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(),

                      // --- Main Content (HTML) ---
                      Text(
                        'Content:',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      // The content often contains line breaks (\n\n) but not always HTML tags. 
                      // HtmlWidget handles both basic text and potential HTML elements.
                      HtmlWidget(
                        _postDetails!.content,
                        onTapUrl: (url) async {
                          _launchUrl(url);
                          return true;
                        },
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Divider(),

                      // --- Main File ---
                      if (_postDetails!.mainFile != null) ...[
                        Text(
                          'Main File:',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(Icons.download),
                          title: Text(_postDetails!.mainFile!.name),
                          subtitle: const Text('Tap to open in browser'),
                          onTap: () => _launchUrl(_postDetails!.mainFile!.fullUrl),
                        ),
                        const Divider(),
                      ],

                      // --- Attachments ---
                      if (_postDetails!.attachments.isNotEmpty) ...[
                        Text(
                          'Attachments (${_postDetails!.attachments.length}):',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ..._postDetails!.attachments.map((file) => ListTile(
                              leading: const Icon(Icons.attach_file),
                              title: Text(file.name),
                              subtitle: const Text('Tap to open in browser'),
                              onTap: () => _launchUrl(file.fullUrl),
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }
}