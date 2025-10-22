import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/kemono_post.dart';

class KemonoService {
  final http.Client _client;

  KemonoService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<KemonoPost>> fetchPosts({required String service, required String userId, int page = 0, int limit = 25}) async {
    final uri = Uri.https('kemono.cr', '/api/v1/$service/user/$userId', {
      'o': page.toString(),
      'limit': limit.toString(),
    });
    log("Using API URL: $uri");
    final response = await _client.get(uri, headers: {
      'User-Agent': 'GoonerAppPro/1.0 (by GalaxyDoge72)',
    });
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch Kemono posts: ${response.statusCode}');
    }
    final data = json.decode(response.body) as List<dynamic>;
    return data.map((e) => KemonoPost.fromJson(e as Map<String, dynamic>)).toList();
  }
}
