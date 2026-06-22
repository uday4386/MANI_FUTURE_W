import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'vertical_news_pager.dart';
import '../widgets/translated_text.dart';
import '../widgets/media_thumbnail_widget.dart';
import 'saved_shorts_player.dart';

class SavedItemsScreen extends StatefulWidget {
  final String selectedLanguage;
  const SavedItemsScreen({super.key, required this.selectedLanguage});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _savedNews = [];
  List<Map<String, dynamic>> _savedShorts = [];
  bool _isLoading = true;

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSavedItems();
  }

  Future<void> _fetchSavedItems() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final newsIds = prefs.getStringList('saved_news_ids') ?? [];
    final shortsIds = prefs.getStringList('saved_shorts_ids') ?? [];

    try {
      if (newsIds.isNotEmpty) {
        final allNews = await ApiService.getNews();
        _savedNews = allNews
            .where((n) => newsIds.contains(n['id'].toString()))
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (shortsIds.isNotEmpty) {
        final allShorts = await ApiService.getShorts();
        _savedShorts = allShorts
            .where((s) => shortsIds.contains(s['id'].toString()))
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint("Error fetching saved items: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final appBarColor = isDark ? const Color(0xFF0B2A45) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final unselectedLabelColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: Text(_isEnglish ? "Saved Items" : "సేవ్ చేసినవి", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFFC107),
          unselectedLabelColor: unselectedLabelColor,
          indicatorColor: const Color(0xFFFFC107),
          tabs: [
            Tab(text: _isEnglish ? "News" : "వార్తలు"),
            Tab(text: _isEnglish ? "Shorts" : "వీడియోలు"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: const Color(0xFFFFC107)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNewsList(),
                _buildShortsList(),
              ],
            ),
    );
  }

  Widget _buildNewsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white54 : Colors.black54;

    if (_savedNews.isEmpty) {
      return Center(
        child: Text(
          _isEnglish ? "No saved news" : "సేవ్ చేసిన వార్తలు లేవు",
          style: TextStyle(color: textColor),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _savedNews.length,
      itemBuilder: (context, index) {
        final item = _savedNews[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = Theme.of(context).cardColor;
        final titleColor = isDark ? Colors.white : Colors.black87;
        final descColor = isDark ? Colors.white54 : Colors.black54;

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: SizedBox(
                width: 60,
                height: 60,
                child: MediaThumbnailWidget(
                  item: item,
                  width: 60,
                  height: 60,
                ),
            ),
            title: TranslatedText(
              item['title'] ?? '',
              language: widget.selectedLanguage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: TranslatedText(
              item['description'] ?? '',
              language: widget.selectedLanguage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: descColor, fontSize: 12),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getString('user_id');
                final newsIds = prefs.getStringList('saved_news_ids') ?? [];
                final id = item['id'].toString();
                newsIds.remove(id);
                await prefs.setStringList('saved_news_ids', newsIds);
                setState(() {
                  _savedNews.removeAt(index);
                });
                
                if (userId != null && userId.isNotEmpty) {
                    try {
                        await ApiService.saveItem(userId, id, 'news', false);
                    } catch (e) {
                        debugPrint("Error unsaving news on backend: $e");
                    }
                }
              },
            ),
            onTap: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (context) => VerticalNewsPager(
                     newsList: _savedNews,
                     initialIndex: index,
                     selectedLanguage: widget.selectedLanguage,
                   ),
                 ),
               ).then((_) => _fetchSavedItems());
            },
          ),
        );
      },
    );
  }

  Widget _buildShortsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white54 : Colors.black54;
    
    if (_savedShorts.isEmpty) {
      return Center(
        child: Text(
          _isEnglish ? "No saved shorts" : "సేవ్ చేసిన వీడియోలు లేవు",
          style: TextStyle(color: textColor),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.6,
      ),
      itemCount: _savedShorts.length,
      itemBuilder: (context, index) {
        final item = _savedShorts[index];
        return GestureDetector(
          onTap: () {
             Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (_) => SavedShortsPlayer(
                   shorts: _savedShorts,
                   initialIndex: index,
                   selectedLanguage: widget.selectedLanguage,
                 ),
               ),
             ).then((_) => _fetchSavedItems());
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              image: const DecorationImage(
                image: NetworkImage("https://via.placeholder.com/150"),
                fit: BoxFit.cover,
              )
            ),
             child: Stack(
              children: [
                Center(child: Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.8), size: 40)),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black54,
                    child: Text(
                      item['title'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final userId = prefs.getString('user_id');
                        final shortsIds = prefs.getStringList('saved_shorts_ids') ?? [];
                        final id = item['id'].toString();
                        shortsIds.remove(id);
                        await prefs.setStringList('saved_shorts_ids', shortsIds);
                        setState(() {
                          _savedShorts.removeAt(index);
                        });
                        
                        if (userId != null && userId.isNotEmpty) {
                            try {
                                await ApiService.saveItem(userId, id, 'shorts', false);
                            } catch (e) {
                                debugPrint("Error unsaving short on backend: $e");
                            }
                        }
                    },
                    child: const CircleAvatar(backgroundColor: Colors.black45, radius: 14, child: Icon(Icons.delete, size: 16, color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
