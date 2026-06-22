import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/share_service.dart';
import '../widgets/shorts_comments_modal.dart';
import '../widgets/scrolling_watermark.dart';

class VideosPage extends StatefulWidget {
  final String selectedLanguage;
  const VideosPage({super.key, required this.selectedLanguage});

  @override
  State<VideosPage> createState() => VideosPageState();
}

class VideosPageState extends State<VideosPage> with WidgetsBindingObserver {
  late PageController _pageController;
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializedSet = {};
  int _currentPageIndex = 0;
  bool isMuted = false;
  bool _loadError = false;
  bool _shortsLoading = true;
  bool _isActiveTab = false;
  bool _userPaused = false;

  final Set<String> _likedIds = {};
  Set<String> _savedIds = {};
  final Set<String> _viewedIds = {};
  final Map<String, int> _likeCounts = {};

  int _likeCount(int index) {
    final id = _getId(index);
    return _likeCounts[id] ?? 0;
  }

  int _saveCount(int index) {
    final id = _getId(index);
    if (id.isEmpty) return 0;
    return _mixedShorts[index]['saves_count'] ?? 0;
  }

  String _getId(int index) {
    if (index < 0 || index >= _mixedShorts.length) return "";
    return _mixedShorts[index]['id']?.toString() ?? "";
  }

  late Map<String, String> _text;

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  /// Reliable public video URLs (Google bucket + Mixkit) for better loading.
  List<Map<String, dynamic>> _realShorts = [];
  List<Map<String, dynamic>> _ads = [];
  List<Map<String, dynamic>> _mixedShorts = [];
  // RealtimeChannel? _realtimeSubscription;

  void _setupRealtimeSubscription() {
    // Supabase realtime is currently unplugged while migrating backends.
  }

  String? _pendingShortId;

  void jumpToShort(String shortId) {
    if (_shortsLoading) {
      _pendingShortId = shortId;
      return;
    }

    final index = _mixedShorts.indexWhere((s) => s['feed_type'] == 'short' && s['id'].toString() == shortId);
    if (index != -1) {
      setState(() {
        _currentPageIndex = index;
        _userPaused = false;
        _isActiveTab = true;
      });
      _pageController.jumpToPage(index);
      _preloadAround(index);
    }
  }

  Future<void> _fetchShorts() async {
    try {
      final response = await ApiService.getShorts();
      final adsResponse = await ApiService.getAdvertisements();

      if (mounted) {
        setState(() {
          _realShorts = List<Map<String, dynamic>>.from(response);
          _ads = adsResponse.where((ad) => ad['is_active'] == true).map((e) => Map<String, dynamic>.from(e)).toList();

          _mixedShorts = [];
          int adIndex = 0;
          int itemsSinceLastAd = 0;
          for (int i = 0; i < _realShorts.length; i++) {
            _mixedShorts.add({..._realShorts[i], 'feed_type': 'short'});
            itemsSinceLastAd++;

            if (_ads.isNotEmpty) {
              final ad = _ads[adIndex % _ads.length];
              int interval = ad['display_interval'] ?? 4;
              if (itemsSinceLastAd >= interval) {
                _mixedShorts.add({...ad, 'feed_type': 'ad'});
                adIndex++;
                itemsSinceLastAd = 0;
              }
            }
          }

          // Initialize counts
          _likeCounts.clear();
          for (var item in _mixedShorts) {
            if (item['feed_type'] == 'short') {
              String id = item['id'].toString();
              _likeCounts[id] = item['likes'] ?? 0;
              // Ensure saves_count is also initialized if present
              item['saves_count'] = item['saves_count'] ?? 0;
            }
          }

          _shortsLoading = false;
        });

        if (_pendingShortId != null) {
          jumpToShort(_pendingShortId!);
          _pendingShortId = null;
        } else if (_mixedShorts.isNotEmpty) {
          _preloadAround(0);
        }
      }
    } catch (e) {
      debugPrint("Error fetching shorts/ads: $e");
      if (mounted) setState(() => _shortsLoading = false);
    }
  }

