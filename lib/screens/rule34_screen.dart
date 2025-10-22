import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../models/r34_post.dart';

class Rule34Screen extends StatefulWidget {
  const Rule34Screen({super.key});

  @override
  State<Rule34Screen> createState() => _Rule34ScreenState();
}

class _Rule34ScreenState extends State<Rule34Screen> {
  static const _keyUserId = 'Rule34_UserId';
  static const _keyApiKey = 'Rule34_ApiKey';

  final TextEditingController _tagController = TextEditingController(text: 'furry');
  final List<R34Post> _posts = [];

  String _userId = '';
  String _apiKey = '';
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _postsPerPage = 25;

  @override
  void initState() {
    super.initState();
    _loadCredentialsAndFetch();
  }

  Future<void> _loadCredentialsAndFetch() async {
    await _loadCredentials();

    if (_userId.isEmpty || _apiKey.isEmpty) {
      await _showSettingsDialog(isInitialLoad: true);
    }

    await _fetchPosts(_tagController.text);
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

  Future<void> _showSettingsDialog({bool isInitialLoad = false}) async {
    final userIdController = TextEditingController(text: _userId);
    final apiKeyController = TextEditingController(text: _apiKey);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rule34 API Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userIdController,
              decoration: const InputDecoration(labelText: 'User ID'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: apiKeyController,
              decoration: const InputDecoration(labelText: 'API Key'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isInitialLoad) Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveCredentials(
                  userIdController.text, apiKeyController.text);
              if (context.mounted) Navigator.pop(ctx);
              await _startNewSearch();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchPosts(String tags) async {
    if (_isLoading || _userId.isEmpty || _apiKey.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final url =
          'https://api.rule34.xxx/index.php?page=dapi&s=post&q=index&tags=${Uri.encodeComponent(tags)}&pid=$_currentPage&limit=$_postsPerPage&json=1&api_key=$_apiKey&user_id=$_userId';

      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Rule34Flutter/1.0 (by GalaxyK)',
      });

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final List<dynamic> data = json.decode(res.body);
      final newPosts = data.map((e) => R34Post.fromJson(e)).toList();

      setState(() {
        for (final post in newPosts) {
          post.authUserId = _userId;
          post.authApiKey = _apiKey;
          _posts.add(post);
        }

        if (newPosts.length < _postsPerPage) {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startNewSearch() async {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
      _posts.clear();
    });
    await _fetchPosts(_tagController.text);
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _currentPage++);
    await _fetchPosts(_tagController.text);
  }

  Future<void> _loadPrevious() async {
    if (_currentPage <= 0) return;
    setState(() => _currentPage--);
    await _fetchPosts(_tagController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rule34.xxx'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
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
                    decoration:
                        const InputDecoration(labelText: 'Enter tags...'),
                    onSubmitted: (_) => _startNewSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _startNewSearch,
                  child: const Text('Search'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: _loadPrevious,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: _loadMore,
                ),
              ],
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 4),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                return GestureDetector(
                  onTap: () {
                    // Navigate to detail page (to be implemented)
                    Navigator.pushNamed(
                      context,
                      '/image_screen',
                      arguments: post,
                    );
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          post.previewUrl ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.error)),
                        ),
                      ),
                      if (post.isVideo)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: _videoLabel('MP4', Colors.white),
                        ),
                      if (post.isWebmVideo)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: _videoLabel('WEBM', const Color(0xFFF17105)),
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

  Widget _videoLabel(String text, Color color) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
