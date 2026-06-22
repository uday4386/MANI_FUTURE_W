import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../services/api_service.dart';
import '../widgets/scrolling_watermark.dart';

class SavedShortsPlayer extends StatefulWidget {
  final List<Map<String, dynamic>> shorts;
  final int initialIndex;
  final String selectedLanguage;

  const SavedShortsPlayer({
    super.key,
    required this.shorts,
    required this.initialIndex,
    required this.selectedLanguage,
  });

  @override
  State<SavedShortsPlayer> createState() => _SavedShortsPlayerState();
}

class _SavedShortsPlayerState extends State<SavedShortsPlayer> with WidgetsBindingObserver {
  late PageController _pageController;
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializedSet = {};
  late int _currentPageIndex;
  bool isMuted = false;
  bool _loadError = false;

  Set<String> _savedIds = {};

  late Map<String, String> _text;

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPageIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadLanguageText();
    _loadSavedIds();
    _preloadAround(_currentPageIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controllers[_currentPageIndex];
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (controller != null && controller.value.isPlaying) {
        controller.pause();
        setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null && !controller.value.isPlaying) {
        controller.play();
        setState(() {});
      }
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
      };
    }
  }

  Future<void> _loadSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedIds = (prefs.getStringList('saved_shorts_ids') ?? []).toSet();
    });
  }

  String _getId(int index) {
      if (index < 0 || index >= widget.shorts.length) return "";
      return widget.shorts[index]['id'].toString();
  }

  Future<void> _toggleSave(int index) async {
    final id = _getId(index);
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
    await prefs.setStringList('saved_shorts_ids', _savedIds.toList());
  }

  Future<void> _preloadAround(int index) async {
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
      if (i < 0 || i >= widget.shorts.length) continue;
      if (_controllers.containsKey(i)) continue;

      final url = ApiService.normalizeUrl(widget.shorts[i]['video_url']);
      if (url == null || url.isEmpty) continue;

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
        newController.setVolume(isMuted ? 0 : 1);

        if (i == _currentPageIndex) {
          newController.play();
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
    
    final oldController = _controllers[_currentPageIndex];
    oldController?.pause();
    
    setState(() {
      _currentPageIndex = index;
      _loadError = false;
    });
    
    final newController = _controllers[index];
    if (newController != null && _initializedSet.contains(index)) {
      newController.seekTo(Duration.zero);
      newController.play();
    }
    
    _preloadAround(index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  String _caption(int index) => widget.shorts[index]['title'] ?? '';
  String _title(int index) => widget.shorts[index]['title'] ?? '';
  String _views(int index) => "${widget.shorts[index]['views'] ?? '0'} views";
  String _timeAgo(int index) {
    if (widget.shorts[index]['timestamp'] == null) return "Unknown";
    final dt = DateTime.parse(widget.shorts[index]['timestamp']);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    return "${diff.inMinutes}m ago";
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF041627);
    const accentYellow = Color(0xFFFFC107);
    
    final size = MediaQuery.of(context).size;
    final double scale = (size.width / 390).clamp(0.85, 1.15);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.shorts.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
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
                          } else {
                            controller.play();
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: controller.value.size.width,
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
                                child: Icon(Icons.play_arrow, size: 60, color: Colors.white70),
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
                              Icon(Icons.error_outline,
                                  size: 56, color: Colors.white54),
                              const SizedBox(height: 12),
                              Text(
                                _text["loadError"]!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _text["tapRetry"]!,
                                style: const TextStyle(
                                    color: accentYellow, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (isActive)
                    const Center(
                      child: CircularProgressIndicator(color: const Color(0xFFFFC107)),
                    )
                  else
                    Container(
                      color: bgColor,
                      child: Icon(Icons.videocam,
                          size: 80, color: Colors.white12),
                    ),
    
                  /// Scrolling Watermark
                  Positioned(
                    top: 40 * scale,
                    left: 0,
                    right: 0,
                    child: const ScrollingWatermark(),
                  ),
    
                  /// Caption bar
                  Positioned(
                    bottom: 120 * scale,
                    left: 16 * scale,
                    right: 16 * scale,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14 * scale),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14 * scale, vertical: 12 * scale),
                          color: Colors.black.withOpacity(0.35),
                          child: Text(
                            _caption(index),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13 * scale,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
    
                  /// Right action buttons
                  Positioned(
                    right: 12 * scale,
                    bottom: 100 * scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionButton(
                          icon: Icons.share_outlined,
                          label: _text["share"]!,
                          scale: scale,
                          onTap: () {},
                        ),
                        SizedBox(height: 18 * scale),
                        _actionButton(
                          icon: Icons.bookmark,
                          label: _savedIds.contains(_getId(index)) ? "Saved" : "Save",
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
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  /// Bottom Info
                  Positioned(
                    bottom: 40 * scale,
                    left: 16 * scale,
                    right: 90 * scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Text(
                          _title(index),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                         SizedBox(height: 6 * scale),
                         Text(
                          _timeAgo(index),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Back button
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
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
              color: Colors.white.withOpacity(0.12),
              border: Border.all(
                color: active ? Colors.amber : Colors.white24,
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              color: active ? Colors.amber : Colors.white,
              size: 22 * scale,
            ),
          ),
        ),
        SizedBox(height: 6 * scale),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
