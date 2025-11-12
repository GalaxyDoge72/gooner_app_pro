// audio_screen.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart'; // We still need this for the core Player
import 'package:provider/provider.dart'; // ⭐ NEW: For accessing SettingsService

// ⭐ NEW: Imports for Download Service and Settings
import '../models/file_attachment.dart';
import '../services/download_service.dart';
import '../services/settings_service.dart';

// Global Key to reference the download button's position for iOS share sheet
final GlobalKey _downloadButtonKey = GlobalKey(); // ⭐ NEW: Key for download button

class AudioScreen extends StatefulWidget {
  final FileAttachment attachment;

  const AudioScreen({
    super.key,
    required this.attachment,
  });

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  late final Player _player;
  String? _mediaError;
  bool _isSeeking = false;
  
  // ⭐ NEW: Download State Variables
  bool _downloading = false;
  double _progress = 0.0;
  String _speed = "Starting...";


  @override
  void initState() {
    super.initState();
    _player = Player();
    _setupMedia();

    // Listen for errors
    _player.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          log('MediaKit Error (Audio): $error');
          _mediaError = 'Playback Error: $error. Check URL or Codec.';
        });
      }
    });
  }

  Future<void> _setupMedia() async {
    try {
      await _player.open(Media(widget.attachment.fullUrl));
      _player.setPlaylistMode(PlaylistMode.loop);
      _player.play();
    } catch (e, stack) {
      log('Error setting up audio: $e\n$stack');
      if (mounted) {
        setState(() {
          _mediaError = 'Failed to load audio: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // Helper to format duration
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ⭐ NEW: Download Function
  Future<void> _downloadFile(BuildContext context) async {
    if (_downloading) return;

    final settings = Provider.of<SettingsService>(context, listen: false);

    // Assuming source is derived from the attachment or known context
    // For now, setting source to 'Danbooru' as an example if it's not available
    final source = null;
    final userId = settings.danbooruUserID;
    final apiKey = settings.danbooruApiKey;

    // A check to infer R34 if Danbooru auth is missing but R34 auth is present
    String finalSource = source ?? 'Unknown';
    String? finalUserId = userId;
    String? finalApiKey = apiKey;
    
    if (finalSource == 'Unknown') {
        if (settings.r34UserId.isNotEmpty && settings.r34ApiKey.isNotEmpty) {
            finalSource = 'Rule34';
            finalUserId = settings.r34UserId;
            finalApiKey = settings.r34ApiKey;
        } else if (settings.danbooruUserID.isNotEmpty && settings.danbooruApiKey.isNotEmpty) {
            finalSource = 'Danbooru';
            finalUserId = settings.danbooruUserID;
            finalApiKey = settings.danbooruApiKey;
        }
    }


    await DownloadService.downloadAndShareFile(
      fileUrl: widget.attachment.fullUrl,
      source: finalSource,
      userId: finalUserId,
      apiKey: finalApiKey,
      context: context,
      buttonKey: _downloadButtonKey,
      onStart: () {
        setState(() {
          _downloading = true;
          _progress = 0;
          _speed = "Starting...";
        });
      },
      onProgress: (progress, speed) {
        setState(() {
          _progress = progress;
          _speed = speed;
        });
      },
      onComplete: (success, message) {
        setState(() => _downloading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isDebugMode = settings.isdebugMode;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.attachment.name),
            // ⭐ NEW: Download Button in AppBar
            actions: [
              IconButton(
                key: _downloadButtonKey,
                icon: const Icon(Icons.download),
                onPressed: _downloading ? null : () => _downloadFile(context),
              ),
            ],
          ),
          // ⭐ NEW: Use Stack to place Download Progress Overlay
          body: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon
                      const Icon(
                        Icons.audiotrack,
                        size: 150,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(height: 24),

                      // File Name
                      Text(
                        widget.attachment.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Error Message
                      if (_mediaError != null)
                        Text(
                          _mediaError!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),

                      // Playback Controls
                      if (_mediaError == null) ...[
                        // Seek Bar
                        StreamBuilder<Duration>(
                          stream: _player.stream.duration,
                          builder: (context, durationSnapshot) {
                            final totalDuration =
                                durationSnapshot.data ?? Duration.zero;

                            return StreamBuilder<Duration>(
                              stream: _player.stream.position,
                              builder: (context, positionSnapshot) {
                                final position =
                                    positionSnapshot.data ?? Duration.zero;

                                return Column(
                                  children: [
                                    Slider(
                                      value: (position.inMilliseconds)
                                          .clamp(
                                            0,
                                            totalDuration.inMilliseconds,
                                          )
                                          .toDouble(),
                                      min: 0.0,
                                      max: (totalDuration.inMilliseconds)
                                          .toDouble()
                                          .clamp(0.0, double.infinity),
                                      onChanged: (value) {
                                        if (!_isSeeking) {
                                          // Update position while dragging
                                          _player.seek(
                                              Duration(milliseconds: value.toInt()));
                                        }
                                      },
                                      onChangeStart: (value) {
                                        _isSeeking = true;
                                        _player.pause(); // Pause while seeking
                                      },
                                      onChangeEnd: (value) {
                                        _player
                                            .seek(Duration(milliseconds: value.toInt()));
                                        _player.play(); // Resume after seek
                                        _isSeeking = false;
                                      },
                                    ),
                                    // Time labels
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDuration(position)),
                                        Text(_formatDuration(totalDuration)),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Play/Pause Button
                        StreamBuilder<bool>(
                          stream: _player.stream.playing,
                          builder: (context, playingSnapshot) {
                            final isPlaying = playingSnapshot.data ?? false;

                            return IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                size: 64,
                              ),
                              onPressed: _player.playOrPause,
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        
                        // ⭐ NEW: Debug Labels (Conditional)
                        if (isDebugMode)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              Text('Debug Info', style: Theme.of(context).textTheme.titleMedium),
                              StreamBuilder<double?>(
                                stream: _player.stream.audioBitrate,
                                builder: (context, bitrateSnapshot) {
                                  final bitrateVal = bitrateSnapshot.data;
                                  final bitrate = bitrateVal != null
                                      ? '${(bitrateVal / 1000).toStringAsFixed(1)} kbps'
                                      : 'N/A';
                                  return Text('Bitrate: $bitrate');
                                },
                              ),
                              StreamBuilder<Duration>(
                                stream: _player.stream.buffer,
                                builder: (context, bufferSnapshot) {
                                  final buffer = bufferSnapshot.data ?? Duration.zero;
                                  final bufferLeft = buffer.inMilliseconds > 0
                                      ? _formatDuration(_player.state.duration - buffer)
                                      : 'N/A';
                                  return Text('Buffer Left: $bufferLeft');
                                },
                              ),
                              const Divider(),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // ⭐ NEW: Download Progress Overlay
              if (_downloading)
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
                      crossAxisAlignment: CrossAxisAlignment.end,
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
            ],
          ),
        );
      },
    );
  }
}