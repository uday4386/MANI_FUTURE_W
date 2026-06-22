import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_screen.dart';
import '../widgets/app_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> pages = [
    {
      "title": "మీ ప్రాంతం వార్తలు",
      "subtitle": "మీ ఊరి, జిల్లా మరియు రాష్ట్ర వార్తలు ఒకే చోట పొందండి",
    },
    {
      "title": "తాజా అప్‌డేట్స్",
      "subtitle": "ట్రెండింగ్ న్యూస్ మరియు ముఖ్యమైన ఈవెంట్స్ గురించి తక్షణ సమాచారం పొందండి",
    },
    {
      "title": "పౌర జర్నలిస్ట్",
      "subtitle":
      "మీ చుట్టూ జరుగుతున్న సంఘటనలను నివేదించండి మరియు మీ ప్రాంత సమాచారాన్ని భాగస్వామ్యం చేయండి",
    },
  ];

  void goToNext() {
    if (_currentIndex < pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _markOnboardingCompleteAndGoToLanguage();
    }
  }

  void skip() {
    _markOnboardingCompleteAndGoToLanguage();
  }

  Future<void> _markOnboardingCompleteAndGoToLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LanguageScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final dotInactiveColor = isDark ? Colors.white30 : Colors.black12;
    final cardColor = isDark ? const Color(0xFF173B60) : Colors.grey[200];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLogo(fontSize: 32),
                      const SizedBox(height: 40),
                      Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardColor,
                        ),
                        child: Icon(Icons.article,
                            size: 48, color: isDark ? Colors.white : Colors.black54),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        page["title"]!,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          page["subtitle"]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.all(4),
                  height: 6,
                  width: _currentIndex == index ? 20 : 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? const Color(0xFFFFC107)
                        : dotInactiveColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
            const SizedBox(height: 30),

            // ✅ Two buttons at bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip button
                  TextButton(
                    onPressed: skip,
                    child: Text(
                      "దాటవేయండి",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Next / Start button
                  ElevatedButton(
                    onPressed: goToNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _currentIndex == pages.length - 1
                          ? "ప్రారంభించండి"
                          : "తరువాత",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
