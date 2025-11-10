import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:gooner_app_pro/models/kemono_tag.dart';
import 'package:http/http.dart' as http;

// Note: Assuming R34Post is the generic model used for Kemono/Coomer post data
import '../models/r34_post.dart'; 
// Note: Assuming kemono_post_screen.dart is the screen used for both Kemono/Coomer posts
import 'coomer_post_screen.dart';

class CoomerStScreen extends StatefulWidget { // ⭐ Class Name Changed
  const CoomerStScreen({super.key});

  @override
  State<CoomerStScreen> createState() => _CoomerStScreenState(); // ⭐ State Class Name Changed
}

class _CoomerStScreenState extends State<CoomerStScreen> with SingleTickerProviderStateMixin { // ⭐ State Class Name Changed
  // --- State Variables (Regular/Creator Feed) ---
  // Using R34Post as the common model for Coomer.st posts
  final List<R34Post> _posts = []; 
  bool _isLoading = false;
  final http.Client _httpClient = http.Client();
  bool _hasMore = true;
  int _currentPage = 0;

  // UI selection state (only for Regular/Creator Feed)
  String _currentService = 'onlyfans';
  final TextEditingController _creatorIdController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // --- Tab Controller State ---
  late TabController _tabController;
  
  // --- State Variables for Popular Feed ---
  final List<R34Post> _popularPosts = []; 
  bool _popularLoading = false;
  String? _popularError;
  bool _popularHasFetched = false;

  // --- State Variables for Tag Search Feed (Global Search) ---
  final List<R34Post> _tagSearchPosts = [];
  bool _tagSearchLoading = false;
  final TextEditingController _tagSearchController = TextEditingController();
  bool _tagSearchHasMore = true;
  int _tagSearchCurrentPage = 0;

  // --- State Variables for Tag list feed. ---
  final List<KemonoTag> _commonTags = [];
  bool _tagsLoading = false;
  String? _tagsError;
  bool _tagsHasFetched = false;
  int _visibleTagCount = 50; 

