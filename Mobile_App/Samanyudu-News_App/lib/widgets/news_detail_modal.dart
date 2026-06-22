import 'package:flutter/material.dart';
import '../services/share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import 'package:translator/translator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/speech_service.dart';
// For rootBundle if needed
// For kIsWeb
// For Date formatting
import 'translated_text.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../services/translation_service.dart';
import 'scrolling_watermark.dart';

class NewsDetailModal extends StatefulWidget {
  final Map<String, dynamic> item;
  final String selectedLanguage;
  final bool initialLiked;
  final Function(bool)? onLikeToggle; // Optional callback
  
  const NewsDetailModal({
    super.key,
    required this.item, 
    required this.selectedLanguage,
    this.initialLiked = false,
    this.onLikeToggle,
  });
  
  @override
  State<NewsDetailModal> createState() => _NewsDetailModalState();
}

class _NewsDetailModalState extends State<NewsDetailModal> {
  final SpeechService _speech = SpeechService();
  bool _isPlaying = false;
  late bool _isLiked;
  bool _isSaved = false;
  bool _isImageExpanded = false;

  double _currentSpeechRate = 0.75; // Default speed
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;
  YoutubePlayerController? _ytController;

  // RealtimeChannel? _subscription;
  
  void _subscribeToItem() {
    // Unplugged while migrating to local backend
  }

  @override
  void initState() {
    super.initState();
    _speech.init();
    _isLiked = widget.initialLiked;
    _checkIfSaved();
    _subscribeToItem();

    final videoUrl = widget.item['video_url'];
    if (videoUrl != null && videoUrl.toString().isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(ApiService.normalizeUrl(videoUrl)));
      _initializeVideoPlayerFuture = _videoController!.initialize().then((_) {
        if (mounted) setState(() {});
        _videoController!.setLooping(true);
      });
    }

    final liveLink = widget.item['live_link'];
    if (liveLink != null && liveLink.toString().isNotEmpty) {
      String? videoId = YoutubePlayerController.convertUrlToId(liveLink.toString());
      if (videoId == null) {
        final match = RegExp(r"youtube\.com\/live\/([a-zA-Z0-9_-]+)").firstMatch(liveLink.toString());
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

  Future<void> _checkIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList('saved_news_ids') ?? [];
    setState(() {
      _isSaved = savedIds.contains(widget.item['id'].toString());
    });
  }

  Future<void> _toggleSave() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final savedIds = prefs.getStringList('saved_news_ids') ?? [];
    final id = widget.item['id'].toString();
    
    setState(() {
      if (_isSaved) {
        savedIds.remove(id);
        _isSaved = false;
      } else {
        if (!savedIds.contains(id)) {
          savedIds.add(id);
        }
        _isSaved = true;
      }
    });
    
    await prefs.setStringList('saved_news_ids', savedIds);
    
    // Sync with backend if logged in
    if (userId != null && userId.isNotEmpty) {
      try {
        await ApiService.saveItem(userId, id, 'news', _isSaved);
      } catch (e) {
        debugPrint("Error syncing saved news (detail): $e");
      }
    }
  }

  @override
  void dispose() {
    // _subscription?.unsubscribe();
    _videoController?.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _toggleVoiceOver() {
    if (_isPlaying) {
      _stopSpeaking();
    } else {
      _startSpeaking();
    }
  }

  void _stopSpeaking() {
    _speech.cancel();
    setState(() => _isPlaying = false);
  }

  Future<void> _startSpeaking() async {
    final item = widget.item;
    String text = "${item['title'] ?? ''}. ${item['description'] ?? ''}";
    
    // Determine target language based on user selection
    final isTeluguSelected = widget.selectedLanguage.contains('తెలుగు') || 
                             widget.selectedLanguage.toLowerCase().contains('telugu');
    
    // Show debug info to user
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Processing Voice... Lang: ${widget.selectedLanguage} (Telugu item: $isTeluguSelected)"),
        duration: const Duration(seconds: 1),
      ),
    );

