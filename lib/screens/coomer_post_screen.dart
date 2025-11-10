import 'dart:convert';
import 'dart:developer'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

// Assuming R34Post and ImageScreen are available via relative imports
import '../models/r34_post.dart'; 
import 'image_screen.dart'; 

// --- Helper Models ---

class FileAttachment {
  final String name;
  final String path;
  final String fullUrl;

  FileAttachment({required this.name, required this.path, required this.fullUrl});
}

class coomerPostDetails {
  final String id;
  final String title;
  final String published;
  final String content;
  final List<FileAttachment> attachments;
  final FileAttachment? mainFile;

  coomerPostDetails({
    required this.id,
    required this.title,
    required this.published,
    required this.content,
    this.attachments = const [],
    this.mainFile,
  });

  factory coomerPostDetails.fromJson(Map<String, dynamic> json, String apiBaseUrl) {
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

    return coomerPostDetails(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled Post',
      published: json['published'] ?? 'Unknown Date',
      content: json['content'] ?? 'No content provided.',
      attachments: attachments,
      mainFile: mainFile,
    );
  }
}


// --- Post Detail Screen with Tabs ---

class CoomerPostScreen extends StatefulWidget {
  final String postId;
  final String creatorId;
  final String service;
  
  final String apiBaseUrl = 'https://coomer.st';
  final String apiVersionPath = '/api/v1';

  const CoomerPostScreen({
    super.key,
    required this.postId,
    required this.creatorId,
    required this.service,
  });

  @override
  State<CoomerPostScreen> createState() => _CoomerPostScreenState();
}

class _CoomerPostScreenState extends State<CoomerPostScreen> with SingleTickerProviderStateMixin {
  coomerPostDetails? _postDetails;
  bool _isLoading = true;
  String? _error;
  final http.Client _httpClient = http.Client();
  late TabController _tabController; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); 
    _fetchPostDetails();
  }
  
  @override
  void dispose() {
    _httpClient.close();
    _tabController.dispose(); 
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
      log("CoomerPostScreen FETCHING URL: $uri");
      
      final response = await _httpClient.get(
        uri,
        headers: {'Accept': 'text/css'}, 
      );

      log("CoomerPostScreen Response Status: ${response.statusCode}");


      if (response.statusCode == 200) {
        final Map<String, dynamic> rawJsonResponse = jsonDecode(response.body);
        
        // FIX: Extract the nested "post" object from the root JSON
        final Map<String, dynamic>? postJson = rawJsonResponse['post'];
        
        if (postJson == null) {
           log('CoomerPostScreen PARSING ERROR: "post" key not found in response.');
           setState(() {
              _error = 'Failed to parse post details: missing "post" object.';
              _isLoading = false;
           });
           return;
        }

        log("CoomerPostScreen SUCCESS: Parsed post details for '${postJson['title']}'");
        
        setState(() {
          _postDetails = coomerPostDetails.fromJson(postJson, widget.apiBaseUrl); 
          _isLoading = false;
        });
      } else {
        log('CoomerPostScreen API ERROR: Status ${response.statusCode}, Body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...');
        setState(() {
          _error = 'Failed to load post. HTTP ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      log('CoomerPostScreen CATCH ERROR: $e\n$stack');
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
  
  // NEW: Media tap handler
  void _onMediaTapped(BuildContext context, FileAttachment attachment) {
    final fakePost = R34Post(
      id: widget.postId, // Use the main post ID
      fileUrl: attachment.fullUrl,
      previewUrl: attachment.fullUrl, 
      tagsString: 'Attachment: ${attachment.name} (${widget.service} Post ${widget.postId})',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageScreen(
          post: fakePost,
          source: 'Kemono.cr Media', 
        ),
      ),
    );
  }

  // NEW: Content Tab Widget
  Widget _buildContentTab() {
    if (_postDetails == null) return const Center(child: Text('No content available.'));
    
    return SingleChildScrollView(
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
          HtmlWidget(
            _postDetails!.content,
            onTapUrl: (url) async {
              _launchUrl(url);
              return true;
            },
            textStyle: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ... (rest of CoomerPostScreenState remains the same)

  // NEW: Media Tab Widget
  Widget _buildMediaTab() {
    if (_postDetails == null) return const Center(child: Text('No media available.'));
    
    final allFiles = [
      if (_postDetails!.mainFile != null) _postDetails!.mainFile!,
      ..._postDetails!.attachments,
    ];

    if (allFiles.isEmpty) return const Center(child: Text('No files or attachments found for this post.'));

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: allFiles.map((file) {
        // Simple check to determine if it's likely an image or video
        final isMedia = file.fullUrl.toLowerCase().contains(RegExp(r'\.(jpe?g|png|gif|mp4|webm|mov)'));
        final isMainFile = file == _postDetails!.mainFile;
        
        return ListTile(
  leading: SizedBox(
    width: 50,
    height: 50,
    child: Center( // Use Center to ensure the icon is vertically and horizontally centered in the 50x50 box
      child: isMedia 
          ? const Icon(
              Icons.image, // Icon used if it's a media post (image/video)
              size: 32, 
              color: Colors.blueGrey,
            )
          : const Icon(
              Icons.attach_file, // Icon used if it's a generic file attachment
              size: 28, 
              color: Colors.grey,
            ),
    ),
  ),
          
          title: Text(file.name),
          subtitle: Text(isMainFile ? 'Main File (Tap to view media)' : 'Attachment (Tap to view media)'),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _launchUrl(file.fullUrl), // Open original URL in browser
          ),
          onTap: () => _onMediaTapped(context, file), // Open in ImageScreen
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_postDetails?.title ?? 'Post Details'),
        bottom: TabBar( 
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.article), text: 'Content'),
            Tab(icon: Icon(Icons.perm_media), text: 'Media'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView( 
                  controller: _tabController,
                  children: [
                    _buildContentTab(), 
                    _buildMediaTab(),  
                  ],
                ),
    );
  }
}