  // --- API Constants ---
  // ⭐ Updated list to include common Coomer.st services
  final List<String> _services = [
    'onlyfans',
    'fansly',
    'candfans'

  ];
  // ⭐ Updated Base URL for Coomer.st
  final String _apiBaseUrl = 'https://coomer.st'; 
  final String _apiVersionPath = '/api/v1';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);

    WidgetsBinding.instance.addPostFrameCallback((_) {
    });
  }

  @override
  void dispose() {
    _httpClient.close();
    _creatorIdController.dispose();
    _searchController.dispose();
    _tagSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabSelection() {
    if (_tabController.index == 1 && !_popularHasFetched && !_popularLoading) {
      _fetchPopularPosts();
    } 
    else if (_tabController.index == 2 && !_tagsHasFetched && !_tagsLoading) {
      _fetchCommonTags();
    }
  }

  // ------------------------------------
  // --- API FETCH LOGIC ---
  // ------------------------------------

  Future<void> _fetchPosts({bool clearPrevious = false}) async {
    final String creatorId = _creatorIdController.text.trim();
    final String searchQuery = _searchController.text.trim();

    if (_isLoading) return;

    if (creatorId.isEmpty && searchQuery.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a Creator ID.')));
      }
      return;
    }

    if (searchQuery.isNotEmpty && creatorId.isEmpty) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search requires a Creator ID for the Creator Feed tab.')));
       }
       setState(() { _isLoading = false; });
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

    return await _performCreatorFetch(uri);
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

    return await _performCreatorFetch(uri, isPopularFeed: true); 
  }

  Future<void> _fetchCommonTags() async {
    if (_tagsLoading) return;
    
    final String path = '$_apiVersionPath/posts/tags';
    
    final Uri uri = Uri.https(
      _apiBaseUrl.replaceAll('https://', ''), 
      path,
    );
    
    setState(() {
      _tagsLoading = true;
      _tagsError = null;
    });

    try {
      log("Coomer.st GET URL (Tags): $uri"); // ⭐ Log name changed

      final response = await _httpClient.get(
        uri,
        headers: {'Accept': 'text/css'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawResponse = jsonDecode(response.body);

        final List<KemonoTag> newTags = rawResponse
            .map((tagJson) => KemonoTag.fromJson(tagJson))
            .toList();

        setState(() {
          _commonTags.clear();
          _commonTags.addAll(newTags);
          _tagsHasFetched = true;
          _tagsError = null;
          _visibleTagCount = 50.clamp(0, _commonTags.length); 
        });
      } else {
        log('HTTP Error (Tags): ${response.statusCode} - ${response.body}');
        setState(() => _tagsError = 'HTTP Error: ${response.statusCode}');
      }
    } catch (e, stack) {
      log('Fetch Error (Tags): $e\n$stack');
      setState(() => _tagsError = 'Network/Parsing Error');
    } finally {
      setState(() {
        _tagsLoading = false;
      });
    }
  }

  Future<void> _fetchTagSearchPosts({bool clearPrevious = false}) async {
    final String query = _tagSearchController.text.trim();

    if (_tagSearchLoading || query.isEmpty) {
      if (query.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a search query.')));
      }
      return;
    }

    setState(() {
      _tagSearchLoading = true;
      if (clearPrevious) {
        _tagSearchPosts.clear();
        _tagSearchCurrentPage = 0;
        _tagSearchHasMore = true;
      }
    });

    final int offset = _tagSearchCurrentPage * 50;
    final Map<String, dynamic> queryParams = {
      'o': offset.toString(),
      'q': query,
    };

    final String path = '$_apiVersionPath/posts'; // Global Posts endpoint

    final Uri uri = Uri.https(
      _apiBaseUrl.replaceAll('https://', ''),
      path,
      queryParams,
    );

    return await _performGlobalFetch(uri); 
  }
  
  Future<void> _performCreatorFetch(Uri uri, {bool isPopularFeed = false}) async {
    try {
      log("Coomer.st Creator/Popular GET URL: $uri"); // ⭐ Log name changed

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

Future<void> _performGlobalFetch(Uri uri) async {
  try {
    log("Coomer.st Global GET URL: $uri"); // ⭐ Log name changed

    final response = await _httpClient.get(
      uri,
      headers: {'Accept': 'text/css'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> rawResponse = jsonDecode(response.body);
      final List<dynamic> postsJson = rawResponse['posts'] ?? [];

      final List<R34Post> newPosts = postsJson
          .map((postJson) => _parseKemonoPost(postJson))
          .whereType<R34Post>()
          .toList();

      setState(() {
        _tagSearchPosts.addAll(newPosts);
        _tagSearchCurrentPage++;
        _tagSearchHasMore = newPosts.isNotEmpty;
      });
    } else {
      log('HTTP Error (Global): ${response.statusCode} - ${response.body}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error fetching global posts: ${response.statusCode}')));
      }
    }
  } catch (e, stack) {
    log('Fetch Error (Global): $e\n$stack');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A network or parsing error occurred for global search.')));
    }
  } finally {
    setState(() {
      _tagSearchLoading = false;
    });
  }
}


  // ------------------------------------
  // --- UI/WIDGET LOGIC ---
  // ------------------------------------

  // --- Post Parsing (Logic is identical for Coomer.st) ---
  R34Post? _parseKemonoPost(Map<String, dynamic> json) {
    String? filePath = json['file']?['path'];

    if (filePath == null && json['attachments'] is List && json['attachments'].isNotEmpty) {
      filePath = json['attachments'][0]?['path'];
    }

    if (filePath == null) {
      return null;
    }

    // ⭐ Uses the new _apiBaseUrl ('https://coomer.st')
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

  void _onSearchTapped() {
    _fetchPosts(clearPrevious: true);
  }

  void _onLoadMoreTapped() {
    _fetchPosts(clearPrevious: false);
  }
  
  void _onLoadMoreTags() {
    setState(() {
      _visibleTagCount = (_visibleTagCount + 50).clamp(0, _commonTags.length);
    });
  }

  void _onPostTapped(BuildContext context, R34Post post) {
    String creatorId;
    String service;
    
    if (_tabController.index == 1 || _tabController.index == 3) {
      creatorId = post.authUserId ?? '';
      service = post.authApiKey ?? '';
    } else { // Creator Feed (0)
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
        builder: (context) => CoomerPostScreen( // Assuming this is the common post detail screen
          postId: post.id,
          creatorId: creatorId,
          service: service,
        ),
      ),
    );
  }

  Widget _buildPostTile(R34Post post, String? imageUrl) {
    final Widget mediaContent = post.isAnyVideo
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam, color: Colors.white70, size: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    post.tagsString ?? 'Video', 
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
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
        color: const Color(0xFF303030),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: mediaContent,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            color: Colors.black54,
            child: Text(
              post.tagsString ?? 'Untitled Post',
              textAlign: TextAlign.start,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

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
              crossAxisCount: 3, 
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
        crossAxisCount: 3, 
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
  
  Widget _buildCommonTagsTab() {
    if (_tagsLoading && _commonTags.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tagsError != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Error loading tags: $_tagsError'),
          ElevatedButton(onPressed: _fetchCommonTags, child: const Text('Try Again')),
        ],
      ));
    }
    
    if (_commonTags.isEmpty && _tagsHasFetched) {
       return const Center(child: Text('No common tags found.'));
    }
    
    if (_commonTags.isEmpty && !_tagsHasFetched) {
        return Center(
          child: ElevatedButton(
            onPressed: _fetchCommonTags, 
            child: const Text('Load Common Tags')
          ),
        );
    }

    final List<KemonoTag> visibleTags = 
        _commonTags.sublist(0, _visibleTagCount);
    
    final bool hasMoreTags = _visibleTagCount < _commonTags.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Click a tag to search posts globally:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Wrap(
            spacing: 8.0, 
            runSpacing: 8.0, 
            children: visibleTags.map((tag) {
              return ActionChip(
                label: Text(
                  '${tag.tag} (${tag.postCount})',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.blueGrey,
                elevation: 2.0,
                onPressed: () {
                  _tagSearchController.text = tag.tag;
                  _tabController.animateTo(3);
                  _fetchTagSearchPosts(clearPrevious: true); 
                },
              );
            }).toList(),
          ),
          
          if (hasMoreTags)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Center(
                child: ElevatedButton(
                  onPressed: _onLoadMoreTags, 
                  child: const Text('Load More Tags (50)'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Search Global Posts (Tags/Title)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.text,
                  onSubmitted: (value) => _fetchTagSearchPosts(clearPrevious: true),
                ),
              ),
              const SizedBox(width: 8.0),
              ElevatedButton(
                onPressed: _tagSearchLoading ? null : () => _fetchTagSearchPosts(clearPrevious: true),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        
        if (_tagSearchLoading && _tagSearchPosts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 20.0),
            child: Center(child: CircularProgressIndicator()),
          ),
          
        if (!_tagSearchLoading && _tagSearchPosts.isEmpty && _tagSearchController.text.isNotEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.only(top: 20.0),
            child: Text('No results found for this query.'),
          )),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, 
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
            ),
            itemCount: _tagSearchPosts.length,
            itemBuilder: (context, index) {
              if (index >= _tagSearchPosts.length) {
                return const SizedBox.shrink(); 
              }
              
              final post = _tagSearchPosts[index];

              if (_tagSearchPosts.isNotEmpty && index == _tagSearchPosts.length - 1 && !_tagSearchLoading && _tagSearchHasMore) {
                _fetchTagSearchPosts(clearPrevious: false);
              }

              final imageUrl = post.previewUrl;

              return GestureDetector(
                onTap: () => _onPostTapped(context, post),
                child: _buildPostTile(post, imageUrl),
              );
            },
          ),
        ),

        if (_tagSearchLoading && _tagSearchPosts.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coomer Posts'), // ⭐ UI Title Changed
        bottom: TabBar( 
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Creator Feed'),
            Tab(icon: Icon(Icons.trending_up), text: 'Popular'), 
            Tab(icon: Icon(Icons.tag), text: 'Common Tags'),
            Tab(icon: Icon(Icons.search), text: 'Tag Search'), 
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegularTab(),
          _buildPopularTab(),
          _buildCommonTagsTab(),
          _buildTagSearchTab(),
        ],
      ),
    );
  }
}