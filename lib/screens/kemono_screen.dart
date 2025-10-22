import 'package:flutter/material.dart';
import '../models/kemono_post.dart';
import '../services/kemono_service.dart';

class KemonoScreen extends StatefulWidget {
  const KemonoScreen({super.key});

  @override
  State<KemonoScreen> createState() => _KemonoScreenState();
}

class _KemonoScreenState extends State<KemonoScreen> {
  final KemonoService _service = KemonoService();
  final List<KemonoPost> _posts = [];

  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _limit = 25;

  String? _selectedService;
  final TextEditingController _userIdController = TextEditingController();

  // Service options based on Kemono’s supported platforms
  final List<String> _services = [
    'patreon',
    'fanbox',
    'fantia',
    'boosty',
    'subscribestar',
    'dlsite',
  ];

  Future<void> _fetchPosts({bool reset = false}) async {
    if (_isLoading || _selectedService == null || _userIdController.text.isEmpty) return;

    if (reset) {
      _page = 0;
      _posts.clear();
      _hasMore = true;
    }

    setState(() => _isLoading = true);
    try {
      final newPosts = await _service.fetchPosts(
        service: _selectedService!,
        userId: _userIdController.text.trim(),
        page: _page,
        limit: _limit,
      );

      setState(() {
        _posts.addAll(newPosts);
        if (newPosts.length < _limit) _hasMore = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching posts: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadNextPage() {
    if (!_hasMore || _isLoading) return;
    _page++;
    _fetchPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kemono Browser'),
      ),
      body: Column(
        children: [
          // --- Top filter UI ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Service',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedService,
                  items: _services
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedService = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    labelText: 'Enter User ID',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 123456',
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _fetchPosts(reset: true),
                  icon: const Icon(Icons.search),
                  label: const Text('Fetch Posts'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // --- Content section ---
          Expanded(
            child: _posts.isEmpty
                ? Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('No posts yet.\nChoose a service and user ID.',
                            textAlign: TextAlign.center),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (scrollInfo) {
                      if (!_isLoading &&
                          _hasMore &&
                          scrollInfo.metrics.pixels ==
                              scrollInfo.metrics.maxScrollExtent) {
                        _loadNextPage();
                      }
                      return false;
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        final thumb = post.attachments.isNotEmpty
                            ? post.attachments.first.path
                            : null;
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    KemonoPostDetailScreen(post: post),
                              ),
                            );
                          },
                          child: Container(
                            color: Colors.grey[900],
                            child: thumb != null
                                ? Image.network(
                                    'https://kemono.cr/data${thumb}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.error),
                                  )
                                : const Icon(Icons.image_not_supported),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

// detail screen
class KemonoPostDetailScreen extends StatelessWidget {
  final KemonoPost post;

  const KemonoPostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final first = post.attachments.isNotEmpty ? post.attachments.first.path : '';
    final isVideo =
        first.toLowerCase().endsWith('.mp4') || first.toLowerCase().endsWith('.webm');

    return Scaffold(
      appBar: AppBar(title: Text(post.title)),
      body: Column(
        children: [
          Expanded(
            child: isVideo
                ? const Center(child: Text('Video playback coming soon'))
                : Image.network(
                    'https://kemono.cr/data$first',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.error),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Published: ${post.published}'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: Text(post.content ?? 'No description'),
            ),
          ),
        ],
      ),
    );
  }
}
