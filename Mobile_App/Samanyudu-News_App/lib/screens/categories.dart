import 'package:flutter/material.dart';
import 'category_detail_screen.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

class CategoriesScreen extends StatefulWidget {
  final String selectedLanguage;
  const CategoriesScreen({super.key, required this.selectedLanguage});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Map<String, String> text;
  List<Map<String, dynamic>> categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguageText();
    _fetchCategoryCounts();
  }

  Future<void> _fetchCategoryCounts() async {
    try {
      setState(() {
        _loading = true;
      });
      
      // Fetch all articles and filter for published ones (including null status)
      final response = await ApiService.getNews();
      
      debugPrint("Total articles fetched: ${response.length}");
      
      final Map<String, int> counts = {};
      int publishedCount = 0;
      final Set<String> allTypes = {}; // Track all unique types found
      
      for (var row in response) {
        final status = row['status'] as String?;
        // Count if status is 'published' or null/empty (legacy articles are considered published)
        if (status == null || status.toString().isEmpty || status.toString().toLowerCase() == 'published') {
          String type = (row['type'] as String?)?.trim() ?? 'Others';
          
          // Group Marriage synonyms
          final lowType = type.toLowerCase();
          if (lowType == 'marriage' || lowType == 'పెళ్ళి పందిరి' || lowType == 'పెళ్లి పందిరి' || lowType == 'వివాహ వేడుక') {
            type = 'Marriage';
          }
          
          allTypes.add(type); // Track unique types
          counts[type] = (counts[type] ?? 0) + 1;
          publishedCount++;
        }
      }
      
      debugPrint("Published articles: $publishedCount");
      debugPrint("All unique types found in DB: $allTypes");
      debugPrint("Category counts before mapping: $counts");

      final isEnglish = widget.selectedLanguage.toLowerCase().contains("english");
      
      // Map of DB types to Display names/icons - matching admin dashboard categories
      final availableTypes = [
        {'id': 'Political', 'en': 'Politics', 'te': 'రాజకీయాలు', 'icon': Icons.account_balance},
        {'id': 'AndhraPradesh', 'en': 'Andhra Pradesh', 'te': 'ఆంధ్రప్రదేశ్', 'icon': Icons.location_city},
        {'id': 'Telangana', 'en': 'Telangana', 'te': 'తెలంగాణ', 'icon': Icons.map},
        {'id': 'National', 'en': 'National', 'te': 'జాతీయం', 'icon': Icons.flag},
        {'id': 'International', 'en': 'International', 'te': 'అంతర్జాతీయ', 'icon': Icons.public},
        {'id': 'Crime', 'en': 'Crime Report', 'te': 'క్రైం రిపోర్ట్', 'icon': Icons.gavel},
        {'id': 'Education', 'en': 'Education', 'te': 'విద్య', 'icon': Icons.school},
        {'id': 'Jobs', 'en': 'Jobs', 'te': 'ఉద్యోగం', 'icon': Icons.work},
        {'id': 'Classifieds', 'en': 'Classifieds', 'te': 'క్లాసిఫైడ్స్', 'icon': Icons.campaign},
        {'id': 'Live', 'en': 'Live TV', 'te': 'లైవ్ టీవీ', 'icon': Icons.live_tv},
        {'id': 'Business', 'en': 'Business', 'te': 'వ్యాపారం', 'icon': Icons.business},
        {'id': 'Sports', 'en': 'Sports', 'te': 'క్రీడలు', 'icon': Icons.sports_cricket},
        {'id': 'Agriculture', 'en': 'Agriculture', 'te': 'వ్యవసాయం', 'icon': Icons.agriculture},
        {'id': 'Marriage', 'en': 'Vivaha Veduka', 'te': 'వివాహ వేడుక', 'icon': Icons.favorite, 'color': Colors.pink},
        {'id': 'RealEstate', 'en': 'Real Estate', 'te': 'రియల్ ఎస్టేట్', 'icon': Icons.home},
        {'id': 'Bhakthi', 'en': 'Bhakthi', 'te': 'భక్తి', 'icon': Icons.church},
        {'id': 'Health', 'en': 'Health', 'te': 'ఆరోగ్యం', 'icon': Icons.health_and_safety},
        {'id': 'Social', 'en': 'Social', 'te': 'సామాజిక', 'icon': Icons.people},
        {'id': 'Accident', 'en': 'Accident', 'te': 'ప్రమాదం', 'icon': Icons.warning},
        {'id': 'Others', 'en': 'Others', 'te': 'ఇతరం', 'icon': Icons.more_horiz},
      ];

      if (mounted) {
        setState(() {
          categories = availableTypes.map((t) {
            final categoryId = t['id'] as String;
            final count = counts[categoryId] ?? 0;
            debugPrint("Category '${t['en']}' (id: $categoryId): count = $count");
            return {
              "id": categoryId,
              "title": isEnglish ? t['en'] : t['te'],
              "count": count.toString(),
              "icon": t['icon'],
              "desc": isEnglish ? "Latest news from ${t['en']} category." : "${t['te']} విభాగం నుండి తాజా వార్తలు.",
            };
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching category counts: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadLanguageText() {
    final lang = widget.selectedLanguage.toLowerCase();
    final isEnglish =
        lang.contains("english") || widget.selectedLanguage.contains("ఇంగ్లీష్");

    if (isEnglish) {
      text = {
        "title": "News Categories",
        "subtitle": "Choose your preferred category",
        "newsCount": "news",
      };
    } else {
      text = {
        "title": "వార్త వర్గాలు",
        "subtitle": "మీకు ఇష్టమైన వర్గాన్ని ఎంచుకోండి",
        "newsCount": "వార్తలు",
      };
    }
  }

  void _onCategoryTap(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
          categoryId: item["id"] as String,
          categoryTitle: item["title"] as String,
          count: item["count"] as String,
          icon: item["icon"] as IconData,
          selectedLanguage: widget.selectedLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final iconBg = isDark ? const Color(0xFF1E446B) : Colors.amber.withOpacity(0.2);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    final size = MediaQuery.of(context).size;
    final double scale = (size.width / 390).clamp(0.85, 1.15);

    return Scaffold(
      backgroundColor: bgColor,

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16 * scale, 16 * scale, 16 * scale, 4),
              child: Text(
                text["title"]!,
                style: TextStyle(
                  color: textColor,
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 8 * scale),
              child: Text(
                text["subtitle"]!,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 14 * scale,
                ),
              ),
            ),
            SizedBox(height: 4 * scale),
            Expanded(
              child: _loading 
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : RefreshIndicator(
                      onRefresh: _fetchCategoryCounts,
                      color: Colors.amber,
                      backgroundColor: cardColor,
                      child: GridView.builder(
                        padding: EdgeInsets.all(16 * scale),
                        itemCount: categories.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16 * scale,
                          crossAxisSpacing: 16 * scale,
                          childAspectRatio: 1.05,
                        ),
                        itemBuilder: (context, index) {
                  final item = categories[index];
                  final countStr =
                      "${item["count"]} ${text["newsCount"]}";
                  return GestureDetector(
                    onTap: () => _onCategoryTap(item),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16 * scale),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(14 * scale),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius:
                                  BorderRadius.circular(14 * scale),
                            ),
                            child: Icon(
                              item["icon"] as IconData,
                              color: isDark ? Colors.white : Colors.amber[800],
                              size: 26 * scale,
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          Text(
                            item["title"] as String,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14 * scale,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            countStr,
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12 * scale,
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
