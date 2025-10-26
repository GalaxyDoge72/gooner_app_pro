import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// HACK: Import R34Post and ImageScreen to navigate
// This allows us to "fake" a post object for the ImageScreen
// without having to modify ImageScreen at all.
import '../models/r34_post.dart';
import 'image_screen.dart'; // Adjust this import path as needed

class WaifuPicsScreen extends StatefulWidget {
  const WaifuPicsScreen({super.key});

  @override
  State<WaifuPicsScreen> createState() => _WaifuPicsScreenState();
}

class _WaifuPicsScreenState extends State<WaifuPicsScreen> {
  // --- State Variables ---
  final List<String> _postUrls = [];
  bool _isLoading = false;
  final http.Client _httpClient = http.Client();
  bool _hasMore = true; // waifu.pics can always load more

  // UI selection state
  String _currentType = 'sfw';
  String _currentCategory = 'waifu';

  // --- API Constants ---
  final List<String> _types = ['sfw', 'nsfw'];
  
  // SFW Categories from waifu.pics documentation
  final List<String> _sfwCategories = [
    'waifu', 'neko', 'shinobu', 'megumin', 'bully', 'cuddle', 'cry',
    'hug', 'awoo', 'kiss', 'lick', 'pat', 'smug', 'bonk', 'yeet',
    'blush', 'smile', 'wave', 'highfive', 'handhold', 'nom', 'bite',
    'glomp', 'slap', 'kill', 'kick', 'happy', 'wink', 'poke', 'dance',
    'cringe'
  ];

  // NSFW Categories per user request
  final List<String> _nsfwCategories = [
    'waifu', 'neko', 'trap', 'blowjob'
  ];

  // Helper getter to determine which list to show
  List<String> get _activeCategories {
    return _currentType == 'sfw' ? _sfwCategories : _nsfwCategories;
  }

  @override
  void initState() {
    super.initState();
    // Load initial data when the screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_postUrls.isEmpty) {
        _fetchPosts(clearPrevious: true);
      }
    });
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  // --- API Fetch Logic ---
  Future<void> _fetchPosts({bool clearPrevious = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (clearPrevious) {
        _postUrls.clear();
      }
    });

    final Uri uri = Uri.https(
        'api.waifu.pics', 'many/$_currentType/$_currentCategory');

    try {
      log("Waifu.pics POST URL: $uri");
      
      // The /many endpoint is a POST request
      final response = await _httpClient.post(
        uri,
        // Send an empty JSON body, as 'exclude' is optional
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<String> newUrls =
            List<String>.from(jsonResponse['files'] ?? []);

        setState(() {
          _postUrls.addAll(newUrls);
          // We can always assume there are more images
          _hasMore = true;
        });
      } else {
        log('HTTP Error: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error fetching images: ${response.statusCode}')));
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

  // --- Event Handlers ---
  void _onSearchTapped() {
    // A new search should clear existing posts
    _fetchPosts(clearPrevious: true);
  }

  void _onLoadMoreTapped() {
    // "Next Page" just fetches more images and appends them
    _fetchPosts(clearPrevious: false);
  }

  void _onPostTapped(BuildContext context, String postUrl) {
    // HACK: We create a "fake" R34Post object to send to the ImageScreen.
    // This makes it compatible with the existing screen's
    // 'if (post is R34Post)' logic.
    final fakePost = R34Post(
      // Create a fake ID from the filename
      id: postUrl.split('/').last.split('.').first,
      fileUrl: postUrl,
      previewUrl: postUrl, // Use file URL for preview
      tagsString: _currentCategory, // Pass the category as the "tags"
    );

    // Navigate directly to the ImageScreen widget instead of using a
    // named route. This allows us to pass all required arguments.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageScreen(
          post: fakePost,
          // We MUST lie and say the source is 'Rule34' so that
          // ImageScreen's logic `if (post is R34Post)` works
          // and it calls `_extractR34Tags`.
          source: 'Rule34',
          // We don't pass apiKey or userId, so the
          // _buildAuthenticatedUrl method will just return the
          // original fileUrl, which is what we want.
        ),
      ),
    );
  }

  // --- Build Method (XAML to Dart Conversion) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('waifu.pics'),
        // No settings button in this example, but you could add one
      ),
      body: Column(
        children: <Widget>[
          // --- Control Bar ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: <Widget>[
                // --- Type Dropdown ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _currentType,
                      items: _types.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != _currentType) {
                          setState(() {
                            _currentType = newValue;
                            
                            // Get the new list of categories
                            final newCategoryList = _activeCategories;
                            
                            // Check if the current category is in the new list.
                            // If not, reset to the first item in the new list.
                            if (!newCategoryList.contains(_currentCategory)) {
                              _currentCategory = newCategoryList.first;
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                
                // --- Category Dropdown ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _currentCategory,
                      // *** UPDATED: Use the _activeCategories getter ***
                      items: _activeCategories.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _currentCategory = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),

                // --- Buttons ---
                ElevatedButton(
                  onPressed: _onSearchTapped,
                  child: const Text('Search'),
                ),
                ElevatedButton(
                  onPressed: _isLoading || !_hasMore ? null : _onLoadMoreTapped,
                  child: const Text('Load More'),
                ),
              ],
            ),
          ),

          // --- Loading Indicator ---
          if (_isLoading && _postUrls.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // --- Image Grid ---
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // You can change this
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
              ),
              itemCount: _postUrls.length,
              itemBuilder: (context, index) {
                final postUrl = _postUrls[index];

                return GestureDetector(
                  onTap: () => _onPostTapped(context, postUrl),
                  child: Container(
                    color: const Color(0xFF303030), // Placeholder color
                    child: Image.network(
                      postUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
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
          
          // Show a small loading indicator at the bottom when loading more
          if (_isLoading && _postUrls.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}