    setState(() => _isPlaying = true);

    // If target is Telugu but text is not Telugu, translate it first
    if (isTeluguSelected) {
      final hasEnglishChars = RegExp(r'[a-zA-Z]').hasMatch(text);
      
      if (hasEnglishChars) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Translating to Telugu for Speech..."), duration: Duration(seconds: 1)),
          );
          
          text = await TranslationService.translate(text, to: 'te');
          debugPrint("Translation success: ${text.substring(0, text.length > 20 ? 20 : text.length)}...");
        } catch (e) {
          debugPrint("Translation failed: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Translation Failed: $e"), backgroundColor: Colors.red),
          );
        }
      }
    } 
    // If target is English but text is Telugu, translate to English
    else {
      final hasTeluguChars = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
      if (hasTeluguChars) {
         try {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Translating to English for Speech..."), duration: Duration(seconds: 1)),
          );
          text = await TranslationService.translate(text, to: 'en');
        } catch (e) {
          debugPrint("Translation failed: $e");
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Translation Failed: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }

    // Now determine lang code based on the (possibly translated) text
    final isTelugu = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
    final isHindi = RegExp(r'[\u0900-\u097f]').hasMatch(text);
    
    String langPos = "en-US";
    if (isTelugu) {
      langPos = "te-IN";
    } else if (isHindi) {
      langPos = "hi-IN";
    }
    
    if (!mounted) return;
    
    debugPrint("Speaking in $langPos: $text");

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

  void _showSpeedMenu() {
    final speeds = [0.5, 0.75, 1.0];
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
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEnglish ? "Select Playback Speed" : "ప్లేబ్యాక్ వేగాన్ని ఎంచుకోండి",
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: speeds.map((speed) {
                  final isSelected = speed == _currentSpeechRate;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ChoiceChip(
                      label: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          "${speed}x",
                          style: TextStyle(
                            color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFFC107),
                      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFFFC107) : Colors.transparent,
                        ),
                      ),
                      showCheckmark: false,
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() => _currentSpeechRate = speed);
                          Navigator.pop(context);
                          if (_isPlaying) {
                            _startSpeaking(); // Restart with new speed
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
      },
    );
  }
  
  Future<void> _toggleLike() async {
    final newLiked = !_isLiked;
    
    // Optimistic Update
    setState(() {
      _isLiked = newLiked;
      final current = (widget.item['likes'] ?? 0);
      widget.item['likes'] = newLiked ? current + 1 : (current > 0 ? current - 1 : 0);
    });

    if (widget.onLikeToggle != null) {
      widget.onLikeToggle!(_isLiked);
    }
    
    // Remote Update
    try {
       final prefs = await SharedPreferences.getInstance();
       final userId = prefs.getString('user_id') ?? 'guest';
       
       final newCount = await ApiService.likeNews(
         widget.item['id'].toString(), 
         userId, 
         _isLiked
       );

       // Synchronize with server truth
       if (mounted) {
         setState(() {
           widget.item['likes'] = newCount;
         });
       }
    } catch (e) {
       debugPrint("Error updating likes remotely: $e");
    }
  }


  void _shareArticle() {
     ShareService.showShareOptions(context, widget.item, widget.selectedLanguage);
  }

  Future<void> _launchLiveLink() async {
    final liveLink = widget.item['live_link'];
    if (liveLink != null && liveLink.toString().isNotEmpty) {
      String urlString = liveLink.toString().trim();
      if (!urlString.startsWith('http')) {
        urlString = 'https://$urlString';
      }
      final uri = Uri.parse(urlString);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint("Could not launch $uri: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the live link.')));
        }
      }
    }
  }

  void _toggleImageExpansion() {
    setState(() {
      _isImageExpanded = !_isImageExpanded;
    });
  }

  IconData _getCategoryIcon(String? type) {
     final t = (type ?? '').toLowerCase();
     if (t.contains('politic')) return Icons.account_balance;
     if (t.contains('business')) return Icons.card_giftcard;
     if (t.contains('sport')) return Icons.emoji_events;
     if (t.contains('weather')) return Icons.wb_cloudy;
     if (t.contains('crime')) return Icons.gavel;
     if (t.contains('education')) return Icons.school;
     if (t.contains('accident')) return Icons.car_crash;
     if (t.contains('social')) return Icons.people;
     return Icons.article;
  }
  
  String _getCategoryDisplayName(String? type) {
    final isEnglish = widget.selectedLanguage.toLowerCase().contains("english") ||
        widget.selectedLanguage.contains("ఇంగ్లీష్");
    if (type == null) return isEnglish ? 'General' : 'సాధారణం';
    final t = type.toLowerCase();
    
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
    
    return type.toUpperCase();
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? color : (isDark ? const Color(0xFFFFC107) : Colors.black87),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? color : (isDark ? Colors.white70 : Colors.black87),
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
     final isEnglish = widget.selectedLanguage.toLowerCase().contains("english") ||
        widget.selectedLanguage.contains("ఇంగ్లీష్");
    final item = widget.item;
    final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
    final timeStr = timestamp != null ? _getTimeAgo(timestamp) : 'Recent';
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final metaColor = isDark ? Colors.white38 : Colors.black45;

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
               // Top Handle and Close
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
                    ),
                  ],
                ),
               ),
               
               Expanded(
                 child: SingleChildScrollView(
                   controller: scrollController,
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        // Image
                        // Video, YouTube or Image
                        if (_ytController != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: YoutubePlayer(
                                    controller: _ytController!,
                                    aspectRatio: 16 / 9,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const ScrollingWatermark(),
                              ],
                            ),
                          )
                        else if (_videoController != null && _initializeVideoPlayerFuture != null)
                          FutureBuilder(
                            future: _initializeVideoPlayerFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done) {
                                if (snapshot.hasError || !_videoController!.value.isInitialized) {
                                  return Container(
                                    height: 200,
                                    margin: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.white54, size: 40),
                                          const SizedBox(height: 8),
                                          const Text("Failed to load video", style: TextStyle(color: Colors.white54)),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: AspectRatio(
                                      aspectRatio: _videoController!.value.aspectRatio,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          VideoPlayer(_videoController!),
                                          const Positioned(
                                            top: 20,
                                            left: 0,
                                            right: 0,
                                            child: ScrollingWatermark(),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                if (_videoController!.value.isPlaying) {
                                                  _videoController!.pause();
                                                } else {
                                                  _videoController!.play();
                                                }
                                              });
                                            },
                                            child: Container(
                                              color: Colors.transparent, // Create touch target
                                              child: Center(
                                                child: Icon(
                                                  _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                                  size: 64,
                                                  color: Colors.white.withOpacity(0.7),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                return const SizedBox(
                                  height: 200, 
                                  child: Center(child: CircularProgressIndicator(color: const Color(0xFFFFC107)))
                                );
                              }
                            },
                          )
                        else if (item['image_url'] != null && item['image_url'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: GestureDetector(
                              onTap: _toggleImageExpansion,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: _isImageExpanded 
                                  ? InteractiveViewer(
                                      child: Image.network(ApiService.normalizeUrl(item['image_url']), fit: BoxFit.contain),
                                    )
                                  : Image.network(
                                      ApiService.normalizeUrl(item['image_url']),
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                      errorBuilder: (c,e,s) => Container(height: 200, color: Colors.white10, child: Icon(Icons.broken_image, color: Colors.white24)),
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
                               color: isDark ? const Color(0xFF12355A) : Colors.grey[300],
                               borderRadius: BorderRadius.circular(20),
                             ),
                             child: Icon(_getCategoryIcon(item['type']), size: 60, color: subTextColor),
                          ),
                          
                        // Action Buttons (Like, Share, Voice)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionButton(
                                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                                  label: "${widget.item['likes'] ?? 0}",
                                  onTap: _toggleLike,
                                  isActive: _isLiked,
                                  color: Colors.red,
                                ),
                                _buildActionButton(
                                  icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  label: isEnglish ? (_isSaved ? "Saved" : "Save") : (_isSaved ? "సేవ్డ్" : "సేవ్"),
                                  onTap: _toggleSave,
                                  isActive: _isSaved,
                                  color: const Color(0xFFFFC107),
                                ),
                                if (item['live_link'] != null && item['live_link'].toString().isNotEmpty)
                                  _buildActionButton(
                                    icon: Icons.live_tv,
                                    label: "LIVE",
                                    onTap: _launchLiveLink,
                                    isActive: true, // Always "active" color
                                    color: Colors.redAccent,
                                  ),
                                _buildActionButton(
                                  icon: Icons.share,
                                  label: isEnglish ? "Share" : "షేర్",
                                  onTap: _shareArticle,
                                  isActive: false,
                                  color: subTextColor,
                                ),
                                _buildActionButton(
                                  icon: _isPlaying ? Icons.stop : Icons.volume_up,
                                  label: _isPlaying ? (isEnglish ? "Stop" : "ఆపు") : (isEnglish ? "Voice" : "వాయిస్"),
                                  onTap: _toggleVoiceOver,
                                  isActive: _isPlaying,
                                  color: const Color(0xFFFFC107),
                                ),
                                 _buildActionButton(
                                  icon: Icons.speed,
                                  label: "${_currentSpeechRate}x",
                                  onTap: _showSpeedMenu,
                                  isActive: _currentSpeechRate != 1.0,
                                  color: const Color(0xFFFFC107),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               // Category & Time
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFC107).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      _getCategoryDisplayName(item['type']),
                                      style: const TextStyle(
                                        color: const Color(0xFFFFC107),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(timeStr, style: TextStyle(color: metaColor, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // Title
                              TranslatedText(
                                item['title'] ?? '',
                                language: widget.selectedLanguage,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Author
                              Row(
                                children: [
                                  Icon(Icons.person, size: 16, color: const Color(0xFFFFC107)),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(isEnglish ? "By" : "ద్వారా")}: ${item['author'] ?? 'Admin'}",
                                    style: const TextStyle(
                                      color: const Color(0xFFFFC107),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Divider(color: isDark ? Colors.white12 : Colors.black12, thickness: 1),
                              ),
                              
                              // Description
                              Builder(
                                builder: (context) {
                                  String desc = item['description'] ?? '';
                                  final link = item['live_link']?.toString() ?? '';
                                  if (link.isNotEmpty) {
                                    // Remove the link from description if it's explicitly there
                                    desc = desc.replaceAll(link, '').trim();
                                    // Also remove the same link if it doesn't have https/http prefix in desc
                                    final plainLink = link.replaceAll(RegExp(r'https?://'), '');
                                    desc = desc.replaceAll(plainLink, '').trim();
                                  }
                                  
                                  return TranslatedText(
                                    desc,
                                    language: widget.selectedLanguage,
                                    style: TextStyle(
                                      color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
                                      fontSize: 16,
                                      height: 1.8,
                                    ),
                                  );
                                },
                              ),
                              
                              // Marriage Details Section
                              if ((item['type']?.toString().toLowerCase().trim() == 'marriage' || 
                                   item['type']?.toString().trim() == 'పెళ్లి పందిరి' || 
                                   item['type']?.toString().trim() == 'పెళ్ళి పందిరి' ||
                                   item['type']?.toString().trim() == 'వివాహ వేడుక' ||
                                   item['type']?.toString().toLowerCase().trim() == 'vivaha veduka') && 
                                  item['marriage_details'] != null)
                                _buildMarriageProfile(Map<String, dynamic>.from(item['marriage_details'])),
                              const SizedBox(height: 100),
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
