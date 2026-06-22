import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'search_screen.dart';
import 'post_news_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_service.dart';
import '../widgets/news_detail_modal.dart';
import '../widgets/translated_text.dart';
import '../widgets/media_thumbnail_widget.dart';
import '../data/locations.dart';
import 'package:translator/translator.dart';
import '../services/share_service.dart';
import '../widgets/app_logo.dart';
import 'location_screen.dart';
import 'category_detail_screen.dart';
import '../services/notification_service.dart';
import 'vertical_news_pager.dart';

class IndexScreenV2 extends StatefulWidget {
  final String selectedLanguage;
  final VoidCallback? onNotificationTap;
  final Function(String)? onShortSelected;

  const IndexScreenV2({
    super.key,
    required this.selectedLanguage,
    this.onNotificationTap,
    this.onShortSelected,
  });

  @override
  IndexScreenV2State createState() => IndexScreenV2State();
}

class IndexScreenV2State extends State<IndexScreenV2> with WidgetsBindingObserver {
  void _onThemeChanged() {
    if (mounted) setState(() {});
  }
  late Map<String, String> text;
  List<Map<String, dynamic>> _breakingNewsList = [];
  final ScrollController _breakingScrollController = ScrollController();
  Timer? _breakingScrollTimer;

  // Job Alert Scroll State
  final ScrollController _jobAlertScrollController = ScrollController();
  Timer? _jobAlertScrollTimer;

  List<Map<String, dynamic>> _realNews = [];
  List<Map<String, dynamic>> _ads = [];
  List<Map<String, dynamic>> _mixedFeed = [];
  bool _newsLoading = true;
  bool _isOffline = false;
  bool _hasNewNotifications = false;
  Map<String, dynamic>? _latestClassifiedAlert;

  // Voice over: uses browser Speech Synthesis on web (clear Telugu/English), Flutter TTS on mobile
  final SpeechService _speech = SpeechService();
  dynamic _playingItemId;
  bool _ttsPlaying = false;
  double _currentSpeechRate = 1.0;
  bool _isActive = true;
  final Set<String> _likedPosts = {};
  Set<String> _savedIds = {};
  // RealtimeChannel? _realtimeSubscription;

  String? _userCity;
  String? _userDistrict;
  String? _userState;
  
  int _jobCount = 0;
  int _marriageCount = 0;
  int _classifiedCount = 0;
  
  bool _hasNewClassifieds = false;
  bool _hasNewMarriage = false;
  bool _hasNewLive = false;
  
  int _lastVisitClassifieds = 0;
  int _lastVisitMarriage = 0;
  int _lastVisitLive = 0;

  bool get isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  Future<void> _loadUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? oldCity = _userCity;
    
    if (mounted) {
      setState(() {
        _savedIds = (prefs.getStringList('saved_news_ids') ?? []).toSet();
        _userCity = prefs.getString('user_city');
        _userDistrict = prefs.getString('user_district');
        _userState = prefs.getString('user_state');
        _lastVisitClassifieds = prefs.getInt('last_visit_classifieds') ?? 0;
        _lastVisitMarriage = prefs.getInt('last_visit_marriage') ?? 0;
        _lastVisitLive = prefs.getInt('last_visit_live') ?? 0;
      });
    }

    // Refresh weather if city changed or on initial load
    if (_userCity != oldCity) {
      debugPrint("City updated from $oldCity to $_userCity, refreshing weather...");
      _fetchWeather();
    }

