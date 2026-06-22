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
  VideoPlayerController? _controller;
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
    _initializeVideoForIndex(_currentPageIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_controller != null && _controller!.value.isPlaying) {
        _controller!.pause();
        setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null && !_controller!.value.isPlaying) {
        _controller!.play();
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

  Future<void> _initializeVideoForIndex(int index) async {
    if (index < 0 || index >= widget.shorts.length) return;
    await _controller?.dispose();
    _controller = null;
    if (mounted) setState(() => _loadError = false);

    final url = ApiService.normalizeUrl(widget.shorts[index]['video_url']);
    final newController = VideoPlayerController.networkUrl(Uri.parse(url));

    newController.initialize().then((_) {
      if (!mounted) {
        newController.dispose();
        return;
      }
      _controller = newController;
      _controller!
        ..setLooping(true)
        ..setVolume(isMuted ? 0 : 1)
        ..play();
      setState(() => _loadError = false);
    }).catchError((Object e) {
      if (!mounted) return;
      newController.dispose();
      setState(() => _loadError = true);
    });
  }

  void _onPageChanged(int index) {
    if (index == _currentPageIndex) return;
    setState(() => _currentPageIndex = index);
    _initializeVideoForIndex(index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _controller?.dispose();
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
              final showVideo = isActive &&
                  _controller != null &&
                  _controller!.value.isInitialized &&
                  !_loadError;
              final showError = isActive && _loadError;
    
              return Stack(
                fit: StackFit.expand,
                children: [
                  /// Video
                  if (showVideo)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller!.value.isPlaying) {
                            _controller!.pause();
                          } else {
                            _controller!.play();
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.size.width,
                                height: _controller!.value.size.height,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                          ),
                          if (!_controller!.value.isPlaying)
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
                      onTap: () => _initializeVideoForIndex(index),
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
                            _controller?.setVolume(isMuted ? 0 : 1);
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
