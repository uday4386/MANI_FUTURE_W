import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import '../widgets/app_logo.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String? selectedLanguage;

  void goToMain() async {
    if (selectedLanguage != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', selectedLanguage!);
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(selectedLanguage: selectedLanguage!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('దయచేసి భాషను ఎంచుకోండి / Please select a language'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }



  Widget buildLanguageCard(BuildContext context, String language, String subtitle) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSelected = selectedLanguage == language;
    
    final cardColor = isDark ? const Color(0xFF173B60) : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return GestureDetector(
      onTap: () => setState(() => selectedLanguage = language),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFC107) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off_outlined,
              color: isSelected ? const Color(0xFFFFC107) : subColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const AppLogo(fontSize: 32),
                const SizedBox(height: 40),
                Text(
                  "భాషను ఎంచుకోండి",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Select your language",
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 50),
              
                // Language Options
                buildLanguageCard(context, "తెలుగు", "Telugu"),
                buildLanguageCard(context, "English", "ఇంగ్లీష్"),
              
                const SizedBox(height: 40),
              
                // Continue Button
                ElevatedButton(
                  onPressed: goToMain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 70, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    "తరువాత",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
