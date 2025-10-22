import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gooner_app_pro/models/danbooru_post.dart';
import 'package:gooner_app_pro/screens/image_screen.dart';
import '../settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DanbooruScreen extends StatefulWidget {
  const DanbooruScreen({super.key});

  @override
  State<DanbooruScreen> createState() => _DanbooruScreenState();
}

class _DanbooruScreenState extends State<DanbooruScreen> {
  final TextEditingController _tagController = TextEditingController(text: "furry");
  final ScrollController _scrollController = ScrollController();

  static const _keyUserId = 'Danbooru_UserId';
  static const _keyApiKey = 'Danbooru_ApiKey';

  final List<DanbooruPost> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  late int _postsPerPage;

  String _userId = "";
  String _apiKey = "";

  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _postsPerPage = _settingsService.danbooruPostAmount;
    _fetchPosts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_isLoading &&
          _hasMore) {
        _fetchPosts();
      }
    });
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString(_keyUserId) ?? '';
      _apiKey = prefs.getString(_keyApiKey) ?? '';
    });
  }

  Future<void> _saveCredentials(String userId, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId.trim());
    await prefs.setString(_keyApiKey, apiKey.trim());
    setState(() {
      _userId = userId.trim();
      _apiKey = apiKey.trim();
    });
  }

  Future<void> _showSettingsDialog() async {
    final userIdController = TextEditingController(text: _userId);
    final apiKeyController = TextEditingController(text: _apiKey);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Danbooru API Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userIdController,
              decoration: const InputDecoration(labelText: "User ID"),
            ),
            TextField(
              controller: apiKeyController,
              decoration: const InputDecoration(labelText: "API Key"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _saveCredentials(
                userIdController.text,
                apiKeyController.text,
              );
              Navigator.pop(context);
              _startNewSearch();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchPosts() async {
    if (_isLoading || !_hasMore) return;
    if (_userId.isEmpty || _apiKey.isEmpty) return;

    setState(() => _isLoading = true);

    final nextPage = _currentPage + 1;
    final tags = Uri.encodeComponent(_tagController.text);
    final url =
        'https://danbooru.donmai.us/posts.json?tags=$tags&page=$nextPage&limit=$_postsPerPage&login=${Uri.encodeComponent(_userId)}&api_key=${Uri.encodeComponent(_apiKey)}';

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'GoonerAppFlutter/1.0 (by GalaxyDoge72)',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final List<DanbooruPost> newPosts =
              data.map((e) => DanbooruPost.fromJson(e)).toList();

          setState(() {
            _posts.addAll(newPosts);
            _currentPage = nextPage;
            if (newPosts.length < _postsPerPage) _hasMore = false;
          });
        } else {
          setState(() => _hasMore = false);
        }
      } else {
        debugPrint("Danbooru Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Danbooru Fetch Exception: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startNewSearch() async {
    setState(() {
      _currentPage = 0;
      _posts.clear();
      _hasMore = true;
    });
    await _fetchPosts();
  }

  void _openImage(DanbooruPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageScreen(
          post: post,
          source: 'Danbooru',
          userId: _userId,
          apiKey: _apiKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Danbooru"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Enter tags...',
                    ),
                    onSubmitted: (_) => _startNewSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _startNewSearch,
                  child: const Text("Search"),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    if (_currentPage > 0) {
                      _currentPage--;
                      _startNewSearch();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _hasMore ? _fetchPosts : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _posts.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _posts.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final post = _posts[index];
                final previewUrl = post.previewUrl ?? "";

                return GestureDetector(
                  onTap: () => _openImage(post),
                  child: Stack(
                    children: [
                      Container(
                        color: Colors.grey[800],
                        child: previewUrl.isNotEmpty
                            ? Image.network(
                                previewUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : const Center(
                                child: Text("N/A",
                                    style: TextStyle(color: Colors.white70)),
                              ),
                      ),
                      if (post.isVideo)
                        const Positioned(
                          right: 4,
                          bottom: 4,
                          child: Text("MP4",
                              style: TextStyle(
                                  backgroundColor: Colors.black54,
                                  color: Colors.white)),
                        ),
                      if (post.isWebmVideo)
                        const Positioned(
                          left: 4,
                          top: 4,
                          child: Text("WEBM",
                              style: TextStyle(
                                  backgroundColor: Colors.black54,
                                  color: Colors.orange)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
