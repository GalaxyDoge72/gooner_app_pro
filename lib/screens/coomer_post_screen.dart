import 'dart:convert';
import 'dart:developer'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

// Assuming R34Post and ImageScreen are available via relative imports
import '../models/r34_post.dart'; 
import 'image_screen.dart'; 

// Import for the download service
import 'package:gooner_app_pro/services/download_service.dart';
// Import for the new audio screen
import 'audio_screen.dart'; 

// ⭐ NEW: Import the central FileAttachment model
import '../models/file_attachment.dart';

// --- Helper Models ---

// ⭐ DELETED: The local FileAttachment class definition was removed from here.

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

  // State variables for download management
  bool _isDownloadingMedia = false;
  double _downloadProgress = 0.0;
  String _downloadSpeed = "Starting...";

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

  Future<void> _downloadFile(FileAttachment file, GlobalKey buttonKey) async {
    if (_isDownloadingMedia) return; 

    const String source = 'Coomer.st'; 

    await DownloadService.downloadAndShareFile(
      fileUrl: file.fullUrl,
      source: source, 
      userId: null,
      apiKey: null,
      context: context,
      buttonKey: buttonKey,
      onStart: () {
        setState(() {
          _isDownloadingMedia = true;
          _downloadProgress = 0;
          _downloadSpeed = "Starting...";
        });
      },
      onProgress: (progress, speed) {
        setState(() {
          _downloadProgress = progress;
          _downloadSpeed = speed;
        });
      },
      onComplete: (success, message) {
        setState(() => _isDownloadingMedia = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    );
  }
  
  // Media tap handler for Images/Videos (goes to ImageScreen)
  void _onMediaTapped(BuildContext context, FileAttachment attachment) {
    final fakePost = R34Post(
      id: widget.postId,
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

  // Media tap handler for Audio (goes to AudioScreen)
  void _onAudioTapped(BuildContext context, FileAttachment attachment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioScreen(
          attachment: attachment,
        ),
      ),
    );
  }

  // Content Tab Widget
  Widget _buildContentTab() {
    if (_postDetails == null) return const Center(child: Text('No content available.'));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  // Media Tab Widget
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
        final String lowerUrl = file.fullUrl.toLowerCase();
        
        final bool isVideo = lowerUrl.contains(RegExp(r'\.(mp4|webm|mov|mkv)$'));
        final bool isImage = lowerUrl.contains(RegExp(r'\.(jpe?g|png|gif|webp)$'));
        final bool isAudio = lowerUrl.contains(RegExp(r'\.(mp3|wav|ogg|m4a|flac)$'));
        
        final bool isMainFile = file == _postDetails!.mainFile;
        final GlobalKey buttonKey = GlobalKey();

        IconData fileIcon;
        Color fileIconColor = Colors.blueGrey;
        if (isImage) {
          fileIcon = Icons.image;
        } else if (isVideo) {
          fileIcon = Icons.videocam;
        } else if (isAudio) {
          fileIcon = Icons.audiotrack;
          fileIconColor = Colors.deepPurple;
        } else {
          fileIcon = Icons.attach_file;
          fileIconColor = Colors.grey;
        }

        String subtitle;
        if (isAudio) {
          subtitle = isMainFile ? 'Main File (Tap to play audio)' : 'Attachment (Tap to play audio)';
        } else if (isImage || isVideo) {
          subtitle = isMainFile ? 'Main File (Tap to view media)' : 'Attachment (Tap to view media)';
        } else {
          subtitle = isMainFile ? 'Main File (Tap to open)' : 'Attachment (Tap to open)';
        }
        
        return ListTile(
          leading: SizedBox(
            width: 50,
            height: 50,
            child: Center(
              child: Icon(
                fileIcon,
                size: 32, 
                color: fileIconColor,
              ),
            ),
          ),
          
          title: Text(file.name),
          subtitle: Text(subtitle),
          
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: buttonKey,
                icon: const Icon(Icons.download),
                tooltip: 'Download',
                onPressed: _isDownloadingMedia ? null : () => _downloadFile(file, buttonKey), 
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Open in browser',
                onPressed: () => _launchUrl(file.fullUrl),
              ),
            ],
          ),
          
          onTap: () {
            if (isImage || isVideo) {
              _onMediaTapped(context, file); // Open in ImageScreen
            } else if (isAudio) {
              _onAudioTapped(context, file); // Open in AudioScreen
            } else {
              _launchUrl(file.fullUrl); // Fallback for other files
            }
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    if (_isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      bodyContent = Center(child: Text(_error!));
    } else {
      bodyContent = TabBarView( 
        controller: _tabController,
        children: [
          _buildContentTab(), 
          _buildMediaTab(),  
        ],
      );
    }

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
      body: Stack(
        children: [
          bodyContent, 
          
          if (_isDownloadingMedia)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_downloadSpeed, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 150,
                      child: LinearProgressIndicator(value: _downloadProgress),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}