    if (mounted) {
       setState(() {
          _likedPosts.clear();
          _likedPosts.addAll(prefs.getStringList('liked_news_ids') ?? []);
       });
    }
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
        debugPrint("Error syncing saved news: $e");
      }
    }
  }

  Future<void> _initTtsLocal() async {
    await _speech.init();
  }

  Future<void> _handleSpeak(Map<String, dynamic> item) async {
    final id = item['id'];
    if (_playingItemId == id && _ttsPlaying) {
      _speech.cancel();
      if (mounted) setState(() => _ttsPlaying = false);
      return;
    }

    _speech.cancel();
    if (mounted) {
      setState(() {
        _playingItemId = id;
        _ttsPlaying = true;
      });
    }

    String text = "${item['title'] ?? ''}. ${item['description'] ?? ''}";

    // Check if target language is Telugu
    final isTeluguSelected =
        widget.selectedLanguage.contains('తెలుగు') ||
        widget.selectedLanguage.toLowerCase().contains('telugu');

    if (isTeluguSelected) {
      final hasTeluguChars = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
      if (!hasTeluguChars) {
        try {
          final translator = GoogleTranslator();
          final translation = await translator.translate(text, to: 'te');
          text = translation.text;
        } catch (e) {
          debugPrint("Translation failed for list item: $e");
        }
      }
    } else {
      // Target English
      final hasTeluguChars = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
      if (hasTeluguChars) {
        try {
          final translator = GoogleTranslator();
          final translation = await translator.translate(text, to: 'en');
          text = translation.text;
        } catch (e) {
          debugPrint("Translation failed for list item: $e");
        }
      }
    }

    // Determine language code for TTS
    final isTelugu = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
    final isHindi = RegExp(r'[\u0900-\u097f]').hasMatch(text);
    String lang = "en-US";
    if (isTelugu) {
      lang = "te-IN";
    } else if (isHindi) {
      lang = "hi-IN";
    }

    if (!mounted) return;

    _speech.speak(
      text: text,
      lang: lang,
      rate: _currentSpeechRate,
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

  Future<void> _handleLike(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final isLiked = _likedPosts.contains(id);

    setState(() {
      if (isLiked) {
        _likedPosts.remove(id);
        item['likes'] = (item['likes'] ?? 0) > 0 ? (item['likes'] ?? 0) - 1 : 0;
      } else {
        _likedPosts.add(id);
        item['likes'] = (item['likes'] ?? 0) + 1;
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    
    await prefs.setStringList('liked_news_ids', _likedPosts.toList());
    
    try {
      final effectiveUserId = (userId != null && userId.isNotEmpty) 
          ? userId 
          : (prefs.getString('guest_id') ?? 'guest_${DateTime.now().millisecondsSinceEpoch}');
      
      if (userId == null && !prefs.containsKey('guest_id')) {
        await prefs.setString('guest_id', effectiveUserId);
      }

      final newCount = await ApiService.likeNews(id, effectiveUserId, !isLiked);
      
      // Update local item with server truth
      if (mounted) {
        setState(() {
          item['likes'] = newCount;
        });
      }
    } catch (e) {
      debugPrint("Error updating news likes: $e");
    }
  }

  void _handleShare(Map<String, dynamic> item) {
    ShareService.showShareOptions(context, item, widget.selectedLanguage);
  }

  Future<void> _fetchNews() async {
    try {
      final response = await ApiService.getNews();
      final adsResponse = await ApiService.getAdvertisements();
      
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final lastSeenId = prefs.getString('last_seen_classified_id');

        setState(() {
          // Safety Filter: Only allow 'published' news or legacy items with null status
          _realNews = response
              .where((item) {
                final s = item['status']?.toString().toLowerCase();
                return s == 'published' || s == null || s == '';
              })
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _ads = adsResponse.where((ad) => ad['is_active'] == true).map((e) => Map<String, dynamic>.from(e)).toList();
          
          _mixedFeed = [];
          int adIndex = 0;
          int itemsSinceLastAd = 0;
          for (int i = 0; i < _realNews.length; i++) {
            _mixedFeed.add({..._realNews[i], 'feed_type': 'news'});
            itemsSinceLastAd++;
            
            if (_ads.isNotEmpty) {
              final ad = _ads[adIndex % _ads.length];
              int interval = ad['display_interval'] ?? 4;
              if (itemsSinceLastAd >= interval) {
                _mixedFeed.add({...ad, 'feed_type': 'ad'});
                adIndex++;
                itemsSinceLastAd = 0;
              }
            }
          }
          
          _newsLoading = false;
          _isOffline = ApiService.lastFetchOffline;
          
          // Update breaking news list if any
          final breaking = _realNews
              .where((n) => n['is_breaking'] == true)
              .toList();
          if (breaking.isNotEmpty) {
            _breakingNewsList = breaking;
          }

          // Trigger Classified Alert logic
          final classifieds = _realNews.where((n) {
            final t = n['type']?.toString().toLowerCase();
            return t == 'jobs' || t == 'ఉద్యోగాలు' ||
                   t == 'classifieds' || t == 'క్లాసిఫైడ్స్' ||
                   t == 'real estate' || t == 'house rent' || t == 'రియల్ ఎస్టేట్';
          }).toList();

          _jobCount = _realNews.where((n) {
            final t = n['type']?.toString().toLowerCase();
            return t == 'jobs' || t == 'ఉద్యోగాలు';
          }).length;
          
          _marriageCount = _realNews.where((n) {
            final t = n['type']?.toString().toLowerCase();
            return t == 'marriage' || t == 'పెళ్ళి పందిరి' || t == 'వివాహ వేడుక';
          }).length;
          
          _classifiedCount = _realNews.where((n) {
            final t = n['type']?.toString().toLowerCase();
            const synonyms = ['classifieds', 'క్లాసిఫైడ్స్', 'jobs', 'ఉద్యోగాలు', 'ఉద్యోగం', 'real estate', 'రియల్ ఎస్టేట్', 'house rent'];
            return synonyms.contains(t);
          }).length;

          // Notification dots logic
          _hasNewClassifieds = _realNews.any((n) {
            final t = n['type']?.toString().toLowerCase();
            if (t == 'jobs' || t == 'ఉద్యోగాలు') {
               final ts = DateTime.tryParse(n['timestamp'] ?? '')?.millisecondsSinceEpoch ?? 0;
               return ts > _lastVisitClassifieds;
            }
            return false;
          });
          
          _hasNewMarriage = _realNews.any((n) {
            final t = n['type']?.toString().toLowerCase();
            if (t == 'marriage' || t == 'పెళ్ళి పందిరి' || t == 'వివాహ వేడుక') {
               final ts = DateTime.tryParse(n['timestamp'] ?? '')?.millisecondsSinceEpoch ?? 0;
               return ts > _lastVisitMarriage;
            }
            return false;
          });

          _hasNewLive = _realNews.any((n) {
            final t = n['type']?.toString().toLowerCase();
            final l = n['live_link']?.toString() ?? '';
            if (t == 'live' || l.isNotEmpty) {
               final ts = DateTime.tryParse(n['timestamp'] ?? '')?.millisecondsSinceEpoch ?? 0;
               return ts > _lastVisitLive;
            }
            return false;
          });

          if (classifieds.isNotEmpty) {
            final latest = classifieds.first;
            final latestId = latest['id'].toString();
            
            if (lastSeenId != null && lastSeenId != latestId) {
              _hasNewNotifications = true;
            }
            
            _latestClassifiedAlert = latest;
            // We only update lastSeenId when they visit the notification page
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching news/ads: $e");
      if (mounted) {
        setState(() {
           _isOffline = ApiService.lastFetchOffline;
           _newsLoading = false;
        });
      }
    }
  }

  void _onNotificationUpdate() {
    if (mounted) {
      _fetchNews();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themeNotifier.addListener(_onThemeChanged);
    _initTtsLocal();
    _loadLanguageText();
    WidgetsBinding.instance.addPostFrameCallback((_) async { 
      _startBreakingNewsScroll();
      _startJobAlertScroll();
      await _loadUserPrefs();
      _fetchNews();
      _setupRealtimeSubscription();
    });
    NotificationService.updateCount.addListener(_onNotificationUpdate);
  }

  String? get latestClassifiedId => _latestClassifiedAlert?['id']?.toString();
  
  @override
  void onTabActive() {
    setState(() => _isActive = true);
  }

  void onTabInactive() {
    setState(() => _isActive = false);
    if (_ttsPlaying) {
      _speech.cancel();
      setState(() => _ttsPlaying = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_ttsPlaying) {
        _speech.cancel();
        setState(() => _ttsPlaying = false);
      }
    }
  }

  @override
  void didUpdateWidget(IndexScreenV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLanguage != widget.selectedLanguage) {
      _loadLanguageText();
      _fetchNews(); // Re-fetch or at least re-process news for potential translation changes
    }
  }

  void _setupRealtimeSubscription() {
    // Supabase realtime is currently unplugged while migrating backends.
    // For now, poll or rely on pull-to-refresh
  }

  // Weather State
  bool _weatherLoading = true;
  double? _temperature;
  int? _weatherCode;
  List<dynamic>? _hourlyTemps;
  List<dynamic>? _hourlyCodes;

  Future<void> _fetchWeather() async {
    try {
      if (mounted) setState(() => _weatherLoading = true);

      // 1. If we have a manually selected city, prioritize Geocoding it
      if (_userCity != null && _userCity!.isNotEmpty) {
        debugPrint("Attempting geocoding for selected city: $_userCity");
        try {
          final geoUrl = Uri.parse(
            "https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(_userCity!)}&count=1&language=en&format=json",
          );
          final geoRes = await http.get(geoUrl);
          if (geoRes.statusCode == 200) {
            final geoData = json.decode(geoRes.body);
            if (geoData["results"] != null && geoData["results"].isNotEmpty) {
              final result = geoData["results"][0];
              final double lat = result["latitude"];
              final double lon = result["longitude"];
              debugPrint("Geocoding success for $_userCity: $lat, $lon");
              await _getWeatherForLocation(lat, lon);
              return;
            }
          }
        } catch (e) {
          debugPrint("Geocoding failed for $_userCity: $e");
        }
      }

      // 2. Fallback to GPS if no city or geocoding failed
      debugPrint("Getting current GPS position...");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
        _useFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permissions are denied");
          _useFallbackLocation();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied");
        _useFallbackLocation();
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        debugPrint("Error getting precise location: $e");
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        debugPrint("Position is null, using fallback.");
        _useFallbackLocation();
        return;
      }

      debugPrint("Got GPS position: ${position.latitude}, ${position.longitude}");
      await _getWeatherForLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("Error in _fetchWeather: $e");
      _useFallbackLocation();
    }
  }

  void _useFallbackLocation() {
    debugPrint("Using fallback location (Vijayawada)");
    _getWeatherForLocation(16.5062, 80.6480);
  }

  Future<void> _getWeatherForLocation(double lat, double lon) async {
    try {
      final url = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&hourly=temperature_2m,weathercode&forecast_days=1",
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data["current_weather"];
        final hourly = data["hourly"];
        
        if (mounted) {
          setState(() {
            _temperature = current["temperature"];
            _weatherCode = current["weathercode"];
            _hourlyTemps = hourly["temperature_2m"];
            _hourlyCodes = hourly["weathercode"];

            _weatherLoading = false;
          });
        }
      } else {
        debugPrint("Weather API error: ${response.statusCode}");
        if (mounted) setState(() => _weatherLoading = false);
      }
    } catch (e) {
       debugPrint("API Exception: $e");
       if (mounted) setState(() => _weatherLoading = false);
    }
  }

  void _showWeatherHover(BuildContext context, double scale) {
    if (_hourlyTemps == null) return;
    
    // Get current hour index
    final now = DateTime.now();
    int currentHour = now.hour;
    
    // Take next 5 hours
    List<Map<String, dynamic>> next5Hours = [];
    for (int i = 0; i < 5; i++) {
      int idx = currentHour + i;
      if (idx < _hourlyTemps!.length) {
        next5Hours.add({
          "time": "${(idx % 24).toString().padLeft(2, '0')}:00",
          "temp": _hourlyTemps![idx],
          "code": _hourlyCodes![idx],
        });
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogColor = isDark
        ? const Color(0xFF0B2740).withOpacity(0.95)
        : Colors.white.withOpacity(0.95);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.black87 : Colors.black12;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned(
            top: 100 * scale,
            left: 100 * scale,
            right: 50 * scale,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(12 * scale),
                decoration: BoxDecoration(
                  color: dialogColor,
                  borderRadius: BorderRadius.circular(12 * scale),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Next 5 Hours",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12 * scale,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: next5Hours.map((h) {
                         return Column(
                           children: [
                            Text(
                              h["time"],
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 10 * scale,
                              ),
                            ),
                             SizedBox(height: 4 * scale),
                            Icon(
                              _getWeatherIcon(h["code"]),
                              color: isDark ? Colors.white : Colors.black87,
                              size: 16 * scale,
                            ),
                             SizedBox(height: 4 * scale),
                            Text(
                              "${h["temp"]}°",
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11 * scale,
                              ),
                            ),
                           ],
                         );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(int? code) {
    if (code == null) return Icons.wb_sunny;
    if (code == 0) return Icons.wb_sunny;
    if (code >= 1 && code <= 3) return Icons.cloud;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain; // rain/drizzle
    if (code >= 71 && code <= 77) return Icons.ac_unit; // snow
    if (code >= 80 && code <= 82) return Icons.tsunami; // showers
    if (code >= 95) return Icons.flash_on; // thunderstorm
    return Icons.wb_cloudy;
  }

  @override
  void dispose() {
    NotificationService.updateCount.removeListener(_onNotificationUpdate);
    WidgetsBinding.instance.removeObserver(this);
    themeNotifier.removeListener(_onThemeChanged);
    // if (_realtimeSubscription != null) {
    //   Supabase.instance.client.removeChannel(_realtimeSubscription!);
    // }
    _speech.cancel();
    _breakingScrollTimer?.cancel();
    _breakingScrollController.dispose();
    _jobAlertScrollTimer?.cancel();
    _jobAlertScrollController.dispose();
    super.dispose();
  }

  void _startBreakingNewsScroll() {
    debugPrint("Starting breaking news scroll timer...");
    _breakingScrollTimer?.cancel();
    _breakingScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (
      _,
    ) {
      if (!_breakingScrollController.hasClients || !mounted) return;
      final pos = _breakingScrollController.position;
      final maxExtent = pos.maxScrollExtent;
      if (maxExtent <= 0) return;
      double next = _breakingScrollController.offset + 1.0; // Slower scroll
      if (next >= maxExtent) {
        debugPrint("Resetting ticker scroll to 0");
        next = 0;
      }
      _breakingScrollController.jumpTo(next);
    });
  }

  void _startJobAlertScroll() {
    _jobAlertScrollTimer?.cancel();
    _jobAlertScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_jobAlertScrollController.hasClients || !mounted) return;
      final pos = _jobAlertScrollController.position;
      final maxExtent = pos.maxScrollExtent;
      if (maxExtent <= 0) return;
      double next = _jobAlertScrollController.offset + 2.0;
      if (next >= maxExtent) next = 0;
      _jobAlertScrollController.jumpTo(next);
    });
  }

  void _showSpeedMenu(BuildContext context) {
    final speeds = [0.5, 0.75, 1.0, 1.25];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final chipBg = isDark ? const Color(0xFF12355A) : Colors.black12;
    final chipText = isDark ? Colors.white70 : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Playback Speed",
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: speeds.map((speed) {
                  final isSelected = speed == _currentSpeechRate;
                  return ActionChip(
                    label: Text("${speed}x"),
                    backgroundColor: isSelected
                        ? Colors.black87
                        : chipBg,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : chipText,
                      fontWeight: FontWeight.bold,
                    ),
                    onPressed: () {
                      setState(() => _currentSpeechRate = speed);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _loadLanguageText() {
    final lang = widget.selectedLanguage.toLowerCase();

    if (lang.contains("english") || lang.contains("ఇంగ్లీష్")) {
      text = {
        "breaking": "BREAKING",
        "breakingMsg": "Heavy rain in Vijayawada – View latest updates",
        "location": "Vijayawada",
        "district": "Guntur District, AP",
        "postNews": "Post News",
        "postTitle": "Post a New News Article",
        "hintTitle": "Title...",
        "hintDesc": "Description...",
        "posted": "News Submitted!",
        "categoryPolitics": "Politics",
        "categoryBusiness": "Business",
        "timeAgo": "ago",
        "jobs": "Jobs",
        "marriage": "Vivaha Veduka",
        "classifieds": "Classifieds",
        "live": "LIVE",
      };
      _breakingNewsList = [
        {
          "title": "Welcome to Samanyudu TV - Local News at your fingertips",
          "type": "General",
          "description":
              "Stay updated with real-time news from Guntur district and surrounding areas.",
        },
      ];
    } else {
      text = {
        "breaking": "బ్రేకింగ్",
        "breakingMsg": "విజయవాడలో భారీ వర్షం - తాజా ప్రకటనలు చూడండి",
        "location": "విజయవాడ",
        "district": "గుంటూరు జిల్లా, ఆంధ్రప్రదేశ్",
        "postNews": "వార్త పోస్ట్ చేయండి",
        "postTitle": "క్రొత్త వార్తను పోస్ట్ చేయండి",
        "hintTitle": "శీర్షిక...",
        "hintDesc": "వివరణ...",
        "posted": "వార్త పంపబడింది!",
        "categoryPolitics": "రాజకీయాలు",
        "categoryBusiness": "వ్యాపారం",
        "timeAgo": "క్రితం",
        "jobs": "ఉద్యోగాలు",
        "marriage": "వివాహ వేడుక",
        "classifieds": "క్లాసిఫైడ్స్",
        "live": "లైవ్",
      };
      _breakingNewsList = [
        {
          "title":
              "సామాన్యుడు టీవీకి స్వాగతం - మీ చేతివేళ్ల వద్ద స్థానిక వార్తలు",
          "type": "ఇతరం",
          "description":
              "గుంటూరు జిల్లా మరియు పరిసర ప్రాంతాల నుండి రియల్ టైమ్ వార్తలతో అప్డేట్ అవ్వండి.",
        },
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildNewUI(context);
  }

  void _viewNewsDetail(Map<String, dynamic> item) {
    debugPrint("Opening news detail for item: ${item['title']}");
    
    // Filter news items from mixed feed to maintain continuity in pager
    final newsOnlyList = _mixedFeed
        .where((e) => e['feed_type'] == 'news')
        .toList();
    
    final index = newsOnlyList.indexWhere((e) => e['id'] == item['id']);
    if (index == -1) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerticalNewsPager(
          newsList: newsOnlyList,
          initialIndex: index,
          selectedLanguage: widget.selectedLanguage,
        ),
      ),
    ).then((_) {
      debugPrint("Vertical pager closed");
      _loadUserPrefs();
    });
  }

  // 🔍 Open Search
  void _openSearchSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          selectedLanguage: widget.selectedLanguage,
          onShortSelected: widget.onShortSelected,
        ),
      ),
    ).then((_) => _loadUserPrefs());
  }

  // 📰 Post News Sheet
  void _openPostSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PostNewsScreen(selectedLanguage: widget.selectedLanguage),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (isEnglish) {
      if (diff.inDays > 0) return "${diff.inDays}d ago";
      if (diff.inHours > 0) return "${diff.inHours}h ago";
      if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
      return "Just now";
    } else {
      if (diff.inDays > 0) return "${diff.inDays} రోజుల క్రితం";
      if (diff.inHours > 0) return "${diff.inHours} గంటల క్రితం";
      if (diff.inMinutes > 0) return "${diff.inMinutes} నిమిషాల క్రితం";
      return "ఇప్పుడే";
    }
  }

  String _getCategoryDisplayName(String? type) {
    if (type == null) return isEnglish ? 'General' : 'సాధారణం';
    final t = type.toLowerCase();
    
    // Match internal DB types to translated names
    if (t == 'andhrapradesh') return isEnglish ? 'Andhra Pradesh' : 'ఆంధ్రప్రదేశ్';
    if (t == 'telangana') return isEnglish ? 'Telangana' : 'తెలంగాణ';
    if (t == 'national') return isEnglish ? 'National' : 'జాతీయం';
    if (t == 'international') return isEnglish ? 'International' : 'అంతర్జాతీయ';
    if (t == 'crime') return isEnglish ? 'Crime Report' : 'క్రైం రిపోర్ట్';
    if (t == 'education') return isEnglish ? 'Education' : 'విద్య';
    if (t == 'jobs') return isEnglish ? 'Jobs' : 'ఉద్యోగం';
    if (t == 'business') return isEnglish ? 'Business' : 'వ్యాపారం';
    if (t == 'sports') return isEnglish ? 'Sports' : 'క్రీడలు';
    if (t == 'agriculture') return isEnglish ? 'Agriculture' : 'వ్యవసాయం';
    if (t == 'marriage' || t == 'పెళ్ళి పందిరి' || t == 'పెళ్లి పందిరి' || t == 'pelli pandiri') return isEnglish ? 'Vivaha Veduka' : 'వివాహ వేడుక';
    if (t == 'realestate') return isEnglish ? 'Real Estate' : 'రియల్ ఎస్టేట్';
    if (t == 'bhakthi') return isEnglish ? 'Bhakthi' : 'భక్తి';
    if (t == 'health') return isEnglish ? 'Health' : 'ఆరోగ్యం';
    if (t == 'political') return isEnglish ? 'Politics' : 'రాజకీయాలు';
    if (t == 'classifieds') return isEnglish ? 'Classifieds' : 'క్లాసిఫైడ్స్';
    if (t == 'social') return isEnglish ? 'Social' : 'సామాజిక';
    if (t == 'accident') return isEnglish ? 'Accident' : 'ప్రమాదం';
    
    return type.toUpperCase();
  }

  IconData _getCategoryIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'political':
        return Icons.account_balance;
      case 'business':
        return Icons.work;
      case 'sports':
        return Icons.sports_cricket;
      case 'weather':
        return Icons.wb_sunny;
      case 'crime':
        return Icons.gavel;
      case 'classifieds':
        return Icons.campaign;
      case 'jobs':
        return Icons.work;
      case 'real estate':
        return Icons.house;
      default:
        return Icons.newspaper;
    }
  }

  Widget _buildAdCard(Map<String, dynamic> ad, double scale) {
    final isDark = themeNotifier.value == ThemeMode.dark || 
                  (themeNotifier.value == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final cardColor = isDark ? const Color(0xFF112F4A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final url = ad['media_url'];
    final isVideo = url != null && (url.toString().contains('.mp4') || url.toString().contains('.webm') || url.toString().contains('.ogg'));

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ad Label
          Padding(
            padding: EdgeInsets.all(8 * scale),
            child: Row(
              children: [
                Icon(Icons.ad_units, color: Colors.amber, size: 14 * scale),
                SizedBox(width: 6 * scale),
                Text(
                  isEnglish ? "ADVERTISEMENT" : "ప్రకటన",
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          
          // Media
          if (isVideo && url != null)
            _MutedAdPlayer(
              videoUrl: url, 
              scale: scale,
              isActive: _isActive,
              onUnmute: () {
                if (_ttsPlaying) {
                  _speech.cancel();
                  setState(() => _ttsPlaying = false);
                }
              },
            )
          else if (url != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8 * scale),
              child: Image.network(
                ApiService.normalizeUrl(url),
                height: 200 * scale,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  height: 200 * scale,
                  color: Colors.white10,
                  child: Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            ),
            
          // Content
          Padding(
            padding: EdgeInsets.all(12 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad['title'] ?? (isEnglish ? 'Sponsored Content' : 'ప్రాయోజిత కంటెంట్'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (ad['description'] != null) ...[
                  SizedBox(height: 6 * scale),
                  Text(
                    ad['description'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 13 * scale,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewUI(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double scale = (size.width / 390).clamp(0.85, 1.15);
    final isDark = themeNotifier.value == ThemeMode.dark || 
                  (themeNotifier.value == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final bgColor = isDark ? const Color(0xFF041627) : const Color(0xFFF2F5F8); 
    final topBgColor = isDark ? const Color(0xFF0B2A45) : const Color(0xFFFFC107);
    
    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 100 * scale),
        child: FloatingActionButton(
          heroTag: "fab_post",
          backgroundColor: const Color(0xFFFFC107),
          elevation: 4,
          onPressed: _openPostSheet,
          child: const Icon(Icons.edit, color: Colors.black, size: 22),
        ),
      ),
      body: Container(
        decoration: isDark ? const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B2A45), Color(0xFF041627)],
          ),
        ) : null,
        child: Stack(
          children: [
            if (!isDark)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 140 * scale,
                child: Container(
                  color: topBgColor,
                ),
              ),
          
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetchWeather();
                await _fetchNews();
                await _loadUserPrefs();
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 10 * scale, bottom: 2 * scale),
                          child: Center(child: AppLogo(fontSize: 42 * scale)),
                        ),
                        if (_isOffline)
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10 * scale),
                              border: Border.all(color: Colors.orange.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off, color: Colors.orange, size: 16 * scale),
                                SizedBox(width: 8 * scale),
                                Text(
                                  isEnglish ? "Offline Mode: Showing Cached News" : "ఆఫ్‌లైన్ మోడ్: సేవ్ చేసిన వార్తలు చూస్తున్నారు",
                                  style: TextStyle(color: Colors.orange, fontSize: 12 * scale, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16 * scale),
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF112F4A) : Colors.white,
                            borderRadius: BorderRadius.circular(30 * scale),
                            boxShadow: [
                              BoxShadow(color: isDark ? Colors.black45 : Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                            ]
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: const Color(0xFFFFC107), size: 20 * scale),
                              SizedBox(width: 8 * scale),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LocationScreen(
                                        selectedLanguage: widget.selectedLanguage,
                                      ),
                                    ),
                                  ).then((_) => _loadUserPrefs());
                                },
                                child: Builder(
                                  builder: (context) {
                                    String displayCity = _userCity ?? text["location"]!;
                                    if ((widget.selectedLanguage == "తెలుగు" || widget.selectedLanguage == "Telugu") &&
                                        _userCity != null && _userState != null && _userDistrict != null) {
                                      if (locationData.containsKey(_userState) && locationData[_userState]!.containsKey(_userDistrict)) {
                                        int idx = locationData[_userState]![_userDistrict]!.indexOf(_userCity!);
                                        if (idx != -1 && locationDataTelugu.containsKey(_userState) && locationDataTelugu[_userState]!.containsKey(_userDistrict)) {
                                          var list = locationDataTelugu[_userState]![_userDistrict];
                                          if (list != null && idx < list.length) {
                                            displayCity = list[idx];
                                          }
                                        }
                                      }
                                    } else if ((widget.selectedLanguage == "తెలుగు" || widget.selectedLanguage == "Telugu") && _userCity == null) {
                                      displayCity = "విజయవాడ";
                                    }
                                    return Text(
                                      displayCity,
                                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16 * scale),
                                    );
                                  },
                                ),
                              ),
                              Spacer(),
                              _weatherLoading 
                                ? SizedBox(
                                    width: 20 * scale,
                                    height: 20 * scale,
                                    child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC107)),
                                  )
                                : GestureDetector(
                                    onLongPress: () {
                                      setState(() => _weatherLoading = true);
                                      _fetchWeather();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Refreshing weather..."), duration: Duration(milliseconds: 500)),
                                      );
                                    },
                                    onTap: () => _showWeatherHover(context, scale),
                                    child: Row(
                                      children: [
                                        Icon(_getWeatherIcon(_weatherCode), color: const Color(0xFFFFC107), size: 20 * scale),
                                        SizedBox(width: 8 * scale),
                                        Text(
                                          "${(_temperature ?? 28.0).toStringAsFixed(1)}°C",
                                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16 * scale),
                                        ),
                                      ],
                                    ),
                                  ),
                              Container(
                                height: 20 * scale,
                                width: 1,
                                 color: isDark ? Colors.white24 : Colors.grey.shade300,
                                margin: EdgeInsets.symmetric(horizontal: 10 * scale),
                              ),
                               ValueListenableBuilder<int>(
                                 valueListenable: NotificationService.updateCount,
                                 builder: (context, count, _) {
                                   final showBadge = _hasNewNotifications || count > 0;
                                   return GestureDetector(
                                     onTap: () {
                                       if (mounted) setState(() => _hasNewNotifications = false);
                                       NotificationService.updateCount.value = 0;
                                       final lid = latestClassifiedId;
                                       if (lid != null) {
                                         SharedPreferences.getInstance().then((p) => p.setString('last_seen_classified_id', lid));
                                       }
                                       if (widget.onNotificationTap != null) widget.onNotificationTap!();
                                     },
                                     child: Stack(
                                       clipBehavior: Clip.none,
                                       children: [
                                         Icon(
                                           showBadge ? Icons.notifications : Icons.notifications_none,
                                           color: isDark ? Colors.white70 : Colors.black87,
                                           size: 22 * scale,
                                         ),
                                         if (showBadge)
                                           Positioned(
                                             right: -4,
                                             top: -4,
                                             child: Container(
                                               padding: EdgeInsets.all(2 * scale),
                                               decoration: const BoxDecoration(
                                                 color: Colors.red,
                                                 shape: BoxShape.circle,
                                               ),
                                               constraints: BoxConstraints(
                                                 minWidth: 14 * scale,
                                                 minHeight: 14 * scale,
                                               ),
                                               child: count > 0 
                                                 ? Center(
                                                     child: Text(
                                                       count > 9 ? "9+" : "$count",
                                                       style: TextStyle(color: Colors.white, fontSize: 8 * scale, fontWeight: FontWeight.bold),
                                                     ),
                                                   )
                                                 : null,
                                             ),
                                           ),
                                       ],
                                     ),
                                   );
                                 },
                               ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 16 * scale),
                        
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16 * scale),
                          padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 6 * scale),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(30 * scale),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB71C1C),
                                  borderRadius: BorderRadius.circular(20 * scale),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8 * scale,
                                      height: 8 * scale,
                                      decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    ),
                                    SizedBox(width: 6 * scale),
                                    Text(text["breaking"]!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * scale)),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12 * scale),
                              Expanded(
                                child: SizedBox(
                                  height: 24 * scale,
                                  child: SingleChildScrollView(
                                    controller: _breakingScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: const NeverScrollableScrollPhysics(), // Controlled by timer
                                    child: Row(
                                      children: [
                                        if (_breakingNewsList.isNotEmpty)
                                          ...([..._breakingNewsList, ..._breakingNewsList]).map((item) => GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _viewNewsDetail(item),
                                            child: Container(
                                              padding: EdgeInsets.only(right: 60 * scale),
                                              alignment: Alignment.center,
                                              child: TranslatedText(
                                                item['title'] ?? '',
                                                language: widget.selectedLanguage,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14 * scale,
                                                ),
                                              ),
                                            ),
                                          )).toList()
                                        else 
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => debugPrint("Default ticker tapped"),
                                            child: Container(
                                              padding: EdgeInsets.only(right: 60 * scale),
                                              child: Text(
                                                isEnglish 
                                                  ? "Breaking: Samanyudu TV news is arriving soon..." 
                                                  : "బ్రేకింగ్: వార్తలు త్వరలో వస్తాయీ...",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14 * scale,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Icon(Icons.bolt, color: Colors.white, size: 24 * scale),
                              SizedBox(width: 6 * scale),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 16 * scale),
                        
                        GestureDetector(
                          onTap: () => _openSearchSheet(),
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 16 * scale),
                            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF112F4A) : Colors.white,
                              borderRadius: BorderRadius.circular(30 * scale),
                              boxShadow: [
                                BoxShadow(color: isDark ? Colors.black45 : Colors.black.withOpacity(0.05), blurRadius: 5, offset: Offset(0, 2)),
                              ]
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: Colors.grey.shade600, size: 22 * scale),
                                SizedBox(width: 12 * scale),
                                Text(
                                  isEnglish ? "Search news..." : "వార్తలు వెతకండి...",
                                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade500, fontSize: 16 * scale)
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 16 * scale),
                        
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16 * scale),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatCard(
                                text["classifieds"] ?? "Classifieds", 
                                "", 
                                Icons.campaign, 
                                Colors.blue, 
                                scale,
                                hasNotification: _hasNewClassifieds,
                                onTap: () => _navigateToCategory('Classifieds', text['classifieds'] ?? 'Classifieds', Icons.campaign),
                              ),
                              _buildStatCard(
                                text["marriage"] ?? "Marriage", 
                                "", 
                                Icons.favorite, 
                                Colors.pink, 
                                scale,
                                hasNotification: _hasNewMarriage,
                                onTap: () => _navigateToCategory('marriage', text['marriage'] ?? 'Marriage', Icons.favorite),
                              ),
                              _buildStatCard(
                                text["live"] ?? "LIVE", 
                                "", 
                                Icons.live_tv, 
                                Colors.red, 
                                scale,
                                textColor: Colors.red,
                                hasNotification: _hasNewLive,
                                onTap: () => _navigateToCategory('Live', text['live'] ?? 'LIVE', Icons.live_tv),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 20 * scale),
                      ],
                    ),
                  ),
                  
                  _newsLoading
                    ? SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: const Color(0xFFFFC107))))
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= _mixedFeed.length) return null;
                            final item = _mixedFeed[index];
                            if (item['feed_type'] == 'ad') {
                              return _buildAdCard(item, scale);
                            }
                            return _buildV2NewsCard(item, index, scale);
                          },
                          childCount: _mixedFeed.length,
                        ),
                      ),
                ]
              ),
            )
          )
        ],
      ),
    ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor, double scale, {Color? textColor, VoidCallback? onTap, bool hasNotification = false}) {
    final isDark = themeNotifier.value == ThemeMode.dark || 
                  (themeNotifier.value == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4 * scale),
          padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 10 * scale),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF112F4A) : Colors.white,
            borderRadius: BorderRadius.circular(20 * scale),
            boxShadow: [
              BoxShadow(color: isDark ? Colors.black45 : Colors.black.withOpacity(0.03), blurRadius: 4, offset: Offset(0, 2)),
            ]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 18 * scale),
              SizedBox(width: 6 * scale),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title, 
                        style: TextStyle(
                          color: textColor ?? (isDark ? Colors.white70 : Colors.black87), 
                          fontSize: 11 * scale, 
                          fontWeight: FontWeight.w500
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    ),
                    if (hasNotification)
                      Container(
                        margin: EdgeInsets.only(left: 4 * scale),
                        width: 8 * scale,
                        height: 8 * scale,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              )
            ],
          )
        ),
      ),
    );
  }

  void _navigateToCategory(String categoryId, String title, IconData icon) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (categoryId == 'Classifieds' || categoryId == 'jobs') {
      _lastVisitClassifieds = now;
      await prefs.setInt('last_visit_classifieds', now);
      setState(() => _hasNewClassifieds = false);
    } else if (categoryId == 'marriage') {
      _lastVisitMarriage = now;
      await prefs.setInt('last_visit_marriage', now);
      setState(() => _hasNewMarriage = false);
    } else if (categoryId == 'Live' || categoryId == 'national') {
      _lastVisitLive = now;
      await prefs.setInt('last_visit_live', now);
      setState(() => _hasNewLive = false);
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryDetailScreen(
            categoryId: categoryId,
            categoryTitle: title,
            count: "", // CategoryDetailScreen fetches its own count
            icon: icon,
            selectedLanguage: widget.selectedLanguage,
          ),
        ),
      );
    }
  }

  Widget _buildV2NewsCard(Map<String, dynamic> item, int index, double scale) {
    final isDark = themeNotifier.value == ThemeMode.dark || 
                  (themeNotifier.value == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final timestamp = DateTime.parse(item['timestamp'] ?? DateTime.now().toIso8601String());
    final timeAgo = _getTimeAgo(timestamp);
    
    final bool isFullWidthImage = false; 
    return GestureDetector(
      onTap: () => _viewNewsDetail(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF112F4A) : Colors.white,
          borderRadius: BorderRadius.circular(24 * scale),
          boxShadow: [BoxShadow(color: isDark ? Colors.black45 : Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 16 * scale, right: 16 * scale, top: 16 * scale, bottom: 8 * scale),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262F36) : const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(6 * scale),
                  ),
                  child: TranslatedText(
                    _getCategoryDisplayName(item['type']).toUpperCase(),
                    language: widget.selectedLanguage,
                    style: TextStyle(color: const Color(0xFFFFC107), fontSize: 10 * scale, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
                SizedBox(width: 12 * scale),
                TranslatedText(
                  timeAgo,
                  language: widget.selectedLanguage,
                  style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 12 * scale),
                ),
              ],
            ),
          ),
          
          if (isFullWidthImage)
            _buildFullWidthCardBody(item, scale)
          else
            _buildSideBySideCardBody(item, scale),
            
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _handleLike(item),
                  child: Row(
                    children: [
                      Icon(
                        _likedPosts.contains(item['id'].toString()) ? Icons.favorite : Icons.favorite_border,
                        color: const Color(0xFFE53935),
                        size: 20 * scale
                      ),
                      SizedBox(width: 6 * scale),
                      Text("${item['likes'] ?? 120}", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 13 * scale)),
                    ],
                  )
                ),
                SizedBox(width: 20 * scale),
                Container(width: 1, height: 16 * scale, color: isDark ? Colors.white24 : Colors.grey.shade300),
                SizedBox(width: 20 * scale),
                GestureDetector(
                  onTap: () => _toggleSave(item),
                  child: Icon(
                    _savedIds.contains(item['id'].toString()) ? Icons.bookmark : Icons.bookmark_border,
                    color: const Color(0xFFFFC107),
                    size: 20 * scale
                  ),
                ),
                SizedBox(width: 6 * scale),
                Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.grey.shade500, size: 18 * scale),
              ],
            ),
          )
        ],
      ),
    ),
  );
}

  Widget _buildSideBySideCardBody(Map<String, dynamic> item, double scale) {
    final isDark = themeNotifier.value == ThemeMode.dark || 
                  (themeNotifier.value == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    item['title'] ?? '',
                    language: widget.selectedLanguage,
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 15 * scale, fontWeight: FontWeight.bold, height: 1.3),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8 * scale),
                  TranslatedText(
                    item['description'] ?? '',
                    language: widget.selectedLanguage,
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontSize: 12 * scale),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12 * scale),
                child: MediaThumbnailWidget(
                  item: item,
                  height: 90 * scale,
                  width: double.infinity,
                ),
              ),
            )
          ],
        ),
      );
    }

  Widget _buildFullWidthCardBody(Map<String, dynamic> item, double scale) {
    final isDark = themeNotifier.value == ThemeMode.dark || 
                  (themeNotifier.value == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16 * scale),
        height: 180 * scale,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16 * scale),
              child: MediaThumbnailWidget(
                item: item,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 80 * scale,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16 * scale)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12 * scale, left: 12 * scale, right: 50 * scale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TranslatedText(
                    item['title'] ?? '',
                    language: widget.selectedLanguage,
                    style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4 * scale),
                  TranslatedText(
                    item['description'] ?? '',
                    language: widget.selectedLanguage,
                    style: TextStyle(color: Colors.white70, fontSize: 12 * scale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: -6 * scale, right: 8 * scale,
              child: Container(
                padding: EdgeInsets.all(2 * scale),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle),
                child: Container(
                  padding: EdgeInsets.all(8 * scale),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).cardColor,
                    border: Border.all(color: const Color(0xFFFFC107), width: 3 * scale),
                  ),
                  child: Icon(Icons.add, color: const Color(0xFFFFC107), size: 18 * scale),
                ),
              ),
            )
          ],
        )
      );
    }

}

