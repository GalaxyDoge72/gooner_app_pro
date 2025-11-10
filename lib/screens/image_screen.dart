import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../models/r34_post.dart';
import '../models/danbooru_post.dart';
import '../models/e621_post.dart';
import '../models/tags_object.dart';

// New imports for media players //
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class ImageScreen extends StatefulWidget {
  final dynamic post;
  final String? source; // "Rule34", "Danbooru", "e621", "Kemono.cr"
  final String? userId;
  final String? apiKey;

  const ImageScreen({
    super.key,
    required this.post,
    this.source,
    this.userId,
    this.apiKey,
  });

  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  late String fileUrl;
  late bool isVideo;
  late bool isWebm;
  late String tagsText;

  bool _downloading = false;
  double _progress = 0.0;
  String _speed = "Starting...";

  // MediaKit Controllers
  Player? _player;
  VideoController? _videoKitController;
  String? _mediaError; 

  // ⭐ NEW: Media Loading State Variables
  bool _mediaLoading = true; 
  double _mediaLoadingProgress = 0.0; // 0.0 to 1.0 for video buffering

  // Key to reference the download button's position for iOS share sheet
  final GlobalKey _downloadButtonKey = GlobalKey(); 

  @override
  void initState() {
    super.initState();

    // Initialize media_kit players
    _player = Player();
    _videoKitController = VideoController(_player!);

    // Subscribe to the error stream to capture playback issues
    _player!.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          log('MediaKit Error: $error');
          _mediaError = 'Playback Error: $error. Check URL or Codec.';
        });
      }
    });

    _setupMedia();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _setupMedia() async {
    final post = widget.post;

    setState(() {
      _mediaLoading = true;
      _mediaLoadingProgress = 0.0;
    });

    // Determine type and URL
    if (post is R34Post) {
      fileUrl = post.fileUrl ?? '';
      isVideo = post.isVideo || post.isWebmVideo;
      isWebm = post.isWebmVideo;
      tagsText = _extractR34Tags(post);
    } else if (post is DanbooruPost) {
      fileUrl = post.highResImageUrl ?? '';
      isVideo = post.isAnyVideo;
      isWebm = post.isWebmVideo;
      tagsText = _extractDanbooruTags(post);
    } else if (post is E621Post) {
      fileUrl = post.fileUrl ?? '';
      isVideo = post.isAnyVideo;
      isWebm = post.isWebmVideo;
      tagsText = _extractE621Tags(post);
    } else {
      fileUrl = '';
      isVideo = false;
      isWebm = false;
      tagsText = 'Unknown post type';
    }

    final authUrl = _buildAuthenticatedUrl(fileUrl);

    if (isVideo && authUrl.isNotEmpty) {
      
      // 1. Subscribe to the buffering stream for video progress
      _player!.stream.buffering.listen((isBuffering) {
        // We only care about progress when buffering or when loading
        if (isBuffering || _mediaLoading) {
          final buffered = _player!.state.buffer.inMilliseconds;
          final total = _player!.state.duration.inMilliseconds;
          
          if (total > 0 && mounted) {
            setState(() {
              _mediaLoadingProgress = buffered / total;
            });
          }
        }
      });
      
      // 2. Listen for the first play state (media loaded)
      _player!.stream.playing.listen((isPlaying) {
        if (isPlaying && _mediaLoading && mounted) {
          setState(() {
            _mediaLoading = false; // Video is loaded and playing
            _mediaLoadingProgress = 1.0;
          });
        }
      });

      await _player!.open(Media(authUrl));
      _player!.setPlaylistMode(PlaylistMode.loop);
      _player!.play();
      
    } else {
      // If it's an image, the loading state will be handled by Image.network's builder
    }
  }

  String _buildAuthenticatedUrl(String url) {
    if (widget.source == 'Danbooru' &&
        widget.apiKey != null &&
        widget.userId != null) {
      return '$url?api_key=${Uri.encodeComponent(widget.apiKey!)}&login=${Uri.encodeComponent(widget.userId!)}';
    } else if (widget.source == 'Rule34' &&
        widget.apiKey != null &&
        widget.userId != null) {
      return '$url?api_key=${Uri.encodeComponent(widget.apiKey!)}&user=${Uri.encodeComponent(widget.userId!)}';
    }
    // No specific auth for Kemono.cr or generic posts needed here
    return url;
  }

  String _extractR34Tags(R34Post post) {
    final tags = post.parsedTags;
    if (tags.isEmpty) return 'No tags available.';
    
    // Check if the post has Kemono-specific metadata (authUserId and authApiKey were re-used for creatorId and service)
    String sourceInfo = 'Source: Rule34';
    if (widget.source == 'Kemono.cr') {
      sourceInfo = 'Source: Kemono.cr (${post.authApiKey ?? 'N/A'} / ${post.authUserId ?? 'N/A'})';
    }
    
    return '$sourceInfo | Post ID: ${post.id}\n\n${tags.join(", ")}';
  }

  String _extractDanbooruTags(DanbooruPost post) {
    final tags = TagsObject(
      general: post.tagStringGeneral?.split(' ') ?? [],
      artist: post.tagStringArtist?.split(' ') ?? [],
      character: post.tagStringCharacter?.split(' ') ?? [],
      copyright: post.tagStringCopyright?.split(' ') ?? [],
    );

    post.tags = tags;
    final buffer = StringBuffer();
    buffer.writeln('Source: Danbooru | Post ID: ${post.id}\n');
    if (tags.artist.isNotEmpty) buffer.writeln('-- Artists --\n${tags.artist.join(", ")}\n');
    if (tags.character.isNotEmpty) buffer.writeln('-- Characters --\n${tags.character.join(", ")}\n');
    if (tags.copyright.isNotEmpty) buffer.writeln('-- Copyright --\n${tags.copyright.join(", ")}\n');
    if (tags.general.isNotEmpty) buffer.writeln('-- General Tags --\n${tags.general.join(", ")}\n');
    return buffer.toString().trim();
  }

  String _extractE621Tags(E621Post post) {
    final tags = post.tags;
    if (tags == null) return 'No tags found.';
    final buffer = StringBuffer();
    buffer.writeln('Source: e621 | Post ID: ${post.id}\n');
    if (tags.artist.isNotEmpty) buffer.writeln('-- Artists --\n${tags.artist.join(", ")}\n');
    if (tags.character.isNotEmpty) buffer.writeln('-- Characters --\n${tags.character.join(", ")}\n');
    if (tags.species.isNotEmpty) buffer.writeln('-- Species --\n${tags.species.join(", ")}\n');
    if (tags.copyright.isNotEmpty) buffer.writeln('-- Copyright --\n${tags.copyright.join(", ")}\n');
    if (tags.general.isNotEmpty) buffer.writeln('-- General --\n${tags.general.join(", ")}\n');
    return buffer.toString().trim();
  }

  Future<void> _downloadFile() async {
    final url = _buildAuthenticatedUrl(fileUrl);
    final uri = Uri.parse(url);

    setState(() {
      _downloading = true;
      _progress = 0;
      _speed = "Starting...";
    });

    try {
      String? saveDir;
      bool useShareSheet = Platform.isIOS;

      if (useShareSheet) {
        final dir = await getTemporaryDirectory();
        saveDir = dir.path;
      } else {
        try {
          saveDir = await FilePicker.platform.getDirectoryPath();
        } catch (e) {
          log('Caught exception $e');
        }
      }

      if (saveDir == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download cancelled by user.')),
          );
        }
        return;
      }

      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);

      String fileName =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download';
      final contentType = response.headers['content-type'] ?? '';

      if (!fileName.contains('.')) {
        if (contentType.contains('video/webm')) {
          fileName += '.webm';
        } else if (contentType.contains('video/mp4')) {
          fileName += '.mp4';
        } else if (contentType.contains('image/jpeg')) {
          fileName += '.jpg';
        } else if (contentType.contains('image/png')) {
          fileName += '.png';
        } else if (contentType.contains('image/gif')) {
          fileName += '.gif';
        } else {
          fileName += '.bin';
        }
      }

      final filePath = '$saveDir/$fileName';
      final file = File(filePath);
      final total = response.contentLength ?? -1;
      var received = 0;
      final sink = file.openWrite();
      final stopwatch = Stopwatch()..start();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;

        if (total > 0) {
          final progress = received / total;
          final speed = received / (stopwatch.elapsedMilliseconds / 1000 + 0.001);
          setState(() {
            _progress = progress;
            _speed = _formatSpeed(speed);
          });
        }
      }

      await sink.close();
      stopwatch.stop();

      // Corrected Fix for iOS Share Sheet Popover (sharePositionOrigin)
      if (useShareSheet) {
        final RenderBox? box = _downloadButtonKey.currentContext?.findRenderObject() as RenderBox?;
        
        Rect? shareRect;
        if (box != null) {
          shareRect = box.localToGlobal(Offset.zero) & box.size;
        }

        final xfile = XFile(filePath, name: fileName);
        
        await Share.shareXFiles(
          [xfile], 
          text: 'Downloaded: $fileName',
          sharePositionOrigin: shareRect, 
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded: $fileName')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      setState(() => _downloading = false);
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(2)} B/s';
    final kbps = bytesPerSecond / 1024;
    if (kbps < 1024) return '${kbps.toStringAsFixed(2)} KB/s';
    final mbps = kbps / 1024;
    return '${mbps.toStringAsFixed(2)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final authUrl = _buildAuthenticatedUrl(fileUrl);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image/Media Details'),
        actions: [
          IconButton(
            key: _downloadButtonKey,
            icon: const Icon(Icons.download),
            onPressed: _downloading ? null : _downloadFile,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: isVideo 
                ? (_mediaError != null
                    // Display error message if playback failed
                    ? Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          _mediaError!,
                          style: const TextStyle(color: Colors.red, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      )
                    // Otherwise, show the video player in a Stack
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Video(
                            controller: _videoKitController!,
                            fit: BoxFit.contain,
                          ),
                          // Video Loading/Buffering Indicator
                          if (_mediaLoading)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(color: Colors.white),
                                    const SizedBox(height: 10),
                                    // Show buffering progress for video
                                    Text(
                                      'Buffering: ${(_mediaLoadingProgress * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                  )
                : Image.network(
                    authUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loading) {
                      if (loading == null) {
                        // Image is loaded, set loading state to false
                        if (_mediaLoading) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() => _mediaLoading = false);
                          });
                        }
                        return child;
                      }
                      
                      // Image is loading, show progress
                      return Center(
                        child: CircularProgressIndicator(
                          value: loading.expectedTotalBytes != null
                              ? loading.cumulativeBytesLoaded / loading.expectedTotalBytes!
                              : null, // Indeterminate progress if total bytes is unknown
                        ),
                      );
                    },
                    errorBuilder: (context, _, __) => const Center(
                      child: Text(
                        "Cannot display image or non-video file type.",
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          ),
          
          // --- Download Progress Overlay ---
          if (_downloading)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black54,
                child: Column(
                  children: [
                    Text(_speed, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 150,
                      child: LinearProgressIndicator(value: _progress),
                    ),
                  ],
                ),
              ),
            ),
            
          // --- Show Tags Button ---
          Positioned(
            bottom: 80,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Post Tags'),
                    content: SingleChildScrollView(
                      child: Text(tagsText),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Tags'),
            ),
          ),
          
          // --- Show Comments Button ---
          Positioned(
            bottom: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Comments page navigation not yet implemented.'),
                  ),
                );
              },
              child: const Text('Show Comments'),
            ),
          ),
        ],
      ),
    );
  }
}