  Future<void> _toggleLike(int index) async {
    final id = _getId(index);
    if (id.isEmpty) return;

    final isLiked = _likedIds.contains(id);

    setState(() {
      if (isLiked) {
        _likedIds.remove(id);
        int current = _likeCounts[id] ?? 0;
        _likeCounts[id] = current > 0 ? current - 1 : 0;
      } else {
        _likedIds.add(id);
        int current = _likeCounts[id] ?? 0;
        _likeCounts[id] = current + 1;
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'guest';
      await prefs.setStringList('liked_shorts_ids', _likedIds.toList());

      await ApiService.likeShort(id, userId, !isLiked);
      
      if (!isLiked && !_viewedIds.contains(id)) {
        await ApiService.viewShort(id);
        _viewedIds.add(id);
      }
    } catch (e) {
      debugPrint("Error updating short like: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);
    _loadLanguageText();
    _fetchShorts();
    _loadSavedIds();
    _setupRealtimeSubscription();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controllers[_currentPageIndex];
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (controller != null && controller.value.isPlaying) {
        controller.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isActiveTab &&
          controller != null &&
          !controller.value.isPlaying &&
          !_userPaused) {
        controller.play();
      }
    }
  }

  void onTabActive() {
    _isActiveTab = true;
    final controller = _controllers[_currentPageIndex];
    if (controller != null && !controller.value.isPlaying && !_userPaused) {
      controller.play();
      setState(() {});
    }
  }

  void onTabInactive() {
    _isActiveTab = false;
    final controller = _controllers[_currentPageIndex];
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
      setState(() {});
    }
  }

  void refreshData() {
    _loadSavedIds();
    _fetchShorts();
  }

  Future<void> _loadSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedIds = (prefs.getStringList('saved_shorts_ids') ?? []).toSet();
    });

