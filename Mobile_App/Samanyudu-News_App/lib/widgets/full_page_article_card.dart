import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../services/api_service.dart';
import '../services/speech_service.dart';
import '../services/share_service.dart';
import '../services/translation_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'translated_text.dart';
import 'media_thumbnail_widget.dart';
import 'scrolling_watermark.dart';

class FullPageArticleCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String selectedLanguage;
  final bool isLiked;
  final bool isSaved;
  final PageController pageController;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback? onBack;

  const FullPageArticleCard({
    super.key,
    required this.item,
    required this.selectedLanguage,
    required this.isLiked,
    required this.isSaved,
    required this.pageController,
    required this.onLike,
    required this.onSave,
    this.onBack,
  });

  @override
  State<FullPageArticleCard> createState() => _FullPageArticleCardState();
}

class _FullPageArticleCardState extends State<FullPageArticleCard> {
  final SpeechService _speech = SpeechService();
  bool _isPlaying = false;
  double _currentSpeechRate = 0.5;
  final ScrollController _scrollController = ScrollController();
  
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  void _initializeMedia() {
    final videoUrl = widget.item['video_url'];
    if (videoUrl != null && videoUrl.toString().trim().isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(ApiService.normalizeUrl(videoUrl.toString()))
      );
      _initializeVideoPlayerFuture = _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.setLooping(true);
          _videoController!.setVolume(1.0); // Reset volume to 1.0 since it's user-triggered now
          // _videoController!.play(); // REMOVED auto-play as requested
        }
      });
    }

    final liveLink = widget.item['live_link'];
    if (liveLink != null && liveLink.toString().trim().isNotEmpty) {
      String? videoId = YoutubePlayerController.convertUrlToId(liveLink.toString());
      if (videoId == null) {
        final match = RegExp(r"youtube\.com\/live\/([a-zA-Z0-9_-]+)").firstMatch(liveLink.toString());
        if (match != null) {
          videoId = match.group(1);
        }
      }
      if (videoId == null) {
        final match = RegExp(r"youtube\.com\/shorts\/([a-zA-Z0-9_-]+)").firstMatch(liveLink.toString());
        if (match != null) {
          videoId = match.group(1);
        }
      }
      if (videoId == null) {
        final match = RegExp(r"v=([a-zA-Z0-9_-]+)").firstMatch(liveLink.toString());
        if (match != null) {
          videoId = match.group(1);
        }
      }

      if (videoId != null) {
        _ytController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            mute: false,
            playsInline: true,
            strictRelatedVideos: true,
            origin: 'https://www.youtube.com',
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _scrollController.dispose();
    _videoController?.pause();
    _videoController?.dispose();
    _ytController?.close();
    super.dispose();
  }

  void _toggleVoice() {
    if (_isPlaying) {
      _speech.cancel();
      setState(() => _isPlaying = false);
    } else {
      _startSpeaking();
    }
  }

  Future<void> _startSpeaking() async {
    final item = widget.item;
    String text = "${item['title'] ?? ''}. ${item['description'] ?? ''}";
    
    final isTeluguSelected = widget.selectedLanguage.contains('తెలుగు') || 
                             widget.selectedLanguage.toLowerCase().contains('telugu');
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Processing Voice... Lang: ${widget.selectedLanguage}"),
        duration: const Duration(seconds: 1),
      ),
    );

    setState(() => _isPlaying = true);

    if (isTeluguSelected) {
      final hasEnglishChars = RegExp(r'[a-zA-Z]').hasMatch(text);
      if (hasEnglishChars) {
        try {
          text = await TranslationService.translate(text, to: 'te');
        } catch (e) {
          debugPrint("Translation failed: $e");
        }
      }
    } else {
      final hasTeluguChars = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
      if (hasTeluguChars) {
         try {
          text = await TranslationService.translate(text, to: 'en');
        } catch (e) {
          debugPrint("Translation failed: $e");
        }
      }
    }

    final isTelugu = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
    final isHindi = RegExp(r'[\u0900-\u097f]').hasMatch(text);
    
    String langPos = "en-US";
    if (isTelugu) {
      langPos = "te-IN";
    } else if (isHindi) {
      langPos = "hi-IN";
    }
    
    if (!mounted) return;

    _speech.speak(
      text: text,
      lang: langPos,
      rate: _currentSpeechRate,
      onComplete: () {
        if (mounted) setState(() => _isPlaying = false);
      },
      onError: (_) {
         if (mounted) setState(() => _isPlaying = false);
      },
    );
  }

  Future<void> _launchLiveLink() async {
    final liveLink = widget.item['live_link'];
    if (liveLink != null && liveLink.toString().trim().isNotEmpty) {
      final uri = Uri.parse(liveLink.toString().trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    }
  }

  void _showSpeedMenu() {
    final speeds = [0.25, 0.5, 0.75, 1.0];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final isEnglish = widget.selectedLanguage.toLowerCase().contains("english") ||
        widget.selectedLanguage.contains("ఇంగ్లీష్");

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                    isEnglish ? "Select Playback Speed" : "ప్లేబ్యాక్ వేగాన్ని ఎంచుకోండి",
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: speeds.map((speed) {
                      final isSelected = speed == _currentSpeechRate;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ChoiceChip(
                          label: Text("${speed}x", style: TextStyle(color: isSelected ? Colors.black : textColor)),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFFC107),
                          onSelected: (bool selected) {
                            if (selected) {
                              setState(() => _currentSpeechRate = speed);
                              Navigator.pop(context);
                              if (_isPlaying) {
                                _speech.cancel();
                                _startSpeaking();
                              }
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            );
          }
        );
      },
    );
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return "";
    final dt = DateTime.tryParse(timestamp) ?? DateTime.now();
    final diff = DateTime.now().difference(dt);
    final isEnglish = widget.selectedLanguage.toLowerCase().contains("english") ||
        widget.selectedLanguage.contains("ఇంగ్లీష్");
    
    if (diff.inDays > 0) return "${diff.inDays}${isEnglish ? 'd ago' : ' రోజుల క్రితం'}";
    if (diff.inHours > 0) return "${diff.inHours}${isEnglish ? 'h ago' : ' గంటల క్రితం'}";
    return "${diff.inMinutes}${isEnglish ? 'm ago' : ' నిమిషాల క్రితం'}";
  }

  Widget _buildMediaContent(Size size) {
    if (_ytController != null) {
      return SizedBox(
        height: size.height * 0.45,
        width: size.width,
        child: YoutubePlayer(
          controller: _ytController!,
          aspectRatio: 16 / 9,
        ),
      );
    }
    
    if (_videoController != null) {
      return FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _videoController!.value.isInitialized) {
            return SizedBox(
              height: size.height * 0.45,
              width: size.width,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                  Positioned.fill(
                    child: _VideoOverlay(controller: _videoController!),
                  ),
                ],
              ),
            );
          }
          return MediaThumbnailWidget(
            item: widget.item,
            height: size.height * 0.45,
            width: size.width,
            fit: BoxFit.contain, // Changed to contain to ensure full image visibility
          );
        },
      );
    }

    return MediaThumbnailWidget(
      item: widget.item,
      height: size.height * 0.45,
      width: size.width,
      fit: BoxFit.contain, // Changed to contain to ensure full image visibility
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final cardBg = isDark ? const Color(0xFF041627) : Colors.white;
    final bottomBarBg = isDark ? const Color(0xFF0D253F) : Colors.grey[100];
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final bool hasLive = widget.item['live_link'] != null && widget.item['live_link'].toString().trim().isNotEmpty;
    final bool hasVideo = widget.item['video_url'] != null && widget.item['video_url'].toString().trim().isNotEmpty;
    final bool isMediaVideo = hasLive || hasVideo;
    
    return Container(
      color: cardBg,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is OverscrollNotification) {
                if (notification.overscroll > 10) {
                  widget.pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                } else if (notification.overscroll < -10) {
                  widget.pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                }
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        color: Colors.black, // Dark background behind the media header
                        child: _buildMediaContent(size),
                      ),
                      if (_ytController == null && (_videoController == null || !_videoController!.value.isPlaying))
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                                  stops: const [0.8, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      // Static Watermark for Images (Way2News style)
                      if (!isMediaVideo)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Opacity(
                            opacity: 0.95,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black45, // Background opacity box
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Image.asset(
                                'assets/app_logo_new.png',
                                height: 28, // Slightly adjusted height
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 150.0), // Extra bottom padding for scroll area
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.3)),
                              ),
                              child: Text(
                                (widget.item['type'] ?? 'News').toString().toUpperCase(),
                                style: const TextStyle(color: Color(0xFFFFC107), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.access_time_filled, size: 14, color: subTextColor),
                                const SizedBox(width: 4),
                                Text(_getTimeAgo(widget.item['timestamp']), style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white10)),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.5))),
                              child: const CircleAvatar(radius: 14, backgroundColor: Color(0xFF1E446B), child: Icon(Icons.person, size: 16, color: Colors.white)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.item['author'] ?? 'Samanyudu Admin', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                                Text("Journalist", style: TextStyle(color: subTextColor, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10)),
                        
                        // New Heading Section
                        TranslatedText(
                          widget.item['title'] ?? '',
                          language: widget.selectedLanguage,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Description Section
                        TranslatedText(
                          widget.item['description'] ?? '',
                          language: widget.selectedLanguage,
                          textAlign: TextAlign.justify,
                          style: TextStyle(color: textColor.withOpacity(0.85), fontSize: 17, height: 1.7, letterSpacing: 0.3),
                        ),

                        // Marriage Details Section
                        if ((widget.item['type']?.toString().toLowerCase().trim() == 'marriage' || 
                             widget.item['type']?.toString().trim() == 'పెళ్లి పందిరి' || 
                             widget.item['type']?.toString().trim() == 'పెళ్ళి పందిరి' ||
                             widget.item['type']?.toString().trim() == 'వివాహ వేడుక' ||
                             widget.item['type']?.toString().toLowerCase().trim() == 'vivaha veduka') && 
                            widget.item['marriage_details'] != null)
                          _buildMarriageProfile(Map<String, dynamic>.from(widget.item['marriage_details'])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (widget.onBack != null)
            Positioned(
              top: 50,
              left: 15,
              child: GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                  child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
                ),
              ),
            ),
            
          // Watermark ticker - ONLY for videos
          if (isMediaVideo)
            const Positioned(top: 55, left: 0, right: 0, child: ScrollingWatermark()),

          // Fixed Action Bar Bottom
          Positioned(
            bottom: bottomPadding + 10, // Added dynamic padding for mobile navigation areas
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: bottomBarBg?.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionBtn(icon: widget.isLiked ? Icons.favorite : Icons.favorite_border, label: widget.selectedLanguage.contains('Telugu') ? "లైక్" : "Like", color: Colors.red, isActive: widget.isLiked, onTap: widget.onLike, isDark: isDark),
                  _buildActionBtn(icon: widget.isSaved ? Icons.bookmark : Icons.bookmark_border, label: widget.selectedLanguage.contains('Telugu') ? "సేవ్" : "Save", color: const Color(0xFFFFC107), isActive: widget.isSaved, onTap: widget.onSave, isDark: isDark),
                  if (widget.item['live_link'] != null && widget.item['live_link'].toString().trim().isNotEmpty)
                    _buildActionBtn(icon: Icons.live_tv, label: "Live", color: Colors.red, isActive: true, onTap: _launchLiveLink, isDark: isDark),
                  _buildActionBtn(icon: Icons.share_outlined, label: widget.selectedLanguage.contains('Telugu') ? "షేర్" : "Share", color: Colors.blueAccent, isActive: false, onTap: () => ShareService.showShareOptions(context, widget.item, widget.selectedLanguage), isDark: isDark),
                  _buildActionBtn(icon: _isPlaying ? Icons.stop_circle : Icons.volume_up_rounded, label: widget.selectedLanguage.contains('Telugu') ? "వాయిస్" : "Voice", color: const Color(0xFFFFC107), isActive: _isPlaying, onTap: _toggleVoice, isDark: isDark),
                  _buildActionBtn(icon: Icons.speed, label: widget.selectedLanguage.contains('Telugu') ? "వేగం" : "Speed", color: const Color(0xFFFFC107), isActive: false, onTap: _showSpeedMenu, isDark: isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarriageProfile(Map<String, dynamic> d) {
    final isEnglish = widget.selectedLanguage.toLowerCase().contains("english") ||
        widget.selectedLanguage.contains("ఇంగ్లీష్");
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
    final labelColor = isDark ? Colors.white60 : Colors.black54;
    final valColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Colors.pink, size: 22),
              const SizedBox(width: 10),
              Text(
                isEnglish ? "Matrimonial Profile" : "వివాహ ప్రొఫైల్",
                style: TextStyle(
                  color: valColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow(isEnglish ? "Full Name" : "పూర్తి పేరు", d['full_name'], labelColor, valColor),
          _buildDetailRow(isEnglish ? "Gender" : "లింగం", d['gender'], labelColor, valColor),
          _buildDetailRow(isEnglish ? "Age / DOB" : "వయస్సు / పుట్టిన తేదీ", "${d['age'] ?? ''}${d['date_of_birth'] != null ? ' (${d['date_of_birth']})' : ''}", labelColor, valColor),
          _buildDetailRow(isEnglish ? "Education" : "విద్య", d['highest_education'], labelColor, valColor),
          _buildDetailRow(isEnglish ? "Occupation" : "ఉద్యోగం", d['occupation'], labelColor, valColor),
          _buildDetailRow(isEnglish ? "Income" : "ఆదాయం", d['annual_income'], labelColor, valColor),
          _buildDetailRow(isEnglish ? "Religion/Caste" : "మతం/కులం", "${d['religion'] ?? ''}${d['caste'] != null ? ' - ${d['caste']}' : ''}", labelColor, valColor),
          _buildDetailRow(isEnglish ? "Location" : "ప్రాంతం", d['location'], labelColor, valColor),
          _buildDetailRow(isEnglish ? "Native Place" : "సొంత ఊరు", d['native_place'], labelColor, valColor),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10),
          ),
          
          Text(
            isEnglish ? "Family Details" : "కుటుంబ వివరాలు",
            style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(isEnglish ? "Father" : "తండ్రి", "${d['father_name'] ?? ''}${d['father_occupation'] != null ? ' (${d['father_occupation']})' : ''}", labelColor, valColor),
          _buildDetailRow(isEnglish ? "Mother" : "తల్లి", "${d['mother_name'] ?? ''}${d['mother_occupation'] != null ? ' (${d['mother_occupation']})' : ''}", labelColor, valColor),
          _buildDetailRow(isEnglish ? "Siblings" : "తోబుట్టువులు", d['siblings'], labelColor, valColor),

          if (d['is_contact_visible'] == true || d['is_contact_visible'] == 'true') ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10),
            ),
            Text(
              isEnglish ? "Contact Information" : "సంప్రదింపు వివరాలు",
              style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(isEnglish ? "Phone" : "ఫోన్", d['phone_number'], labelColor, valColor),
            _buildDetailRow(isEnglish ? "Email" : "ఈమెయిల్", d['email'], labelColor, valColor),
            _buildDetailRow(isEnglish ? "WhatsApp" : "వాట్సాప్", d['whatsapp_number'], labelColor, valColor),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value, Color labelColor, Color valColor) {
    if (value == null || value.toString().isEmpty || value.toString() == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(color: valColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? color : (isDark ? Colors.white70 : Colors.black87), size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isActive ? color : (isDark ? Colors.white54 : Colors.black54), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoOverlay({required this.controller});
  @override
  State<_VideoOverlay> createState() => _VideoOverlayState();
}

class _VideoOverlayState extends State<_VideoOverlay> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          widget.controller.value.isPlaying ? widget.controller.pause() : widget.controller.play();
        });
      },
      child: Container(
        // Hit area covers entire video area always
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: widget.controller.value.isPlaying
            ? const SizedBox.shrink()
            : Center(
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
                ),
              ),
      ),
    );
  }
}
