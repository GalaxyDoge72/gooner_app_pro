import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';

import 'package:gooner_app_pro/models/e621_post.dart';
import 'package:gooner_app_pro/models/root_object.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../settings_service.dart'; // Contains SettingsService

class E621Screen extends StatefulWidget {
  const E621Screen({super.key});

  @override
  State<E621Screen> createState() => _E621ScreenState();
}

class _E621ScreenState extends State<E621Screen> {
  // --- State Variables (C# to Dart Conversion) ---
  final List<E621Post> _posts = [];
  int _currentPage = 1;
  bool _isLoading = false;
  final http.Client _httpClient = http.Client();
  int _postsPerPage = 25; 
  bool _hasMore = true;
  String _currentTags = 'rating:safe'; // Matches C# debug logic
  
  // Controller for the TagBox (Entry)
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tagController.text = _currentTags; 
    
    // Equivalent of the C# `Appearing` event logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  // Equivalent of the C# E621Screen_Appearing logic
  void _loadInitialData() {
    // We listen: false here because we only need to read the initial value.
    final settings = Provider.of<SettingsService>(context, listen: false);
    _postsPerPage = settings.e621PostAmount;
    
    if (_posts.isEmpty) {
      _fetchPosts(_currentTags);
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _httpClient.close();
    super.dispose();
  }

  // --- API Fetch Logic (C# FetchPosts conversion) ---
  Future<void> _fetchPosts(String tags) async {
    if (_isLoading || !_hasMore) return;

    Provider.of<SettingsService>(context, listen: false);

    setState(() {
      _isLoading = true;
      if (_currentPage == 1) _posts.clear(); 
    });

    final Uri uri = Uri.https('e621.net', '/posts.json', {
      'limit': _postsPerPage.toString(),
      'page': _currentPage.toString(),
      'tags': tags,
    });
    
    try {
      log("Using URL: $uri");
      final response = await _httpClient.get(
        uri, 
        // User-Agent is mandatory for e621
        headers: {'User-Agent': 'E621Flutter/1.0 (by GoonerApp)'}
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        
        // Use the generated RootObject model to parse the response
        final RootObject root = RootObject.fromJson(jsonResponse); 
        final List<E621Post> newPosts = root.posts;

        setState(() {
          _posts.addAll(newPosts);
          _hasMore = newPosts.length == _postsPerPage; // Check if the page was full
        });
       
      } else {
        log('HTTP Error: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching posts: ${response.statusCode}'))
          );
        }
      }

    } catch (e, stack) {
      log('Fetch Error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A network or parsing error occurred.'))
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Event Handlers (C# methods conversion) ---
  void _searchTapped(String tags) {
    if (tags.trim().isEmpty) return;
    _currentTags = tags;
    _currentPage = 1; // Reset page on new search
    _fetchPosts(tags);
  }
  
  void _prevPageTapped() {
    if (_currentPage > 1) { 
      _currentPage--;
      _posts.clear(); // Clear posts before loading the previous page
      _fetchPosts(_currentTags);
    }
  }

  void _nextPageTapped() {
    if (!_hasMore) return;
    _currentPage++;
    _posts.clear(); // Clear posts before loading the next page
    _fetchPosts(_currentTags);
  }
  
  void _onPostTapped(BuildContext context, E621Post post) {
  // Use a generic name for navigation consistency across providers
  Navigator.pushNamed(
                      context,
                      '/image_screen',
                      arguments: post,
                    );
}

  // --- Build Method (XAML to Dart Conversion) ---
  @override
  Widget build(BuildContext context) {
    void onSettingsTapped() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SettingsScreenPlaceholder(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('e621.net'),
        // ToolbarItem Text="Settings"
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: onSettingsTapped,
          ),
        ],
      ),
      // Grid RowDefinitions="Auto, *" -> Column with Expanded
      body: Column(
        children: <Widget>[
          // HorizontalStackLayout Grid.Row="0" Margin="8" -> Padding with Row
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                // Entry x:Name="TagBox"
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Enter tags...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    onSubmitted: _searchTapped, // Completed="TagBox_Completed"
                  ),
                ),
                const SizedBox(width: 8.0),
                // Button x:Name="SearchButton"
                ElevatedButton(
                  onPressed: () => _searchTapped(_tagController.text), 
                  child: const Text('Search'),
                ),
                // Button x:Name="prevPageButton"
                Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: ElevatedButton(
                    onPressed: _prevPageTapped, 
                    child: const Text('<'),
                  ),
                ),
                // Button x:Name="nextPageButton"
                Padding(
                  padding: const EdgeInsets.only(left: 10.0),
                  child: ElevatedButton(
                    onPressed: _nextPageTapped, 
                    child: const Text('>'),
                  ),
                ),
              ],
            ),
          ),

          // LoadingBar equivalent 
          if (_isLoading && _posts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // CollectionView Grid.Row="1" -> Expanded GridView
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

                return GestureDetector(
                  onTap: () => _onPostTapped(context, post),
                  // Grid item wrapper
                  child: Container(
                    // PlaceholderGray #303030
                    color: const Color(0xFF303030), 
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        
                        // Placeholder Label IsVisible="{Binding IsInvalidOrNullEntry}"
                        if (post.isInvalidOrNullEntry)
                          const Center(
                            child: Text(
                              'INVALID',
                              style: TextStyle(
                                // TextColor="#999999"
                                color: Color(0xFF999999), 
                                fontSize: 16,
                              ),
                            ),
                          ),

                        // Image Source="{Binding PreviewUrl}" IsVisible="{Binding IsInvalidOrNullEntry, Converter={StaticResource InvertBoolConverter}}"
                        if (!post.isInvalidOrNullEntry)
                          Image.network(
                            post.previewUrl ?? '',
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) => 
                              const Center(child: Icon(Icons.broken_image, color: Colors.white70)),
                          ),

                        // MP4 Label IsVisible="{Binding IsVideo}"
                        if (post.isVideo)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              // BackgroundColor="#80000000"
                              color: const Color(0x80000000), 
                              child: const Text(
                                'MP4',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // WEBM Label IsVisible="{Binding IsWebmVideo}"
                        if (post.isWebmVideo)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              // BackgroundColor="#80000000"
                              color: const Color(0x80000000), 
                              child: const Text(
                                'WEBM',
                                style: TextStyle(
                                  // TextColor="#FFF17105"
                                  color: Color(0xfffff17105), 
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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

// --- Placeholder Classes for Navigation ---
class SettingsScreenPlaceholder extends StatelessWidget {
  const SettingsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Settings')), body: const Center(child: Text('Settings Screen Placeholder')));
  }
}
// Assuming e621Post is imported from post_models.dart
class ImageScreenPlaceholder extends StatelessWidget {
  final E621Post post; 
  const ImageScreenPlaceholder({super.key, required this.post});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('Post ${post.id}')), body: const Center(child: Text('Image Viewer Screen Placeholder')));
  }
}