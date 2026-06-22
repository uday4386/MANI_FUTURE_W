import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import 'category_detail_screen.dart';
import '../widgets/news_detail_modal.dart';
import 'vertical_news_pager.dart';
import '../widgets/translated_text.dart';
import '../widgets/media_thumbnail_widget.dart';

class SearchScreen extends StatefulWidget {
  final String? selectedLanguage; // Telugu by default
  final Function(String)? onShortSelected;
  const SearchScreen({super.key, this.selectedLanguage, this.onShortSelected});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late Map<String, String> text;
  final TextEditingController _controller = TextEditingController();
  String query = '';
  
  // Category Metadata Mapping
  late List<Map<String, dynamic>> categories;

  @override
  void initState() {
    super.initState();
    _loadLanguageText();
  }

  void _loadLanguageText() {
    final lang = widget.selectedLanguage?.toLowerCase() ?? "తెలుగు";
    final isEnglish = lang.contains("english") || lang.contains("ఇంగ్లీష్");

    if (isEnglish) {
      text = {
        "title": "Search News",
        "hint": "Search news or shorts...",
        "trending": "Trending Categories",
        "recent": "Recent Searches",
        "noResults": "No results found",
      };
      categories = [
        {"id": "AndhraPradesh", "label": "Andhra Pradesh", "icon": Icons.location_city},
        {"id": "Telangana", "label": "Telangana", "icon": Icons.map},
        {"id": "National", "label": "National", "icon": Icons.flag},
        {"id": "International", "label": "International", "icon": Icons.public},
        {"id": "Crime", "label": "Crime Report", "icon": Icons.gavel},
        {"id": "Jobs", "label": "Jobs", "icon": Icons.work},
        {"id": "Business", "label": "Business", "icon": Icons.business},
        {"id": "Sports", "label": "Sports", "icon": Icons.sports_cricket},
      ];
    } else {
      text = {
        "title": "వార్తలు వెతకండి",
        "hint": "వార్తలు లేదా వీడియోలు వెతకండి...",
        "trending": "ట్రెండింగ్ వర్గాలు",
        "recent": "ఇటీవలి శోధనలు",
        "noResults": "ఫలితాలు కనబడలేదు",
      };
      categories = [
        {"id": "AndhraPradesh", "label": "ఆంధ్రప్రదేశ్", "icon": Icons.location_city},
        {"id": "Telangana", "label": "తెలంగాణ", "icon": Icons.map},
        {"id": "National", "label": "జాతీయం", "icon": Icons.flag},
        {"id": "International", "label": "అంతర్జాతీయ", "icon": Icons.public},
        {"id": "Crime", "label": "క్రైం రిపోర్ట్", "icon": Icons.gavel},
        {"id": "Jobs", "label": "ఉద్యోగం", "icon": Icons.work},
        {"id": "Business", "label": "వ్యాపారం", "icon": Icons.business},
        {"id": "Sports", "label": "క్రీడలు", "icon": Icons.sports_cricket},
      ];
    }
  }

