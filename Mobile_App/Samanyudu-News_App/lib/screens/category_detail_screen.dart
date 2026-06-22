import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_service.dart';
import '../widgets/news_detail_modal.dart';
import '../widgets/translated_text.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../widgets/media_thumbnail_widget.dart';
import 'vertical_news_pager.dart';

/// Shows clear info about a category when tapped from the Categories page.
/// Fetches and displays the list of news articles for that category.
class CategoryDetailScreen extends StatefulWidget {
  final String categoryId; // The DB value for 'type' column
  final String categoryTitle; // Display title
  final String count;
  final IconData icon; // Display icon
  final String selectedLanguage;

  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    required this.count,
    required this.icon,
    required this.selectedLanguage,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _categoryNews = [];
  
  static const bgColor = Color(0xFF041627);
  static const cardColor = Color(0xFF132F4C);  

  static const iconBg = Color(0xFF1E446B);
  static const accentYellow = Color(0xFFFFC107);

  // Voice & Actions
  final SpeechService _speech = SpeechService();
  dynamic _playingItemId;
  bool _ttsPlaying = false;

  final Set<String> _likedPosts = {};
  Set<String> _savedIds = {};

  Future<void> _loadSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _savedIds = (prefs.getStringList('saved_news_ids') ?? []).toSet();
      });
    }

    // final user = Supabase.instance.client.auth.currentUser;
    // if (user != null) {
    //   try {
    //     final res = await Supabase.instance.client
    //         .from('news_likes')
    //         .select('news_id')
    //         .eq('user_id', user.id);
    //     if (mounted) {
    //       setState(() {
    //         _likedPosts.clear();
    //         _likedPosts.addAll((res as List).map((row) => row['news_id'].toString()));
    //       });
    //     }
    //   } catch (e) {
    //     debugPrint("Error fetching category user likes: $e");
    //   }
    // } else {
      if (mounted) {
         setState(() {
            _likedPosts.clear();
            _likedPosts.addAll(prefs.getStringList('liked_news_ids') ?? []);
         });
      }
    // }
  }

  Future<void> _toggleSave(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    
    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
    await prefs.setStringList('saved_news_ids', _savedIds.toList());
    
    // Sync with backend if logged in
    if (userId != null && userId.isNotEmpty) {
      try {
        await ApiService.saveItem(userId, id, 'news', _savedIds.contains(id));
      } catch (e) {
        debugPrint("Error syncing category saved news: $e");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _speech.init();
    _fetchCategoryNews();
    _loadSavedIds();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _fetchCategoryNews() async {
    try {
      final response = await ApiService.getNews();

      if (mounted) {
        setState(() {
          final allNews = response.map((e) => Map<String, dynamic>.from(e)).toList();
          
          // Improved filtering with synonyms and trimming
          _categoryNews = allNews.where((n) {
            final type = (n['type'] as String?)?.trim() ?? '';
            final targetId = widget.categoryId.trim();
            
            if (targetId.toLowerCase() == 'marriage') {
              // Match various marriage synonyms across languages/normalization
              const synonyms = ['marriage', 'పెళ్లి పందిరి', 'పెళ్ళి పందిరి', 'pelli pandiri', 'వివాహ వేడుక', 'vivaha veduka'];
              return synonyms.contains(type.toLowerCase());
            }
            
            if (targetId.toLowerCase() == 'classifieds') {
              // Match various classifieds synonyms
              const synonyms = ['classifieds', 'క్లాసిఫైడ్స్', 'jobs', 'ఉద్యోగాలు', 'ఉద్యోగం', 'real estate', 'రియల్ ఎస్టేట్', 'house rent'];
              return synonyms.contains(type.toLowerCase());
            }
            
            if (targetId.toLowerCase() == 'live') {
              // Match explicitly marked 'live' items OR any item with a live link
              final liveLink = n['live_link']?.toString() ?? '';
              return type.toLowerCase() == 'live' || liveLink.isNotEmpty;
            }
            
            return type.toLowerCase() == targetId.toLowerCase();
          }).toList();
          
          _loading = false;
          
          if (widget.categoryId.toLowerCase() == 'live' && _categoryNews.isNotEmpty) {
            // No inline playing in category detail screen as requested.
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching category news: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    if (widget.selectedLanguage.toLowerCase().contains('english')) {
      final diff = DateTime.now().difference(dateTime);
      if (diff.inDays > 0) return "${diff.inDays}d ago";
      if (diff.inHours > 0) return "${diff.inHours}h ago";
      if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
      return "Just now";
    } else {
      final diff = DateTime.now().difference(dateTime);
      if (diff.inDays > 0) return "${diff.inDays} రోజుల క్రితం";
      if (diff.inHours > 0) return "${diff.inHours} గంటల క్రితం";
      if (diff.inMinutes > 0) return "${diff.inMinutes} నిమిషాల క్రితం";
      return "ఇప్పుడే";
    }
  }

  Future<void> _handleSpeak(Map<String, dynamic> item) async {
    final id = item['id'];
    if (_playingItemId == id && _ttsPlaying) {
      _speech.cancel();
      if (mounted) setState(() => _ttsPlaying = false);
      return;
    }

    _speech.cancel();

    final text = "${item['title'] ?? ''}. ${item['description'] ?? ''}";
    final isTelugu = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
    final isHindi = RegExp(r'[\u0900-\u097f]').hasMatch(text);
    String lang = "en-US";
    if (isTelugu) {
      lang = "te-IN";
    } else if (isHindi) {
      lang = "hi-IN";
    }

    if (mounted) {
      setState(() {
        _playingItemId = id;
        _ttsPlaying = true;
      });
    }

    _speech.speak(
      text: text,
      lang: lang,
      rate: 0.9,
      pitch: 1.0,
      onComplete: () {
        if (mounted) {
          setState(() {
          _ttsPlaying = false;
          _playingItemId = null;
        });
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() {
          _ttsPlaying = false;
          _playingItemId = null;
        });
        }
      },
    );
  }

  void _handleLike(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final bool isLiked = _likedPosts.contains(id);
    setState(() {
      if (isLiked) {
        _likedPosts.remove(id);
      } else {
        _likedPosts.add(id);
      }
    });

    // final user = Supabase.instance.client.auth.currentUser;
    // if (user != null) {
    //   try {
    //      if (isLiked) {
    //          await Supabase.instance.client.from('news_likes').delete().match({'user_id': user.id, 'news_id': id});
    //      } else {
    //          await Supabase.instance.client.from('news_likes').insert({'user_id': user.id, 'news_id': id});
    //      }
    //   } catch (e) {
    //      debugPrint("Error updating category like record: $e");
    //   }
    // } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('liked_news_ids', _likedPosts.toList());

      try {
        await ApiService.likeNews(id, 'guest_${DateTime.now().millisecondsSinceEpoch}', !isLiked);
      } catch (e) {
        debugPrint("Error updating category news likes: $e");
      }
    // }
  }

  void _handleShare(Map<String, dynamic> item) {
    final title = item['title'] ?? '';
    final description = item['description'] ?? '';
    Share.share("$title\n\n$description", subject: title);
  }

  void _viewNewsDetail(Map<String, dynamic> item) {
     _speech.cancel();
     if (mounted) setState(() => _ttsPlaying = false);

     final index = _categoryNews.indexOf(item);
     if (index == -1) return;

     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => VerticalNewsPager(
           newsList: _categoryNews,
           initialIndex: index,
           selectedLanguage: widget.selectedLanguage,
         ),
       ),
     ).then((_) => _loadSavedIds());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double scale = (size.width / 390).clamp(0.85, 1.15);
    final isEnglish = widget.selectedLanguage.toLowerCase().contains("english") ||
        widget.selectedLanguage.contains("ఇంగ్లీష్");

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final iconBg = isDark ? const Color(0xFF1E446B) : Colors.grey[200];
    const accentYellow = Color(0xFFFFC107);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;
    
    final noNewsText = isEnglish ? "No news in this category yet." : "ఈ వర్గంలో ఇంకా వార్తలు లేవు.";

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryTitle,
          style: TextStyle(
            color: textColor,
            fontSize: 18 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header Card
              Container(
                width: double.infinity,
                margin: EdgeInsets.all(16 * scale),
                padding: EdgeInsets.all(16 * scale),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16 * scale),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12 * scale),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12 * scale),
                      ),
                      child: Icon(widget.icon, color: accentYellow, size: 30 * scale),
                    ),
                    SizedBox(width: 16 * scale),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.categoryTitle,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18 * scale,
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          widget.count, // e.g "5 news"
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 14 * scale,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Inline video player removed per user request.
              
              Expanded(
                child: _loading 
                  ? Center(child: CircularProgressIndicator(color: accentYellow))
                  : _categoryNews.isEmpty 
                      ? Center(child: Text(noNewsText, style: TextStyle(color: subTextColor, fontSize: 14 * scale)))
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                          itemCount: _categoryNews.length,
                          itemBuilder: (context, index) {
                            final item = _categoryNews[index];
                            final timestamp = DateTime.tryParse(item['timestamp'] ?? '') ?? DateTime.now();
                            // Helper internal since removed from class? No, define it or use inline logic?
                            // Wait, _getTimeAgo is MISSING too! I need to restore that or rewrite it.
                            // I'll rewrite it inline or as a helper method.
                            
                            final timeAgo = _getTimeAgo(timestamp);
                            
                            final isLiked = _likedPosts.contains(item['id'].toString());
                            final isPlaying = _playingItemId == item['id'] && _ttsPlaying;

                            return GestureDetector(
                              onTap: () => _viewNewsDetail(item),
                              child: Container(
                                margin: EdgeInsets.only(bottom: 14 * scale),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16 * scale),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Image Thumbnail
                                        ClipRRect(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(16 * scale),
                                          ),
                                          child: Container(
                                            width: 100 * scale,
                                            height: 100 * scale,
                                            color: const Color(0xFF12355A),
                                            child: MediaThumbnailWidget(
                                              item: item,
                                              width: 100 * scale,
                                              height: 100 * scale,
                                            ),
                                          ),
                                        ),
                                        
                                        // Content
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.all(12 * scale),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                TranslatedText(
                                                  item['title'] ?? '',
                                                  language: widget.selectedLanguage,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: 14 * scale,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                SizedBox(height: 8 * scale),
                                                Row(
                                                  children: [
                                                    Icon(Icons.access_time, color: subTextColor, size: 12 * scale),
                                                    SizedBox(width: 4 * scale),
                                                    Text(
                                                      timeAgo,
                                                      style: TextStyle(
                                                        color: subTextColor,
                                                        fontSize: 11 * scale,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Action Buttons Row (Like, Share, Voice)
                                    Container(
                                       padding: EdgeInsets.symmetric(vertical: 8 * scale),
                                       decoration: BoxDecoration(
                                         border: Border(top: BorderSide(color: Colors.white10)),
                                       ),
                                       child: Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                         children: [
                                           _buildActionButton(
                                              icon: isLiked ? Icons.favorite : Icons.favorite_border,
                                              label: isEnglish ? "Like" : "లైక్",
                                              onTap: () => _handleLike(item),
                                              isActive: isLiked,
                                              color: Colors.red,
                                              scale: scale,
                                           ),
                                           _buildActionButton(
                                              icon: _savedIds.contains(item['id'].toString()) ? Icons.bookmark : Icons.bookmark_border,
                                              label: isEnglish ? (_savedIds.contains(item['id'].toString()) ? "Saved" : "Save") : "సేవ్",
                                              onTap: () => _toggleSave(item),
                                              isActive: _savedIds.contains(item['id'].toString()),
                                              color: accentYellow,
                                              scale: scale,
                                           ),
                                           _buildActionButton(
                                              icon: Icons.share,
                                              label: isEnglish ? "Share" : "షేర్",
                                              onTap: () => _handleShare(item),
                                              isActive: false,
                                              color: subTextColor,
                                              scale: scale,
                                           ),
                                            _buildActionButton(
                                              icon: isPlaying ? Icons.stop : Icons.volume_up,
                                              label: isEnglish ? "Voice" : "వాయిస్",
                                              onTap: () => _handleSpeak(item),
                                              isActive: isPlaying,
                                              color: accentYellow,
                                              scale: scale,
                                           ),
                                         ],
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
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
    required Color color,
    required double scale,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 4 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? color : (isDark ? const Color(0xFFFFC107) : Colors.black87),
                size: 18 * scale,
              ),
              SizedBox(width: 6 * scale),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? color : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 12 * scale,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


