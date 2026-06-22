import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_logo.dart';

/// About app screen – same theme as the rest of the app.
class AboutScreen extends StatelessWidget {
  final String selectedLanguage;

  const AboutScreen({super.key, required this.selectedLanguage});

  static const accentYellow = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.15);
    final isEnglish = selectedLanguage.toLowerCase().contains("english") ||
        selectedLanguage.contains("ఇంగ్లీష్");

    final appName = "సామాన్యుడు";
    final taglineEn = "Your local news in one place.";
    final taglineTe = "మీ ప్రాంత వార్తలు ఒకే చోట.";
    final version = "1.0.1";
    final descEn =
        "Stay updated with local news, weather, events, and alerts from your region in Telugu or English.";
    final descTe =
        "మీ ప్రాంతం నుండి తెలుగు లేదా ఇంగ్లీష్‌లో స్థానిక వార్తలు, వాతావరణం, ఈవెంట్స్ మరియు హెచ్చరికలతో నవీకరించబడండి.";

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bgColor = Theme.of(context).scaffoldBackgroundColor;
      final cardColor = Theme.of(context).cardColor;
      final textColor = isDark ? Colors.white : Colors.black87;

      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20 * scale),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isEnglish ? "About App" : "యాప్ గురించి",
            style: TextStyle(
              color: textColor,
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
            ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24 * scale),
          child: Column(
            children: [
              SizedBox(height: 24 * scale),
              // App Logo
              const AppLogo(fontSize: 100),
              SizedBox(height: 20 * scale),
              Text(
                isEnglish ? taglineEn : taglineTe,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accentYellow,
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8 * scale),
              Text(
                "Version $version",
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 13 * scale,
                ),
              ),
              SizedBox(height: 32 * scale),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18 * scale),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16 * scale),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Text(
                  isEnglish ? descEn : descTe,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 14 * scale,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 24 * scale),
              // Privacy Policy Button
              TextButton(
                onPressed: () => _launchPrivacyPolicy(),
                child: Text(
                  isEnglish ? "Privacy Policy" : "ప్రైవసీ పాలసీ",
                  style: TextStyle(
                    color: accentYellow,
                    decoration: TextDecoration.underline,
                    fontSize: 14 * scale,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchPrivacyPolicy() async {
    final uri = Uri.parse('https://samanyudutv.in/privacy-policy/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
