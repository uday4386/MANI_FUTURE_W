import 'package:flutter/material.dart';
import 'index.dart';
import 'index_v2.dart';
import 'categories.dart';
import 'alerts.dart';
import 'videos.dart';
import 'profile.dart';
import 'dart:async';
// import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../widgets/ad_dialog.dart';
import '../services/speech_service.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vertical_news_pager.dart';

class MainNavigation extends StatefulWidget {
  final String selectedLanguage;
  const MainNavigation({super.key, required this.selectedLanguage});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  final GlobalKey<VideosPageState> _videosKey = GlobalKey();
  final GlobalKey<IndexScreenV2State> _indexKey = GlobalKey();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey();

  /// Kept in state so tabs (e.g. Videos) stay mounted and keep running when switching.
  List<Widget>? _screens;

  List<Map<String, dynamic>> _ads = [];
  final Map<String, Timer> _adTimers = {};

  void _onShortSelected(String shortId) {
    setState(() => currentIndex = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videosKey.currentState?.jumpToShort(shortId);
    });
  }


  @override
  void didUpdateWidget(MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLanguage != widget.selectedLanguage) {
      // Re-initialize screens with the new language
      _initScreens();
    }
  }

  void _initScreens() {
    setState(() {
      _screens = [
        IndexScreenV2(
          key: _indexKey,
          selectedLanguage: widget.selectedLanguage,
          onNotificationTap: () => setState(() => currentIndex = 3),
          onShortSelected: _onShortSelected,
        ),
        CategoriesScreen(selectedLanguage: widget.selectedLanguage),
        VideosPage(key: _videosKey, selectedLanguage: widget.selectedLanguage),
        AlertsScreen(selectedLanguage: widget.selectedLanguage),
        ProfileScreen(key: _profileKey, selectedLanguage: widget.selectedLanguage),
      ];
    });
  }

  @override
  void initState() {
    super.initState();
    _initScreens();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingDeepLink();
    });
  }

  void _checkPendingDeepLink() async {
    if (NotificationService.pendingArticleId != null) {
      final articleId = NotificationService.pendingArticleId!;
      NotificationService.pendingArticleId = null; // Clear it

      try {
        final article = await ApiService.getNewsItem(articleId);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerticalNewsPager(
                newsList: [article],
                initialIndex: 0,
                selectedLanguage: widget.selectedLanguage,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint("Pending deep link failed: $e");
      }
    }
  }

  Future<void> _fetchAds() async {
    try {
      final res = await ApiService.getAdvertisements();

      if (mounted) {
        setState(() {
          // Filter out inactive ads just in case
          _ads = res.where((ad) => ad['is_active'] == true).map((e) => Map<String, dynamic>.from(e)).toList();
        });
        // _setupAdTimers(); // Disabled in favor of In-Feed ads
      }
    } catch (e) {
      debugPrint("Ads fetch error: $e");
    }
  }

  void _setupAdTimers() {
    for (final timer in _adTimers.values) {
      timer.cancel();
    }
    _adTimers.clear();

    bool isFirstAdShown = false;

    for (var ad in _ads) {
      final intervalMinutes = ad['interval_minutes'] ?? 15;
      final String adId = ad['id'].toString();
      
      if (!isFirstAdShown) {
         // Show the first active ad quickly for demonstration
         Timer(const Duration(seconds: 15), () {
            if (mounted) _showAdDialog(ad);
         });
         isFirstAdShown = true;
      }

      // Schedule subsequent ads based on their interval
      _adTimers[adId] = Timer.periodic(Duration(minutes: (intervalMinutes as num).toInt()), (_) {
         if (mounted) _showAdDialog(ad);
      });
    }
  }

  void _showAdDialog(Map<String, dynamic> ad) async {
    // Popup ads disabled
    return;
  }

  @override
  void dispose() {
    for (final timer in _adTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  List<BottomNavigationBarItem> get _navItems => [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: _isEnglish ? "Home" : "హోమ్",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.grid_view_outlined),
      activeIcon: Icon(Icons.grid_view),
      label: _isEnglish ? "News" : "వార్తలు",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.video_library_outlined),
      activeIcon: Icon(Icons.video_library),
      label: _isEnglish ? "Videos" : "వీడియోలు",
    ),
    BottomNavigationBarItem(
      icon: ValueListenableBuilder<int>(
        valueListenable: NotificationService.updateCount,
        builder: (context, count, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none),
            if (count > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                    child: Text(
                      count > 9 ? "9+" : "$count",
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      activeIcon: const Icon(Icons.notifications),
      label: _isEnglish ? "Alerts" : "నోటిఫికేషన్స్",
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: _isEnglish ? "Profile" : "ప్రొఫైల్",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmall = size.height < 700;      // simple breakpoint
    final double iconSize = isSmall ? 18 : 22;   // smaller icons
    final double fontSize = isSmall ? 9 : 11;
    final double barHeight = isSmall ? 70 : 76; // Increased from 54/60 to prevent overflow

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Use theme color
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: _screens ?? [],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, // Use theme card color or nav bar specific
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconSize: iconSize, // base icon size [web:35]
                selectedIconTheme: IconThemeData(size: iconSize + 2),
                unselectedIconTheme: IconThemeData(size: iconSize),
                selectedItemColor: const Color(0xFFFFC107),
                unselectedItemColor: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                selectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: fontSize,
                ),
                showUnselectedLabels: true,
                currentIndex: currentIndex,
                onTap: (i) {
                  SpeechService().cancel(); // Stop playing voice when switching tabs
                  setState(() => currentIndex = i);
                  if (i == 3) {
                    NotificationService.updateCount.value = 0;
                    SharedPreferences.getInstance().then((prefs) {
                       final latestId = _indexKey.currentState?.latestClassifiedId;
                       if (latestId != null) {
                         prefs.setString('last_seen_classified_id', latestId);
                       }
                    });
                  }
                  
                  if (i == 0) {
                     _indexKey.currentState?.onTabActive();
                  } else {
                     _indexKey.currentState?.onTabInactive();
                  }

                  if (i == 2) {
                     _videosKey.currentState?.refreshData();
                     _videosKey.currentState?.onTabActive();
                  } else {
                     _videosKey.currentState?.onTabInactive();
                  }
                  if (i == 4) {
                     _profileKey.currentState?.loadSavedData();
                  }
                },
                items: _navItems,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