    // final user = Supabase.instance.client.auth.currentUser;
    // if (user != null) {
    //   try {
    //     final res = await Supabase.instance.client
    //         .from('shorts_likes')
    //         .select('short_id')
    //         .eq('user_id', user.id);
    //     if (mounted) {
    //       setState(() {
    //         _likedIds.clear();
    //         _likedIds.addAll(
    //           (res as List).map((row) => row['short_id'].toString()),
    //         );
    //       });
    //     }
    //   } catch (e) {
    //     debugPrint("Error fetching short likes: $e");
    //   }
    // } else {
      if (mounted) {
        setState(() {
          _likedIds.clear();
          _likedIds.addAll(prefs.getStringList('liked_shorts_ids') ?? []);
        });
      }
    // }
  }

  Future<void> _toggleSave(int index) async {
    final id = _getId(index);
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final isSaved = _savedIds.contains(id);
    
    setState(() {
      if (isSaved) {
        _savedIds.remove(id);
        if (_mixedShorts[index]['saves_count'] != null && _mixedShorts[index]['saves_count'] > 0) {
          _mixedShorts[index]['saves_count']--;
        }
      } else {
        _savedIds.add(id);
        _mixedShorts[index]['saves_count'] = (_mixedShorts[index]['saves_count'] ?? 0) + 1;
      }
    });
    await prefs.setStringList('saved_shorts_ids', _savedIds.toList());

    try {
      // Use actual userId if logged in, else use a stable guest ID
      final effectiveUserId = (userId != null && userId.isNotEmpty) 
          ? userId 
          : (prefs.getString('guest_id') ?? 'guest_${DateTime.now().millisecondsSinceEpoch}');
      
      // Save guest_id if we just generated it
      if (userId == null && !prefs.containsKey('guest_id')) {
        await prefs.setString('guest_id', effectiveUserId);
      }

      await ApiService.saveItem(effectiveUserId, id, 'shorts', !isSaved);
    } catch (e) {
      debugPrint("Error syncing saved short: $e");
    }
  }

  void _loadLanguageText() {
    if (_isEnglish) {
      _text = {
        "share": "Share",
        "sound": "Sound",
        "soundOn": "Sound on",
        "muted": "Muted",
        "posted": "Posted",
        "sharedMsg": "Shared",
        "commentsMsg": "Open comments",
        "loadError": "Couldn't load video",
        "tapRetry": "Tap to retry",
        "swipeUp": "Swipe up",
        "swipeDown": "Swipe down",
        "save": "Save",
        "saved": "Saved",
      };
    } else {
      _text = {
        "share": "షేర్",
        "sound": "సౌండ్",
        "soundOn": "సౌండ్ ఆన్",
        "muted": "మ్యూట్",
        "posted": "పోస్ట్ చేయబడినది",
        "sharedMsg": "షేర్ చేయబడింది",
        "commentsMsg": "కామెంట్స్ తెరవండి",
        "loadError": "వీడియో లోడ్ కాలేదు",
        "tapRetry": "మళ్ళీ ప్రయత్నించడానికి టాప్ చేయండి",
        "swipeUp": "పైకి స్వైప్",
        "swipeDown": "క్రిందికి స్వైప్",
        "save": "సేవ్",
        "saved": "సేవ్డ్",
      };
    }
  }

  Future<void> _preloadAround(int index) async {
    // Dispose controllers that are far away (more than 2 pages away)
    final toRemove = <int>[];
    for (final key in _controllers.keys) {
      if ((key - index).abs() > 2) {
        toRemove.add(key);
      }
    }
    for (final key in toRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
      _initializedSet.remove(key);
    }

    for (int i = index - 1; i <= index + 1; i++) {
      if (i < 0 || i >= _mixedShorts.length) continue;
      if (_controllers.containsKey(i)) continue;

      final item = _mixedShorts[i];
      final isAd = item['feed_type'] == 'ad';
      final rawUrl = isAd ? item['media_url'] : item['video_url'];
      final url = ApiService.normalizeUrl(rawUrl);

      // For ads, if it's not a video, don't try to initialize video player
      if (isAd && url != null && !(url.toLowerCase().endsWith('.mp4') || url.toLowerCase().endsWith('.webm') || url.toLowerCase().endsWith('.ogg'))) {
         continue; 
      }

      if (url == null || url.toString().isEmpty) {
        continue;
      }

      final newController = VideoPlayerController.networkUrl(Uri.parse(url));
      _controllers[i] = newController;

      newController.initialize().then((_) {
        if (!mounted) {
          newController.dispose();
          _controllers.remove(i);
          return;
        }
        _initializedSet.add(i);
        newController.setLooping(true);
        newController.setVolume(isAd ? 1.0 : (isMuted ? 0.0 : 1.0));

        if (i == _currentPageIndex && _isActiveTab && !_userPaused) {
          newController.play();
        }
        
        // Track view if it's the current page and playing
        if (i == _currentPageIndex) {
          final id = item['id'].toString();
          if (item['feed_type'] == 'short' && id.isNotEmpty && !_viewedIds.contains(id)) {
            _viewedIds.add(id);
            setState(() {
              int currentViews = int.tryParse(item['views']?.toString() ?? '0') ?? 0;
              item['views'] = currentViews + 1;
            });
            ApiService.viewShort(id).catchError((e) => debugPrint("Error: $e"));
          }
        }
        
        setState(() {});
      }).catchError((Object e) {
        if (!mounted) return;
        newController.dispose();
        _controllers.remove(i);
        _initializedSet.remove(i);
        if (i == _currentPageIndex) setState(() => _loadError = true);
      });
    }
  }

  void _onPageChanged(int index) {
    if (index == _currentPageIndex) return;
    
    // Pause old controller
    final oldController = _controllers[_currentPageIndex];
    oldController?.pause();
    
    setState(() {
      _currentPageIndex = index;
      _loadError = false;
      _userPaused = false;
    });
    
    // Play new controller if ready
    final newController = _controllers[index];
    if (newController != null && _initializedSet.contains(index)) {
      newController.seekTo(Duration.zero);
      if (_isActiveTab && !_userPaused) {
        newController.play();
      }
    }
    
    _preloadAround(index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // _realtimeSubscription?.unsubscribe();
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  String _caption(int index) => _mixedShorts[index]['title'] ?? '';
  String _title(int index) => _mixedShorts[index]['title'] ?? '';
  String _category(int index) => _mixedShorts[index]['feed_type'] == 'ad' ? "AD" : "Shorts";
  String _views(int index) => _mixedShorts[index]['feed_type'] == 'ad' ? "Sponsored" : ""; // Removed view count
  String _timeAgo(int index) {
    if (_mixedShorts[index]['timestamp'] == null) return "Unknown";
    final dt = DateTime.parse(_mixedShorts[index]['timestamp']);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    return "${diff.inMinutes}m ago";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    const accentYellow = Color(0xFFFFC107);

    final size = MediaQuery.of(context).size;
    final double scale = (size.width / 390).clamp(0.85, 1.15);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final iconColor = isDark ? Colors.white54 : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: _shortsLoading
          ? Center(child: CircularProgressIndicator(color: accentYellow))
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _mixedShorts.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final item = _mixedShorts[index];
                final isAd = item['feed_type'] == 'ad';
                final isActive = index == _currentPageIndex;
                final controller = _controllers[index];
                final isReady = controller != null && _initializedSet.contains(index);
                final showVideo = isReady && !(_loadError && isActive);
                final showError = isActive && _loadError;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    /// Video
                    if (showVideo)
                      GestureDetector(
                        onTap: () {
                          if (controller == null) return;
                          setState(() {
                            if (controller.value.isPlaying) {
                              controller.pause();
                              if (isActive) _userPaused = true;
                            } else {
                              controller.play();
                              if (isActive) _userPaused = false;
                            }
                          });
                        },
                        child: Stack(
                          children: [
                            SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: controller!.value.size.width,
                                  height: controller.value.size.height,
                                  child: VideoPlayer(controller),
                                ),
                              ),
                            ),
                            if (!controller.value.isPlaying)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    size: 60,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (showError)
                      GestureDetector(
                        onTap: () {
                          setState(() => _loadError = false);
                          _preloadAround(index);
                        },
                        child: Container(
                          color: bgColor,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 56 * scale,
                                  color: iconColor,
                                ),
                                SizedBox(height: 12 * scale),
                                Text(
                                  _text["loadError"]!,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 16 * scale,
                                  ),
                                ),
                                SizedBox(height: 6 * scale),
                                Text(
                                  _text["tapRetry"]!,
                                  style: TextStyle(
                                    color: accentYellow,
                                    fontSize: 14 * scale,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (isActive)
                      const Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFFFFC107),
                        ),
                      )
                    else if (isAd && item['media_url'] != null)
                      Image.network(
                        ApiService.normalizeUrl(item['media_url']),
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        color: bgColor,
                        child: Icon(
                          Icons.videocam,
                          size: 80 * scale,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),

                    /// Scrolling Watermark
                    Positioned(
                      top: 40 * scale,
                      left: 0,
                      right: 0,
                      child: const ScrollingWatermark(),
                    ),

                    /// Right action buttons
                    if (!isAd)
                      Positioned(
                        right: 12 * scale,
                        bottom: 138 * scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _actionButton(
                              icon: _likedIds.contains(_getId(index))
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_alt_outlined,
                              label: _likeCount(index).toString(),
                              active: _likedIds.contains(_getId(index)),
                              scale: scale,
                              onTap: () => _toggleLike(index),
                            ),
                            SizedBox(height: 18 * scale),
                            _actionButton(
                              icon: Icons.share_outlined,
                              label: _text["share"]!,
                              scale: scale,
                              onTap: () {
                                ShareService.shareText(item);
                              },
                            ),
                            SizedBox(height: 18 * scale),
                            _actionButton(
                              icon: Icons.chat_bubble_outline,
                              label: (item['comments_count'] ?? 0)
                                  .toString(),
                              scale: scale,
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (c) => ShortsCommentsModal(
                                    short: item,
                                    isEnglish: _isEnglish,
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 18 * scale),
                             _actionButton(
                              icon: _savedIds.contains(_getId(index))
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              label: _savedIds.contains(_getId(index)) ? _text["saved"]! : _text["save"]!,
                              active: _savedIds.contains(_getId(index)),
                              scale: scale,
                              onTap: () => _toggleSave(index),
                            ),
                            SizedBox(height: 18 * scale),
                            _actionButton(
                              icon: isMuted ? Icons.volume_off : Icons.volume_up,
                              label: _text["sound"]!,
                              scale: scale,
                              onTap: () {
                                setState(() => isMuted = !isMuted);
                                for (final c in _controllers.values) {
                                  c.setVolume(isMuted ? 0 : 1);
                                }
                                _showSnack(
                                  isMuted ? _text["muted"]! : _text["soundOn"]!,
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    else
                         // Ad CTA or info
                         Positioned(
                           right: 12 * scale,
                           bottom: 138 * scale,
                           child: _actionButton(
                             icon: Icons.launch,
                             label: "Open Ad",
                             scale: scale,
                             onTap: () {
                               // Open target URL or just show info
                             },
                           ),
                         ),

                    /// Bottom: category, title, views + posted time (above nav so always visible)
                    Positioned(
                      bottom: 110 * scale,
                      left: 16 * scale,
                      right: 90 * scale,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// Category (per video)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12 * scale,
                              vertical: 5 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: accentYellow,
                              borderRadius: BorderRadius.circular(18 * scale),
                            ),
                            child: Text(
                              _category(index),
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 12 * scale,
                              ),
                            ),
                          ),
                          SizedBox(height: 10 * scale),

                          /// Title
                          Text(
                            _title(index),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17 * scale,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10 * scale),

                          /// First line: posted time (views removed)
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14 * scale,
                                color: Colors.white70,
                              ),
                              SizedBox(width: 4 * scale),
                              Text(
                                "${_text["posted"]!} ${_timeAgo(index)}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w500,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required double scale,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 46 * scale,
            width: 46 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54, // Darker background
              border: Border.all(
                color: active ? const Color(0xFFFFC107) : Colors.white60,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  spreadRadius: 1,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: active ? const Color(0xFFFFC107) : Colors.white,
              size: 24 * scale,
            ),
          ),
        ),
        SizedBox(height: 6 * scale),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12 * scale,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ],
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
