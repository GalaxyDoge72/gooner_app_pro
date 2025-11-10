import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart'; // REMOVED
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../models/r34_post.dart';
import '../models/danbooru_post.dart';
import '../models/e621_post.dart';
import '../models/tags_object.dart';

// New imports for iOS Media players //
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class ImageScreen extends StatefulWidget {
  final dynamic post;
  final String? source; // "Rule34", "Danbooru", "e621"
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

  // VideoPlayerController? _videoController; // REMOVED
  bool _downloading = false;
  double _progress = 0.0;
  String _speed = "Starting...";

  // Controllers are now used for ALL platforms //
  Player? _player;
  VideoController? _videoKitController;

  @override
  void initState() {
    super.initState();

    // Initialize media_kit players unconditionally for all platforms
    _player = Player();
    _videoKitController = VideoController(_player!);

    _setupMedia();
  }

  @override
  void dispose() {
    // _videoController?.dispose(); // REMOVED
    _player?.dispose();
    super.dispose();
  }

  Future<void> _setupMedia() async {
    final post = widget.post;

    // Determine type and URL
    if (post is R34Post) {
      fileUrl = post.fileUrl ?? '';
      isVideo = post.isVideo;
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

    if (isVideo) {
      // Use media_kit for ALL platforms, replacing the conditional logic
      await _player!.open(Media(authUrl));
      _player!.setPlaylistMode(PlaylistMode.loop);
      _player!.play();
      
      setState(() {});
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
    return url;
  }

  String _extractR34Tags(R34Post post) {
    final tags = post.parsedTags;
    if (tags.isEmpty) return 'No tags available.';
    return 'Source: Rule34 | Post ID: ${post.id}\n\n${tags.join(", ")}';
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
        // This returns a String? (nullable string)
        saveDir = await FilePicker.platform.getDirectoryPath();
      } catch (e) {
        log('Caught exception $e');
      }
    }

    // ⭐ CRITICAL FIX: Check if the user cancelled the directory picker
    if (saveDir == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download cancelled by user.')),
        );
      }
      return; // Stop the download process and skip the rest of the method
    }

    // 2️⃣ Stream the download
    final request = http.Request('GET', uri);
    final response = await http.Client().send(request);

    // Determine filename and fallback extension
    String fileName =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download';
    final contentType = response.headers['content-type'] ?? '';

    // 3️⃣ Append file extension if missing
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

    // saveDir is guaranteed to be non-null here
    final filePath = '$saveDir/$fileName';
    final file = File(filePath);
    final total = response.contentLength ?? -1;
    var received = 0;
    final sink = file.openWrite();
    final stopwatch = Stopwatch()..start();

    await for (final chunk in response.stream) {
      // ... (rest of download logic) ...
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

    if (useShareSheet) {
      final xfile = XFile(filePath, name: fileName);
      await Share.shareXFiles([xfile], text: 'Downloaded: $fileName');
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
        // ... (AppBar is unchanged) ...
        title: const Text('Image Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloading ? null : _downloadFile,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: isVideo
                // MODIFIED: Always use the media_kit Video widget for video playback
                ? Video( 
                    controller: _videoKitController!,
                    fit: BoxFit.contain,
                  )
                : Image.network(
                    authUrl,
                    fit: BoxFit.contain,
                    // ... (Image.network logic is unchanged) ...
                    loadingBuilder: (context, child, loading) {
                      if (loading == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, _, __) => const Center(
                      child: Text(
                        "Cannot display image or unsupported WebM.",
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          ),
          // ... (Rest of your Stack children for progress, tags, etc. are unchanged) ...
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