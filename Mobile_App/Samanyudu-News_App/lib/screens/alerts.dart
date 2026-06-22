import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'vertical_news_pager.dart';
import '../services/notification_service.dart';

class AlertsScreen extends StatefulWidget {
  final String selectedLanguage;
  const AlertsScreen({super.key, required this.selectedLanguage});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Map<String, String> text;
  List<Map<String, dynamic>> _realAlerts = [];
  bool _loading = true;
  String? _userName;
  // RealtimeChannel? _alertSubscription;

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  void _onNotificationUpdate() {
    if (mounted) {
      _fetchAlerts();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLanguageText();
    _loadUserProfile();
    _fetchAlerts();
    _setupRealtime();
    NotificationService.updateCount.addListener(_onNotificationUpdate);
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name');
    });
  }

  void _setupRealtime() {
    // Unplugged while migrating to local backend
  }

  @override
  void dispose() {
    NotificationService.updateCount.removeListener(_onNotificationUpdate);
    super.dispose();
  }

  Future<void> _fetchAlerts() async {
    try {
      final response = await ApiService.getNews();
      
      debugPrint("Alerts fetched: ${response.length}");
      
      if (mounted) {
        setState(() {
          _realAlerts = response.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching alerts: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadLanguageText() {
    if (_isEnglish) {
      text = {
        "title": "Alerts & Notices",
        "subtitle": "Important alerts and announcements",
        "posted": "Posted",
      };
    } else {
      text = {
        "title": "హెచ్చరికలు & నోటీసులు",
        "subtitle": "ముఖ్యమైన హెచ్చరికలు మరియు ప్రకటనలు",
        "posted": "పోస్ట్ చేయబడినది",
      };
    }
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return "";
    final dt = DateTime.parse(timestamp);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    return "${diff.inMinutes}m ago";
  }

  Color _getCategoryColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'political': return Colors.red;
      case 'crime': return Colors.deepOrange;
      case 'weather': return Colors.blue;
      default: return Colors.amber;
    }
  }

  IconData _getCategoryIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'political': return Icons.warning;
      case 'weather': return Icons.cloud;
      default: return Icons.info;
    }
  }

  void _onAlertTap(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerticalNewsPager(
          newsList: _realAlerts,
          initialIndex: index,
          selectedLanguage: widget.selectedLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    final size = MediaQuery.of(context).size;
    final double scale = (size.width / 390).clamp(0.85, 1.15);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16 * scale, 16 * scale, 16 * scale, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text["title"]!,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16 * scale, 0, 16 * scale, 12 * scale),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text["subtitle"]!,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 14 * scale,
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchAlerts,
                color: const Color(0xFFFFC107),
                backgroundColor: Theme.of(context).cardColor,
                child: _loading 
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : _realAlerts.isEmpty 
                    ? Center(child: Text("No alerts available", style: TextStyle(color: subTextColor)))
                    : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                  itemCount: _realAlerts.length,
                itemBuilder: (context, index) {
                  final item = _realAlerts[index];
                  final timeStr = _getTimeAgo(item['timestamp']);
                  final color = _getCategoryColor(item['type']);
                  final icon = _getCategoryIcon(item['type']);

                  final isMyPost = _userName != null && item['author'] == _userName;
                  final notificationTitle = isMyPost 
                      ? (_isEnglish ? "Your post approved" : "మీ పోస్ట్ ఆమోదించబడింది")
                      : (_isEnglish ? "New Update" : "కొత్త అప్‌డేట్");

                  return GestureDetector(
                    onTap: () => _onAlertTap(index),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 14 * scale),
                      padding: EdgeInsets.all(14 * scale),
                      decoration: BoxDecoration(
                        color: isMyPost ? (isDark ? Colors.teal.withOpacity(0.1) : Colors.teal.withOpacity(0.05)) : null,
                        gradient: !isMyPost ? LinearGradient(
                          colors: [
                            color.withOpacity(0.25),
                            color.withOpacity(0.08),
                          ],
                        ) : null,
                        borderRadius:
                            BorderRadius.circular(16 * scale),
                        border: Border.all(
                            color: isMyPost ? Colors.teal : color.withOpacity(0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(10 * scale),
                            decoration: BoxDecoration(
                              color: isMyPost ? Colors.teal : color,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isMyPost ? Icons.check_circle : icon,
                              color: Colors.white,
                              size: 20 * scale,
                            ),
                          ),
                          SizedBox(width: 12 * scale),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notificationTitle,
                                  style: TextStyle(
                                    color: isMyPost ? Colors.teal : (isDark ? Colors.white70 : Colors.black54),
                                    fontSize: 12 * scale,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4 * scale),
                                Text(
                                  item['title'] ?? '',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15 * scale,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6 * scale),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14 * scale,
                                      color: isDark ? Colors.white54 : const Color(0xFF616161),
                                    ),
                                    SizedBox(width: 4 * scale),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : const Color(0xFF616161),
                                        fontSize: 11 * scale,
                                      ),
                                    ),
                                  ],
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
            ),
          ],
        ),
      ),
    );
  }
}

class AlertItem {
  final String title;
  final String description;
  final String timeKey;
  final Color color;
  final IconData icon;

  AlertItem({
    required this.title,
    required this.description,
    required this.timeKey,
    required this.color,
    required this.icon,
  });
}
