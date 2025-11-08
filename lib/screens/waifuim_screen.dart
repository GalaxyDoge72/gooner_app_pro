import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:gooner_app_pro/screens/image_screen.dart';
import 'package:http/http.dart' as http;

import '../models/r34_post.dart';
import '../services/settings_service.dart';

class WaifuImScreen extends StatefulWidget {
  const WaifuImScreen({super.key});

  @override
  State<WaifuImScreen> createState() => _WaifuImScreenState();
}

class _WaifuImScreenState extends State<WaifuImScreen> {
  final List<String> _postUrls = [];
  bool _isLoading = false;
  final http.Client _httpClient = http.Client();
  bool _hasMore = true;
  SettingsService settings = SettingsService();

  bool _isNsfw = false;
  String _currentTag = "waifu";

  final TextEditingController _heightController = TextEditingController();
  String _minHeight = '';

  final List<String> _sfwTags = [
    'maid',
    'waifu',
    'marin-kitagawa',
    'mori-calliope',
    'raiden-shogun',
    'oppai',
    'selfies',
    'uniform',
    'kamisato-ayaka'
  ];

  final List<String> _nsfwTags = [
    'ass',
    'hentai',
    'milf',
    'oral',
    'paizuri',
    'ecchi',
    'ero'
  ];

  List<String> get _activeTags {
    return _isNsfw ? _nsfwTags : _sfwTags;
  }

  @override
  void initState() {
    super.initState();

    _currentTag = _sfwTags.first;

    _heightController.addListener(_updateHeightFilter);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_postUrls.isEmpty) {
        _fetchPosts(clearPrevious: true);
      }
    });
  }

  @override
  void dispose() {
    _httpClient.close();
    _heightController.dispose();
    super.dispose();
  }

  void _updateHeightFilter() {
    _minHeight = _heightController.text.trim();
  }

  void _onSearchTapped() {
    _fetchPosts(clearPrevious: true);
  }

  void _onLoadMoreTapped() {
    _fetchPosts(clearPrevious: false);
  }

  void _onPostTapped(BuildContext context, String postUrl) {
    final fakePost = R34Post(
      id: postUrl.split('/').last.split('.').first,
      fileUrl: postUrl,
      previewUrl: postUrl,
      tagsString: _currentTag
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageScreen(post: fakePost, source: "Rule34")
      )
    );
  }

  Future<void> _fetchPosts({bool clearPrevious = false}) async {
    if (_isLoading) {
      log('IsLoading is true. Returning early');
      return;
    }

    setState(() {
      _isLoading = true;
      if (clearPrevious) {
        _postUrls.clear();
      }
    });

    final Map<String, dynamic> queryParams = {
      'is_nsfw': _isNsfw.toString(),
      'selected_tags': [_currentTag],
      'limit': settings.waifuImPostAmount.toString()
    };

    if (_minHeight.isNotEmpty) {
      queryParams['height'] = _minHeight;
    }

    final Uri uri = Uri.https(
      'api.waifu.im',
      '/search',
      queryParams
    );

    try {
      log("Waifu.im GET URL: $uri");

      final response = await _httpClient.get(uri);

      if (response.statusCode == 200) { // Indicates successful fetch. //
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final List<dynamic> imageObjects = jsonResponse['images'] ?? [];

        final List<String> newUrls = imageObjects.map<String>((img) => img['url'].toString()).toList();

        setState(() {
          _postUrls.addAll(newUrls);
          _hasMore = newUrls.length == settings.waifuImPostAmount;
        });
      }
      else {
        log("HTTP Error: ${response.statusCode} - ${response.body}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("A network or parsing error occurred: ${response.statusCode}"))
          );
        }
      }
    }
    catch (e, stack) {
      log("Fetch error: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("A network error occurred: $e"))
        );
      }
    }
    finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('waifu.im'),
      ),
      body: Column(
        children: <Widget>[
          // --- Control Bar ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column( // Use Column for vertical layout of controls
              children: [
                // Row 1: SFW/NSFW Switch and Tag Dropdown
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    // --- Type Switch (SFW/NSFW) ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('SFW'),
                        Switch(
                          value: _isNsfw,
                          onChanged: (bool newValue) {
                            if (newValue != _isNsfw) {
                              setState(() {
                                _isNsfw = newValue;
                                
                                // Reset the current tag to the first in the new list
                                final newTagList = _activeTags;
                                if (!newTagList.contains(_currentTag)) {
                                  _currentTag = newTagList.first;
                                }
                              });
                            }
                          },
                        ),
                        const Text('NSFW'),
                      ],
                    ),
                    
                    // --- Tag Dropdown ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currentTag,
                          // Use the dynamically selected list of tags
                          items: _activeTags.map((String value) { 
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _currentTag = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8.0),
                
                // Row 2: Height Input and Buttons
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: [
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
                crossAxisCount: 2, 
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
              ),
              itemCount: _postUrls.length,
              itemBuilder: (context, index) {
                final postUrl = _postUrls[index];

                return GestureDetector(
                  onTap: () => _onPostTapped(context, postUrl),
                  child: Container(
                    color: const Color(0xFF303030),
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