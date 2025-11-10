import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/r34_post.dart';
import 'kemono_post_screen.dart'; // NEW IMPORT

class KemonoCrScreen extends StatefulWidget {
  const KemonoCrScreen({super.key});

  @override
  State<KemonoCrScreen> createState() => _KemonoCrScreenState();
}

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

  // --- Tab Controller State ---
  late TabController _tabController;
  
  // --- State Variables for Popular Feed ---
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

  // --- API Fetch Logic (Creator Feed) ---
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

    return await _performFetch(uri, isPopularFeed: false);
  }
  
  // --- API Fetch Logic for Popular Posts Tab ---
  Future<void> _fetchPopularPosts() async {
    if (_popularLoading) return;
    
    // 1. Get current date and format as YYYYMMDD
    final now = DateTime.now();
    final dateString = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    
    final String path = '$_apiVersionPath/posts/popular';
    final Map<String, dynamic> queryParameters = {
      'date': dateString,
      'period': 'day', // Fetching daily popular posts
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

    return await _performFetch(uri, isPopularFeed: true); 
  }

  // --- Unified API Fetch Handler ---
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
          postsJson = rawResponse['posts'] ?? [];
        } else {
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

  // --- Kemono Post Parsing ---
  R34Post? _parseKemonoPost(Map<String, dynamic> json) {
    String? filePath = json['file']?['path'];

    if (filePath == null && json['attachments'] is List && json['attachments'].isNotEmpty) {
      filePath = json['attachments'][0]?['path'];
    }

    if (filePath == null) {
      return null;
    }

    final String fileUrl = '$_apiBaseUrl$filePath';
    final String tagsString = json['title'] ?? 'untitled';

    return R34Post(
      id: json['id'].toString(),
      previewUrl: fileUrl,
      fileUrl: fileUrl,
      tagsString: tagsString,
      authUserId: json['user']?.toString(),
      authApiKey: json['service'],
    );
  }

  // --- Event Handlers ---
  void _onSearchTapped() {
    _fetchPosts(clearPrevious: true);
  }

  void _onLoadMoreTapped() {
    _fetchPosts(clearPrevious: false);
  }

  void _onPostTapped(BuildContext context, R34Post post) {
    String creatorId;
    String service;
    
    if (_tabController.index == 1) {
      creatorId = post.authUserId ?? '';
      service = post.authApiKey ?? '';
    } else {
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

  // ⭐ MODIFIED: Helper Widget for Post Tile (Now includes caption)
  Widget _buildPostTile(R34Post post, String? imageUrl) {
    // Determine the content widget (Image or Video Placeholder)
    final Widget mediaContent = post.isAnyVideo
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam, color: Colors.white70, size: 30), // Smaller icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    post.tagsString ?? 'Video', 
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 10), // Smaller text
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
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) =>
                    const Center(
                        child: Icon(Icons.broken_image,
                            color: Colors.white70)),
              )
            : const Center(child: Icon(Icons.broken_image, color: Colors.white70))
          );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700, width: 0.5),
        color: const Color(0xFF303030), // Retain background color
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Media/Image Area (Expanded to take available space)
          Expanded(
            child: mediaContent,
          ),
          
          // 2. Caption Area (Added caption)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            color: Colors.black54, // Ensures text is readable
            child: Text(
              post.tagsString ?? 'Untitled Post',
              textAlign: TextAlign.start,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10), // Smaller font for dense grid
            ),
          ),
        ],
      ),
    );
  }

  // --- _buildControlBar (Unchanged) ---
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
  
  // ⭐ MODIFIED: _buildRegularTab (Updated crossAxisCount)
  Widget _buildRegularTab() {
    return Column(
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
              crossAxisCount: 3, // ⭐ CHANGED from 2 to 3 for smaller tiles
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
            ),
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              final post = _posts[index];
              final imageUrl = post.previewUrl;

              return GestureDetector(
                onTap: () => _onPostTapped(context, post),
                child: _buildPostTile(post, imageUrl),
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
    );
  }

  // ⭐ MODIFIED: _buildPopularTab (Updated crossAxisCount)
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
        crossAxisCount: 3, // ⭐ CHANGED from 2 to 3 for smaller tiles
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

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kemono Posts'),
        bottom: TabBar( 
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Creator Feed'),
            Tab(icon: Icon(Icons.trending_up), text: 'Popular'), 
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegularTab(),
          _buildPopularTab(),
        ],
      ),
    );
  }
}