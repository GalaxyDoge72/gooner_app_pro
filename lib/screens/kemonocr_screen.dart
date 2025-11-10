import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/r34_post.dart';
import 'kemono_post_screen.dart'; // NEW IMPORT

// ⭐ ADD SingleTickerProviderStateMixin
class KemonoCrScreen extends StatefulWidget {
  const KemonoCrScreen({super.key});

  @override
  State<KemonoCrScreen> createState() => _KemonoCrScreenState();
}

// ⭐ ADD SingleTickerProviderStateMixin for TabController
class _KemonoCrScreenState extends State<KemonoCrScreen> with SingleTickerProviderStateMixin {
  // --- State Variables (Regular/Creator Feed) ---
  final List<R34Post> _posts = [];
  bool _isLoading = false;
  final http.Client _httpClient = http.Client();
  bool _hasMore = true;
  int _currentPage = 0;

  // UI selection state (only for Regular/Creator Feed)
  String _currentService = 'patreon';
  final TextEditingController _creatorIdController =
      TextEditingController(text: '12345678');
  final TextEditingController _searchController = TextEditingController();

  // --- Tab Controller State --- ⭐ NEW
  late TabController _tabController;
  
  // --- State Variables for Popular Feed --- ⭐ NEW
  final List<R34Post> _popularPosts = []; 
  bool _popularLoading = false;
  String? _popularError;
  bool _popularHasFetched = false;

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

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);

    WidgetsBinding.instance.addPostFrameCallback((_) {
    });
  }

  @override
  void dispose() {
    _httpClient.close();
    _creatorIdController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  void _handleTabSelection() {
    if (_tabController.index == 1 && !_popularHasFetched && !_popularLoading) {
      _fetchPopularPosts();
    }
  }

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

    return await _performFetch(uri, isPopularFeed: false); // Passing isPopularFeed flag
  }

  Future<void> _fetchPopularPosts() async {
    if (_popularLoading) return;

    final now = DateTime.now();
    final dateString = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final String path = '$_apiVersionPath/posts/popular';
    final Map<String, dynamic> queryParameters = {
      'date': dateString, 
      'period': 'day',
    };
    
    final Uri uri = Uri.https(
      _apiBaseUrl.replaceAll('https://', ''), 
      path,
      queryParameters,
    );
    
    setState(() {
      _popularLoading = true;
      _popularError = null;
    });

    // Reuse the fetch logic, but specify it's for the popular feed
    return await _performFetch(uri, isPopularFeed: true); 
  }

  Future<void> _performFetch(Uri uri, {required bool isPopularFeed}) async {
    try {
      log("Kemono.cr GET URL: $uri");

      final response = await _httpClient.get(
        uri,
        headers: {'Accept': 'text/css'},
      );

      if (response.statusCode == 200) {
        final dynamic rawResponse = jsonDecode(response.body);
        List<dynamic> postsJson = [];

        if (isPopularFeed) {
          // Popular feed returns a map with a 'posts' key
          postsJson = rawResponse['posts'] ?? [];
        } else {
          // Creator feed returns a list directly
          postsJson = rawResponse;
        }

        final List<R34Post> newPosts = postsJson
            .map((postJson) => _parseKemonoPost(postJson))
            .whereType<R34Post>()
            .toList();

        setState(() {
          if (isPopularFeed) {
            _popularPosts.addAll(newPosts);
            _popularHasFetched = true;
            _popularError = null;
          } else {
            _posts.addAll(newPosts);
            _currentPage++;
            _hasMore = newPosts.isNotEmpty;
          }
        });
      } else {
        log('HTTP Error: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Error fetching posts: ${response.statusCode}. Check ID/Service.')));
        }
        if (isPopularFeed) {
          setState(() => _popularError = 'HTTP Error: ${response.statusCode}');
        }
      }
    } catch (e, stack) {
      log('Fetch Error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A network or parsing error occurred.')));
      }
      if (isPopularFeed) {
          setState(() => _popularError = 'Network/Parsing Error');
      }
    } finally {
      setState(() {
        if (isPopularFeed) {
          _popularLoading = false;
        } else {
          _isLoading = false;
        }
      });
    }
  }

  R34Post? _parseKemonoPost(Map<String, dynamic> json) {
    String? filePath = json['file']?['path'];

    // Also check for the first attachment if 'file' is null (common in popular posts)
    if (filePath == null && json['attachments'] is List && json['attachments'].isNotEmpty) {
      filePath = json['attachments'][0]?['path'];
    }

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
      authUserId: json['user']?.toString(), // Kemono Creator ID
      authApiKey: json['service'], // Kemono Service
    );
  }

  // --- Event Handlers (Unchanged) ---
  void _onSearchTapped() {
    _fetchPosts(clearPrevious: true);
  }

  void _onLoadMoreTapped() {
    _fetchPosts(clearPrevious: false);
  }

  void _onPostTapped(BuildContext context, R34Post post) {
    String creatorId;
    String service;
    
    // Check the current tab index to determine the source of the post
    if (_tabController.index == 1) { // Popular Feed
      // For popular posts, the creator ID and service are stored in the post object
      creatorId = post.authUserId ?? '';
      service = post.authApiKey ?? '';
    } else { // Regular (Creator) Feed
      // For creator posts, the creator ID and service are from the screen's controls
      creatorId = _creatorIdController.text.trim();
      service = _currentService;
    }
    
    if (creatorId.isEmpty || service.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot navigate: missing Creator ID or Service.')));
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KemonoPostScreen(
          postId: post.id,
          creatorId: creatorId,
          service: service,
        ),
      ),
    );
  }

  // --- Helper Widgets (Refactored/New) ---
  
  // ⭐ NEW: Post tile builder (for use in both grids)
  Widget _buildPostTile(R34Post post, String? imageUrl) {
      return Container(
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
            : (imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
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
                  )
                : const Center(child: Icon(Icons.broken_image, color: Colors.white70))
              ),
      );
  }

  // --- _buildControlBar (Unchanged) ---
  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // ... (DropdownButton, TextField, Search bar logic remains here)
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
          // Keep load more button in control bar for the regular feed
          ElevatedButton(
            onPressed: _isLoading || !_hasMore ? null : _onLoadMoreTapped,
            child: Text('Load More (${_posts.length})'),
          ),
        ],
      ),
    );
  }
  
  // ⭐ NEW: Widget for the Regular Feed tab content
  Widget _buildRegularTab() {
    return Column(
      children: [
        _buildControlBar(), // Contains all controls, including Load More button

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
                child: _buildPostTile(post, imageUrl),
              );
            },
          ),
        ),

        // Indicator for when more posts are loading at the bottom
        if (_isLoading && _posts.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  // ⭐ NEW: Widget for the Popular Posts tab content
  Widget _buildPopularTab() {
    if (_popularLoading && _popularPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_popularError != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Error: $_popularError'),
          ElevatedButton(onPressed: _fetchPopularPosts, child: const Text('Try Again')),
        ],
      ));
    }
    
    if (_popularPosts.isEmpty && _popularHasFetched) {
       return const Center(child: Text('No popular posts found for this period.'));
    }
    
    // Display a button to initially load the data if not yet fetched
    if (_popularPosts.isEmpty && !_popularHasFetched) {
        return Center(
          child: ElevatedButton(
            onPressed: _fetchPopularPosts, 
            child: const Text('Load Popular Posts')
          ),
        );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
      ),
      itemCount: _popularPosts.length,
      itemBuilder: (context, index) {
        final post = _popularPosts[index];
        final imageUrl = post.previewUrl;
        
        return GestureDetector(
          onTap: () => _onPostTapped(context, post),
          child: _buildPostTile(post, imageUrl),
        );
      },
    );
  }

  // --- Build Method (Modified for Tabs) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kemono Posts'),
        // ⭐ Add TabBar to the AppBar's bottom
        bottom: TabBar( 
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Creator Feed'),
            Tab(icon: Icon(Icons.trending_up), text: 'Popular'), 
          ],
        ),
      ),
      // ⭐ Use TabBarView for the body content
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Regular/Creator Feed
          _buildRegularTab(),
          // Tab 2: Popular Posts
          _buildPopularTab(),
        ],
      ),
    );
  }
}