  // Search Results
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  Future<void> _performSearch(String val) async {
    if (val.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final allNews = await ApiService.getNews();
      final allShorts = await ApiService.getShorts();
      
      final queryLower = val.toLowerCase();
      
      final newsList = allNews.where((n) {
        final title = (n['title'] ?? '').toString().toLowerCase();
        final desc = (n['description'] ?? '').toString().toLowerCase();
        return title.contains(queryLower) || desc.contains(queryLower);
      }).take(10).map((e) => Map<String, dynamic>.from(e)..['result_type'] = 'news').toList();
      
      final shortsList = allShorts.where((s) {
        final title = (s['title'] ?? '').toString().toLowerCase();
        return title.contains(queryLower);
      }).take(10).map((e) => Map<String, dynamic>.from(e)..['result_type'] = 'short').toList();

      if (mounted) {
        setState(() {
          _searchResults = [...newsList, ...shortsList];
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _navigateToCategory(Map<String, dynamic> category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
          categoryId: category['id'],
          categoryTitle: category['label'],
          count: "View all", // We don't have exact count here easily without fetch
          icon: category['icon'],
          selectedLanguage: widget.selectedLanguage ?? 'Telugu',
        ),
      ),
    );
  }

  void _openResult(Map<String, dynamic> item) {
    if (item['result_type'] == 'news') {
      final newsOnlyList = _searchResults.where((e) => e['result_type'] == 'news').toList();
      final index = newsOnlyList.indexWhere((e) => e['id'] == item['id']);
      if (index == -1) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerticalNewsPager(
            newsList: newsOnlyList,
            initialIndex: index,
            selectedLanguage: widget.selectedLanguage ?? 'Telugu',
          ),
        ),
      );
    } else if (item['result_type'] == 'short') {
      if (widget.onShortSelected != null) {
        Navigator.pop(context); // Close search
        widget.onShortSelected!(item['id'].toString());
      } else {
        // Fallback if no callback provided
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: _SimpleShortPlayer(videoUrl: item['video_url']),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double scale = (size.width / 390).clamp(0.85, 1.1);
    
    // Dynamic theme colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final accent = isDark ? const Color(0xFFFFC107) : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : Colors.black54;
    
    final isEnglish = widget.selectedLanguage != null &&
        (widget.selectedLanguage!.toLowerCase().contains("english") ||
            widget.selectedLanguage!.contains("ఇంగ్లీష్"));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          text["title"]!,
          style: TextStyle(
            color: textColor,
            fontSize: 18 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔍 Search Field
              TextField(
                controller: _controller,
                onChanged: (value) {
                  setState(() => query = value);
                  _performSearch(value);
                },
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: text["hint"],
                  hintStyle:
                  TextStyle(color: hintColor, fontSize: 14 * scale),
                  prefixIcon: Icon(Icons.search, color: hintColor),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: hintColor),
                    onPressed: () {
                      setState(() {
                        _controller.clear();
                        query = '';
                        _searchResults = [];
                      });
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF12355A) : Colors.black12,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12 * scale),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25 * scale),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 24 * scale),

              // 🔹 If search query is empty → show categories list
              if (query.isEmpty) ...[
                Text(
                  text["trending"]!,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16 * scale,
                  ),
                ),
                SizedBox(height: 12 * scale),

                ...categories.asMap().entries.map((entry) {
                  final i = entry.key + 1;
                  final category = entry.value;
                  return GestureDetector(
                    onTap: () => _navigateToCategory(category),
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 5 * scale),
                      padding: EdgeInsets.symmetric(
                          horizontal: 14 * scale, vertical: 10 * scale),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12 * scale),
                        border: Border.all(color: isDark ? Colors.transparent : Colors.black12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12 * scale,
                            backgroundColor: accent,
                            child: Text(
                              i.toString(),
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12 * scale,
                              ),
                            ),
                          ),
                          SizedBox(width: 10 * scale),
                          Expanded(
                            child: Text(
                              category['label'],
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14 * scale,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              color: hintColor, size: 14),
                        ],
                      ),
                    ),
                  );
                }),
                SizedBox(height: 28 * scale),
              ],

              // 🔍 Show search results
              if (query.isNotEmpty) ...[
                SizedBox(height: 20 * scale),
                Text(
                  isEnglish ? "Search Results" : "శోధన ఫలితాలు",
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16 * scale,
                  ),
                ),
                SizedBox(height: 12 * scale),
                if (_isSearching)
                  Center(child: CircularProgressIndicator(color: accent))
                else if (_searchResults.isEmpty)
                  Text(
                    text["noResults"]!,
                    style: TextStyle(color: hintColor, fontSize: 14 * scale),
                  )
                else
                  ..._searchResults.map((result) {
                    final isNews = result['result_type'] == 'news';
                    return GestureDetector(
                      onTap: () => _openResult(result),
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 5 * scale),
                        padding: EdgeInsets.symmetric(
                            horizontal: 14 * scale, vertical: 10 * scale),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12 * scale),
                          border: Border.all(color: isDark ? Colors.transparent : Colors.black12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 50 * scale,
                                height: 50 * scale,
                                child: MediaThumbnailWidget(
                                  item: result,
                                  width: 50 * scale,
                                  height: 50 * scale,
                                ),
                              ),
                            ),
                            SizedBox(width: 12 * scale),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TranslatedText(
                                    result['title'] ?? '',
                                    language: widget.selectedLanguage ?? 'Telugu',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14 * scale,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (isNews && result['description'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: TranslatedText(
                                         result['description'],
                                         language: widget.selectedLanguage ?? 'Telugu',
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                         style: TextStyle(color: hintColor, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
              SizedBox(height: 30 * scale),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleShortPlayer extends StatefulWidget {
  final String videoUrl;
  const _SimpleShortPlayer({required this.videoUrl});

  @override
  State<_SimpleShortPlayer> createState() => _SimpleShortPlayerState();
}

class _SimpleShortPlayerState extends State<_SimpleShortPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 500,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_initialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          else
            const CircularProgressIndicator(color: Colors.amber),
            
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

