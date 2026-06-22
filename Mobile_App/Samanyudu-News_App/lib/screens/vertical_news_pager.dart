import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/full_page_article_card.dart';

class VerticalNewsPager extends StatefulWidget {
  final List<Map<String, dynamic>> newsList;
  final int initialIndex;
  final String selectedLanguage;

  const VerticalNewsPager({
    super.key,
    required this.newsList,
    required this.initialIndex,
    required this.selectedLanguage,
  });

  @override
  State<VerticalNewsPager> createState() => _VerticalNewsPagerState();
}

class _VerticalNewsPagerState extends State<VerticalNewsPager> {
  late PageController _pageController;
  late int _currentIndex;
  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadUserStates();
  }

  Future<void> _loadUserStates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _likedIds.addAll(prefs.getStringList('liked_news_ids') ?? []);
      _savedIds.addAll(prefs.getStringList('saved_news_ids') ?? []);
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final isLiked = _likedIds.contains(id);
    
    setState(() {
      if (isLiked) {
        _likedIds.remove(id);
        item['likes'] = (item['likes'] ?? 0) > 0 ? (item['likes'] ?? 0) - 1 : 0;
      } else {
        _likedIds.add(id);
        item['likes'] = (item['likes'] ?? 0) + 1;
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('liked_news_ids', _likedIds.toList());
    
    try {
      final userId = prefs.getString('user_id') ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final newCount = await ApiService.likeNews(id, userId, !isLiked);
      
      if (mounted) {
        setState(() {
          item['likes'] = newCount;
        });
      }
    } catch (e) {
      debugPrint("Error syncing like in pager: $e");
    }
  }

  Future<void> _toggleSave(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final isSaved = _savedIds.contains(id);
    
    setState(() {
      if (isSaved) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_news_ids', _savedIds.toList());
    
    try {
      final userId = prefs.getString('user_id');
      if (userId != null) {
        await ApiService.saveItem(userId, id, 'news', !isSaved);
      }
    } catch (e) {
      debugPrint("Error syncing save in pager: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))),
      );
    }

    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.newsList.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = widget.newsList[index];
          return FullPageArticleCard(
            item: item,
            selectedLanguage: widget.selectedLanguage,
            isLiked: _likedIds.contains(item['id'].toString()),
            isSaved: _savedIds.contains(item['id'].toString()),
            pageController: _pageController,
            onLike: () => _toggleLike(item),
            onSave: () => _toggleSave(item),
            onBack: () => Navigator.pop(context),
          );
        },
      ),
    );
  }
}
