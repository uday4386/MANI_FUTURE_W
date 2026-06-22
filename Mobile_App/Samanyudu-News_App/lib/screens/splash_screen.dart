import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'language_screen.dart';
import 'login_screen.dart';
import 'main_navigation.dart';
import '../widgets/app_logo.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _currentLineIndex = -1;
  bool _logoAtTop = false;

  final List<String> _textLines = [
    "సామాన్యుడి చేత",
    "సామాన్యుడి కొరకు",
    "సామాన్యుడి యొక్క",
    "సామాన్యుడి TV",
    "ప్రతి సామాన్యుడు ఒక జర్నలిస్టు"
  ];

  @override
  void initState() {
    super.initState();
    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    // 1. Show logo in center for 0.7 second
    await Future.delayed(const Duration(milliseconds: 700));
    
    if (!mounted) return;
    setState(() {
      _logoAtTop = true;
    });

    // 2. Wait for logo to move up
    await Future.delayed(const Duration(milliseconds: 400));

    // 3. Show lines one by one (faster reveal)
    for (int i = 0; i < _textLines.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentLineIndex = i;
      });
      await Future.delayed(const Duration(milliseconds: 1400));
    }

    // 4. Final delay before navigation
    await Future.delayed(const Duration(milliseconds: 500));
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    final prefsFuture = SharedPreferences.getInstance();

    if (!mounted) return;

    SharedPreferences? prefs;
    try {
      prefs = await prefsFuture.timeout(const Duration(milliseconds: 400));
    } on TimeoutException {
      prefs = null;
    }

    if (prefs == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageScreen()),
      );
      return;
    }

    final hasSeenOnboarding = prefs.getBool('onboarding_complete') ?? false;
    final selectedLanguage = prefs.getString('selected_language');
    final userId = prefs.getString('user_id');
    
    if (!mounted) return;

    if (!hasSeenOnboarding) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    if (selectedLanguage == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageScreen()),
      );
      return;
    }

    if (userId != null && userId.isNotEmpty) {
      ApiService.syncUserLikes(userId);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigation(selectedLanguage: selectedLanguage),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(selectedLanguage: selectedLanguage),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: Stack(
        children: [
          // Background subtle pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/images/splash_pattern.png',
                repeat: ImageRepeat.repeat,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Main Center Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with subtle transition
                AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.elasticOut,
                  transform: Matrix4.translationValues(0, _logoAtTop ? -200 : 0, 0),
                  child: const AppLogo(fontSize: 100),
                ),
                
                const SizedBox(height: 15), // Slightly more space for larger text

                // Sequential Text Lines - Cinematic Blur Reveal
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final blurSigma = (1.0 - animation.value) * 10.0;
                          return ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  child: _currentLineIndex == -1
                      ? const SizedBox.shrink()
                      : _currentLineIndex < 4
                          ? Row(
                              key: const ValueKey("prefix_row"),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "సామాన్యుడి ",
                                  style: GoogleFonts.notoSansTelugu(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0B2A45),
                                    height: 1.4,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 600),
                                  transitionBuilder: (child, animation) => FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                  child: Text(
                                    _textLines[_currentLineIndex].replaceFirst("సామాన్యుడి", "").trim(),
                                    key: ValueKey<int>(_currentLineIndex),
                                    style: GoogleFonts.notoSansTelugu(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0B2A45),
                                      height: 1.4,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _textLines[_currentLineIndex],
                              key: const ValueKey("last_line"),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSansTelugu(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0B2A45),
                                height: 1.4,
                                letterSpacing: 0.8,
                              ),
                            ),
                ),
              ],
            ),
          ),
          
          // Subtle Footer
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.8,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2A45).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "SAMANYUDU TV MEDIA",
                    style: TextStyle(
                      color: Color(0xFF0B2A45),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
