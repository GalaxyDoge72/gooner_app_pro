import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/r34_post.dart';
import 'kemono_post_screen.dart'; // NEW IMPORT

// Removed SingleTickerProviderStateMixin and TabController logic
class KemonoCrScreen extends StatefulWidget {
  const KemonoCrScreen({super.key});

  @override
  State<KemonoCrScreen> createState() => _KemonoCrScreenState();
}

class _KemonoCrScreenState extends State<KemonoCrScreen> {
  // --- State Variables ---
  final List<R34Post> _posts = [];
  bool _isLoading = false;
  final http.Client _httpClient = http.Client();
  bool _hasMore = true;
  int _currentPage = 0;

  // UI selection state
  String _currentService = 'patreon';
  final TextEditingController _creatorIdController =
      TextEditingController(text: '12345678');
  final TextEditingController _searchController = TextEditingController();

  // --- API Constants ---
  final List<String> _services = [
    'patreon',
    'fanbox',
    'fantia',
    'onlyfans',
    'discord',
    'gumroad'
  ];
  final String _apiBaseUrl = 'https://kemono.cr';
  final String _apiVersionPath = '/api/v1';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_creatorIdController.text.isNotEmpty) {
        _fetchPosts(clearPrevious: true);
      }
    });
  }

  @override
  void dispose() {
    _httpClient.close();
    _creatorIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- API Fetch Logic (Unchanged) ---
  Future<void> _fetchPosts({bool clearPrevious = false}) async {
    final String creatorId = _creatorIdController.text.trim();
    final String searchQuery = _searchController.text.trim();

    if (_isLoading || creatorId.isEmpty) {
      if (creatorId.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a Creator ID.')));
      }
      return;
    }

    setState(() {
      _isLoading = true;
      if (clearPrevious) {
        _posts.clear();
        _currentPage = 0;
        _hasMore = true;
      }
    });

    final int offset = _currentPage * 50;
    final Map<String, dynamic> queryParams = {
      'o': offset.toString(),
    };

    String path;

    if (searchQuery.isNotEmpty) {
      queryParams['q'] = searchQuery;
      path = '$_apiVersionPath/$_currentService/user/$creatorId/posts/search';
    } else {
      path = '$_apiVersionPath/$_currentService/user/$creatorId/posts';
    }

    final Uri uri = Uri.https(
      _apiBaseUrl.replaceAll('https://', ''),
      path,
      queryParams,
    );

    return await _performFetch(uri);
  }

  Future<void> _performFetch(Uri uri) async {
    try {
      log("Kemono.cr GET URL: $uri");

      final response = await _httpClient.get(
        uri,
        headers: {'Accept': 'text/css'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = jsonDecode(response.body);

        final List<R34Post> newPosts = jsonResponse
            .map((postJson) => _parseKemonoPost(postJson))
            .whereType<R34Post>()
            .toList();

        setState(() {
          _posts.addAll(newPosts);
          _currentPage++;
          _hasMore = newPosts.isNotEmpty;
        });
      } else {
        log('HTTP Error: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Error fetching posts: ${response.statusCode}. Check ID/Service.')));
        }
      }
    } catch (e, stack) {
      log('Fetch Error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A network or parsing error occurred.')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Kemono Post Parsing (Only extracts list-view info) ---
  R34Post? _parseKemonoPost(Map<String, dynamic> json) {
    String? filePath = json['file']?['path'];

    if (filePath == null) {
      return null;
    }

    final String fileUrl = '$_apiBaseUrl$filePath';
    final String tagsString = json['title'] ?? 'untitled';

    return R34Post(
      id: json['id'].toString(), // Keep the ID for navigation
      previewUrl: fileUrl,
      fileUrl: fileUrl,
      tagsString: tagsString,
    );
  }

  // --- Event Handlers ---
  void _onSearchTapped() {
    _fetchPosts(clearPrevious: true);
  }

  void _onLoadMoreTapped() {
    _fetchPosts(clearPrevious: false);
  }

  // ⭐ MODIFIED: Navigate to the new KemonoPostScreen
  void _onPostTapped(BuildContext context, R34Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KemonoPostScreen(
          postId: post.id,
          creatorId: _creatorIdController.text.trim(),
          service: _currentService,
        ),
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _currentService,
                    items: _services.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _currentService = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _creatorIdController,
                  decoration: const InputDecoration(
                    labelText: 'Creator ID',
                    hintText: 'e.g., 12345678',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Posts (Optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.text,
                    onSubmitted: (value) => _onSearchTapped(),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _onSearchTapped,
                child: const Text('Go'),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          ElevatedButton(
            onPressed: _isLoading || !_hasMore ? null : _onLoadMoreTapped,
            child: Text('Load More (${_posts.length})'),
          ),
        ],
      ),
    );
  }

  // --- Build Method (Simplified) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('kemono.cr Post List'),
      ),
      body: Column(
        children: [
          _buildControlBar(),

          if (_isLoading && _posts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
              ),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                final imageUrl = post.previewUrl;

                return GestureDetector(
                  onTap: () => _onPostTapped(context, post), // Navigate to detail screen
                  child: Container(
                    color: const Color(0xFF303030),
                    child: post.isAnyVideo
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.videocam, color: Colors.white70, size: 40),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Text(
                                    post.tagsString ?? 'Video', 
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                    child: Icon(Icons.broken_image,
                                        color: Colors.white70)),
                          ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading && _posts.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}