class _MutedAdPlayer extends StatefulWidget {
  final String videoUrl;
  final double scale;
  final bool isActive;
  final VoidCallback? onUnmute;
  const _MutedAdPlayer({required this.videoUrl, required this.scale, this.isActive = true, this.onUnmute});

  @override
  State<_MutedAdPlayer> createState() => _MutedAdPlayerState();
}

class _MutedAdPlayerState extends State<_MutedAdPlayer> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(Uri.parse(ApiService.normalizeUrl(widget.videoUrl)))
      ..setVolume(0) // Default muted
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.play();
        }
      });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
      if (!_isMuted && widget.onUnmute != null) {
        widget.onUnmute!();
      }
    });
  }

  @override
  void didUpdateWidget(_MutedAdPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized) {
      if (!widget.isActive) {
        _controller.pause();
      } else if (widget.isActive && !_isMuted) {
        // Only resume automatically if unmuted or by design? 
        // Ads usually play automatically but muted.
        _controller.play();
      } else if (widget.isActive) {
        _controller.play();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_initialized) _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_initialized) _controller.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        height: 200 * widget.scale,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }
    return Container(
      height: 200 * widget.scale,
      width: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          Positioned(
            bottom: 10 * widget.scale,
            right: 10 * widget.scale,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: EdgeInsets.all(8 * widget.scale),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20 * widget.scale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// News Detail Sheet Widget with Voice Over and Full Image Display
class _NewsDetailSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final String selectedLanguage;
  final String Function(DateTime) getTimeAgo;
  final IconData Function(String?) getCategoryIcon;
  final String Function(String?) getCategoryDisplayName;

  const _NewsDetailSheet({
    required this.item,
    required this.selectedLanguage,
    required this.getTimeAgo,
    required this.getCategoryIcon,
    required this.getCategoryDisplayName,
  });

  @override
  State<_NewsDetailSheet> createState() => _NewsDetailSheetState();
}

class _NewsDetailSheetState extends State<_NewsDetailSheet> {
  final SpeechService _speech = SpeechService();
  bool _isPlaying = false;
  bool _isImageExpanded = false;
  bool _ttsInitialized = false;
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadLikeState();
  }

  void _loadLikeState() {
    // Load like state from shared preferences or initialize from item
    _likeCount = widget.item['likes'] ?? 0;
    _isLiked = false; // Could load from shared preferences if needed
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount = _likeCount > 0 ? _likeCount - 1 : 0;
      }
    });
    // In a real app, you would update the database here
  }

  Future<void> _initializeTts() async {
    try {
      await _speech.init();
      if (mounted) setState(() => _ttsInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _ttsInitialized = true);
    }
  }

  Future<void> _toggleVoiceOver() async {
    if (_isPlaying) {
      _speech.cancel();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    if (!_ttsInitialized) {
      await Future.delayed(const Duration(milliseconds: 400));
    }

    final text =
        "${widget.item['title'] ?? ''}. ${widget.item['description'] ?? ''}";
    final isTelugu = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
    final isHindi = RegExp(r'[\u0900-\u097f]').hasMatch(text);
    String lang = "en-US";
    if (isTelugu) {
      lang = "te-IN";
    } else if (isHindi) {
      lang = "hi-IN";
    }

    if (mounted) setState(() => _isPlaying = true);

    _speech.speak(
      text: text,
      lang: lang,
      rate: 0.9,
      pitch: 1.0,
      onComplete: () {
        if (mounted) setState(() => _isPlaying = false);
      },
      onError: (_) {
        if (mounted) setState(() => _isPlaying = false);
      },
    );
  }

  Future<void> _shareArticle() async {
    final title = widget.item['title'] ?? '';
    final description = widget.item['description'] ?? '';
    final imageUrl = widget.item['image_url'];

    final text = "$title\n\n$description";

    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      await Share.share(text, subject: title);
    } else {
      await Share.share(text, subject: title);
    }
  }

  void _toggleImageExpansion() {
    setState(() {
      _isImageExpanded = !_isImageExpanded;
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  IconData _getCategoryIcon(String? type) {
    return widget.getCategoryIcon(type);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? color
                    : (isDark ? Colors.black87 : Colors.black87),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? color
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish =
        widget.selectedLanguage.toLowerCase().contains("english") ||
        widget.selectedLanguage.contains("ఇంగ్లీష్");
    final timestamp = DateTime.tryParse(widget.item['timestamp'] ?? '');
    final timeStr = timestamp != null ? widget.getTimeAgo(timestamp) : 'Recent';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final metaColor = isDark ? Colors.white38 : Colors.black45;
    final cardColor = Theme.of(context).cardColor;

    return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Top Action Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      IconButton(
                      onPressed: () {
                        _speech.cancel();
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.close, color: subTextColor),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Media Section - Full Image Display
                      if (widget.item['image_url'] != null &&
                          widget.item['image_url'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GestureDetector(
                            onTap: _toggleImageExpansion,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _isImageExpanded
                                  ? InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 4.0,
                              child: Image.network(
                                        widget.item['image_url'],
                                        fit: BoxFit.contain,
                                        errorBuilder: (c, e, s) => Container(
                                          height: 300,
                                          color: const Color(0xFF12355A),
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.white24,
                                            size: 50,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Image.network(
                                      widget.item['image_url'],
                                width: double.infinity,
                                      fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => Container(
                                        height: 300,
                                  color: const Color(0xFF12355A),
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.white24,
                                          size: 50,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            width: double.infinity,
                            height: 160,
                            decoration: BoxDecoration(
                              color: const Color(0xFF12355A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          child: Icon(
                            _getCategoryIcon(widget.item['type']),
                            size: 60,
                            color: Colors.white24,
                          ),
                        ),

                      // Action Buttons - Horizontal bar below image (Like, Share, Voice)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Like Button
                            _buildActionButton(
                              icon: _isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              label: _likeCount > 0
                                  ? _likeCount.toString()
                                  : (isEnglish ? "Like" : "లైక్"),
                              onTap: _toggleLike,
                              isActive: _isLiked,
                              color: _isLiked ? Colors.red : Colors.white70,
                            ),
                            // Share Button
                            _buildActionButton(
                              icon: Icons.share,
                              label: isEnglish ? "Share" : "షేర్",
                              onTap: _shareArticle,
                              isActive: false,
                              color: subTextColor,
                            ),
                            // Voice Over Button
                            _buildActionButton(
                              icon: _isPlaying ? Icons.stop : Icons.volume_up,
                              label: _isPlaying
                                  ? (isEnglish ? "Stop" : "ఆపు")
                                  : (isEnglish ? "Voice" : "వాయిస్"),
                              onTap: _toggleVoiceOver,
                              isActive: _isPlaying,
                              color: _isPlaying
                                  ? Colors.red
                                  : Colors.black87,
                            ),
                          ],
                        ),
                          ),
                        
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Metadata Row
                              Row(
                                children: [
                                  Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                    decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFFC107,
                                    ).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFFC107,
                                      ).withOpacity(0.4),
                                    ),
                                    ),
                                    child: Text(
                                    widget.getCategoryDisplayName(widget.item['type']),
                                      style: const TextStyle(
                                        color: const Color(0xFFFFC107), 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 10,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    timeStr,
                                  style: TextStyle(
                                    color: metaColor,
                                    fontSize: 13,
                                  ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Main Title
                              Text(
                              widget.item['title'] ?? '',
                              style: TextStyle(
                                color: textColor,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Author Info
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFFC107,
                                      ).withOpacity(0.5),
                                    ),
                                    ),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Color(0xFF12355A),
                                    child: Icon(
                                      Icons.person,
                                      size: 14,
                                      color: const Color(0xFFFFC107),
                                    ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "${(isEnglish ? "By" : "ద్వారా")}: ${widget.item['author'] ?? 'Admin'}",
                                    style: const TextStyle(
                                      color: const Color(0xFFFFC107), 
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Divider(
                                color: isDark ? Colors.white12 : Colors.black12,
                                thickness: 1,
                              ),
                              ),
                              
                              // Content Description
                              Text(
                              widget.item['description'] ?? '',
                                style: TextStyle(
                                color: isDark
                                    ? Colors.white.withOpacity(0.85)
                                    : Colors.black87,
                                  fontSize: 16,
                                  height: 1.8,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
    );
  }
}
