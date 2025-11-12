// download_service.dart

import 'dart:io';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart'; // ⭐ Ensure this package is available

// Global Key to reference the download button's position for iOS share sheet
GlobalKey downloadButtonKey = GlobalKey(); 

// ... (BasePost interface and buildAuthenticatedUrl remain the same) ...
// ... (static String _formatSpeed remains the same) ...

class DownloadService {

  static String buildAuthenticatedUrl(String url, String? source, String? userId, String? apiKey) {
    // ... (logic remains the same)
    if (source == 'Danbooru' && userId != null && apiKey != null) {
      return '$url?api_key=${Uri.encodeComponent(apiKey)}&login=${Uri.encodeComponent(userId)}';
    } else if (source == 'Rule34' && userId != null && apiKey != null) {
      return '$url?api_key=${Uri.encodeComponent(apiKey)}&user=${Uri.encodeComponent(userId)}';
    }
    return url;
  }

  static String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(2)} B/s';
    final kbps = bytesPerSecond / 1024;
    if (kbps < 1024) return '${kbps.toStringAsFixed(2)} KB/s';
    final mbps = kbps / 1024;
    return '${mbps.toStringAsFixed(2)} MB/s';
  }

  // ⭐ Main Download Function with Platform-Specific Handling
  static Future<void> downloadAndShareFile({
    required String fileUrl,
    required String? source,
    required String? userId,
    required String? apiKey,
    required BuildContext context,
    required GlobalKey buttonKey,
    Function(double progress, String speed)? onProgress, 
    Function()? onStart,
    Function(bool success, String message)? onComplete,
  }) async {
    final url = buildAuthenticatedUrl(fileUrl, source, userId, apiKey);
    final uri = Uri.parse(url);

    onStart?.call();

    try {
      // 1. Determine download location based on platform
      String saveDir;
      bool useShareSheet = false;
      
      // If mobile (iOS/Android), use temporary directory for sharing.
      if (Platform.isIOS || Platform.isAndroid) {
        final dir = await getTemporaryDirectory();
        saveDir = dir.path;
        useShareSheet = true; // Use share sheet on mobile platforms
      } else {
        // Desktop platforms (Linux, Windows, macOS) require a user-chosen directory
        // We will download to a temp directory first, then copy/move to the chosen location later if not using share.
        final dir = await getTemporaryDirectory();
        saveDir = dir.path;
        useShareSheet = false; // Do NOT use share sheet on desktop
      }


      // 2. Stream the download (remains the same)
      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);

      // Determine filename and fallback extension (remains the same)
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

      final tempFilePath = '$saveDir/$fileName';
      final file = File(tempFilePath);
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
          onProgress?.call(progress, _formatSpeed(speed));
        }
      }

      await sink.close();
      stopwatch.stop();

      // 3. Platform-Specific Action: Share or Save

      if (useShareSheet) {
        // iOS/Android: Use Share Sheet
        final RenderBox? box = buttonKey.currentContext?.findRenderObject() as RenderBox?;
        Rect? shareRect;
        if (box != null) {
          shareRect = box.localToGlobal(Offset.zero) & box.size;
        }

        final xfile = XFile(tempFilePath, name: fileName);
        
        await Share.shareXFiles(
          [xfile], 
          text: 'Downloaded: $fileName',
          sharePositionOrigin: shareRect, 
        );
        onComplete?.call(true, 'Downloaded and shared: $fileName');
        
      } else {
        // Desktop (Linux, Windows, macOS): Use FilePicker to save locally
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save File',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [fileName.split('.').last],
        );
        
        if (result != null) {
          // User chose a save location, copy the file
          final destinationFile = File(result);
          await file.copy(destinationFile.path);
          onComplete?.call(true, 'File saved successfully to: $result');
        } else {
          // User cancelled the save dialog
          onComplete?.call(false, 'Download completed, but saving was cancelled.');
        }

        // Clean up the temporary file after saving/cancelling the save dialog
        await file.delete(); 
      }
      

    } catch (e) {
      log('Download failed: $e');
      onComplete?.call(false, 'Download failed: $e');
    }
  }
}