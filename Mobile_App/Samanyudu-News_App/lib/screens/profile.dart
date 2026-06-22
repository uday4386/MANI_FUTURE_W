import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_screen.dart';
import 'edit_profile_screen.dart';
import 'about_screen.dart';
import 'saved_items_screen.dart';
import '../theme_notifier.dart'; // Access the consistent singleton
// import 'index.dart'; // No longer needed directly for restart
import 'main_navigation.dart'; // Import MainNavigation for restarting the app
import '../services/notification_service.dart';
import 'location_screen.dart';
import '../data/locations.dart';
import 'login_screen.dart';
import '../services/api_service.dart';


class ProfileScreen extends StatefulWidget {
  final String selectedLanguage;
  const ProfileScreen({super.key, required this.selectedLanguage});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  late Map<String, String> text;
  String _profileName = "Guest";
  String _profileEmail = "Not logged in";

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  int _savedCount = 0;
  int _commentsCount = 0;
  int _notificationsCount = 0;
  String _currentTheme = "Light Mode";
  bool _notificationsEnabled = true;
  String _currentLocation = "";

  @override
  void initState() {
    super.initState();
    loadSavedData();
    _loadLanguageText();
  }

  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final newsIds = prefs.getStringList('saved_news_ids') ?? [];
    final shortsIds = prefs.getStringList('saved_shorts_ids') ?? [];
    final theme = prefs.getString('theme_mode') ?? "light";
    final notif = prefs.getBool('notifications_enabled') ?? true;
    
    final savedName = prefs.getString('user_name');
    final savedEmail = prefs.getString('user_email');

    if (mounted) {
      setState(() {
        final userId = prefs.getString('user_id');
        final guestId = prefs.getString('guest_id');
        final effectiveId = (userId != null && userId.isNotEmpty) ? userId : guestId;

        if (userId != null && userId.isNotEmpty) {
           _profileName = savedName ?? "User";
           // Try phone first, fallback to email
           _profileEmail = prefs.getString('user_phone') ?? savedEmail ?? "";
        } else {
           _profileName = _isEnglish ? "Guest" : "అతిథి";
           _profileEmail = _isEnglish ? "Not logged in" : "లాగిన్ కాలేదు";
        }
        
        _savedCount = newsIds.length + shortsIds.length;
        _currentTheme = theme == "light" ? "Light Mode" : "Dark Mode";
        _notificationsEnabled = notif;
        
        _fetchDynamicCounts(effectiveId);
        
        final city = prefs.getString('user_city');
        final district = prefs.getString('user_district');
        final state = prefs.getString('user_state');

        if (city != null && district != null) {
          String displayCity = city;
          String displayDistrict = district;

          if (!_isEnglish) {
             // Translate District
             displayDistrict = districtTranslations[district] ?? district;

             // Translate City
             if (state != null) {
                 if (locationData.containsKey(state) && locationData[state]!.containsKey(district)) {
                      int idx = locationData[state]![district]!.indexOf(city);
                      if (idx != -1 && locationDataTelugu.containsKey(state) && locationDataTelugu[state]!.containsKey(district)) {
                          var list = locationDataTelugu[state]![district];
                          if (list != null && idx < list.length) {
                              displayCity = list[idx];
                          }
                      }
                 }
             }
          }
          _currentLocation = "$displayCity, $displayDistrict"; 
        } else {
          _currentLocation = _isEnglish ? "Select Location" : "ప్రాంతం ఎంచుకోండి";
        }
      });
    }
  }

  Future<void> _fetchDynamicCounts(String? userId) async {
    int cCount = 0;
    int nCount = 0;
    
    try {
      if (userId != null && userId.isNotEmpty) {
        final stats = await ApiService.getUserStats(userId);
        cCount = stats['commentsCount'] ?? 0;
        nCount = stats['notificationsCount'] ?? 0;
      }
    } catch (e) {
      debugPrint("Error fetching dynamic counts: $e");
    }

    if (mounted) {
       setState(() {
          _commentsCount = cCount;
          _notificationsCount = nCount;
       });
    }
  }

  void _navigateToSaved() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SavedItemsScreen(selectedLanguage: widget.selectedLanguage)),
    );
    loadSavedData(); // Refresh count on return
  }

  void _notificationSettings() {
    showDialog(
      context: context,
      builder: (context) {
        // Use local state for the dialog to update UI immediately
        bool isEnabled = _notificationsEnabled;
        
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF0B2A45) : Colors.white;
            final textColor = isDark ? Colors.white : Colors.black87;

            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(text['notificationSettings']!, style: TextStyle(color: textColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(_isEnglish ? "Allow Notifications" : "నోటిఫికేషన్లు అనుమతించు", style: TextStyle(color: textColor)),
                    value: isEnabled,
                    activeThumbColor: const Color(0xFFFFC107),
                    onChanged: (val) async {
                      setState(() => isEnabled = val);
                      // Update parent state
                      this.setState(() => _notificationsEnabled = val);
                      // Call service to toggle
                      await NotificationService().toggle(val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Done", style: TextStyle(color: textColor.withOpacity(0.7))),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _changeLanguage() {
    showDialog(
      context: context,
      builder: (context) {
        String selected = _isEnglish ? "english" : "telugu";
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF0B2A45) : Colors.white;
            final textColor = isDark ? Colors.white : Colors.black87;

            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(text['language']!, style: TextStyle(color: textColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   RadioListTile<String>(
                    title: Text("English", style: TextStyle(color: textColor)),
                    value: "english",
                    groupValue: selected,
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (val) {
                       setState(() => selected = val!);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text("Telugu (తెలుగు)", style: TextStyle(color: textColor)),
                    value: "telugu",
                    groupValue: selected,
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (val) {
                       setState(() => selected = val!);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: textColor.withOpacity(0.7))),
                ),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('selected_language', selected == "english" ? "English" : "Telugu");

                    // Restart the app from MainNavigation with new language
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MainNavigation(
                          selectedLanguage: selected == "english" ? "English" : "Telugu",
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: Text("Save", style: TextStyle(color: const Color(0xFFFFC107))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _changeTheme() {
    showDialog(
      context: context,
      builder: (context) {
        String selected = _currentTheme == "Light Mode" ? "light" : "dark";
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF0B2A45) : Colors.white;
            final textColor = isDark ? Colors.white : Colors.black87;

            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(text['theme']!, style: TextStyle(color: textColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text("Dark Mode", style: TextStyle(color: textColor)),
                    value: "dark",
                    groupValue: selected,
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (val) {
                       setState(() => selected = val!);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text("Light Mode", style: TextStyle(color: textColor)),
                    value: "light",
                    groupValue: selected,
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (val) {
                       setState(() => selected = val!);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: textColor.withOpacity(0.7))),
                ),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('theme_mode', selected);
                    
                    // Update global notifier
                    themeNotifier.value = selected == 'light' ? ThemeMode.light : ThemeMode.dark;

                    Navigator.pop(context);
                    if (mounted) {
                       // Reload local data to update subtitle
                       loadSavedData();
                    }
                  },
                  child: Text("Save", style: TextStyle(color: const Color(0xFFFFC107))),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _changeLocation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationScreen(selectedLanguage: widget.selectedLanguage),
      ),
    ).then((_) => loadSavedData());
  }

  void _loadLanguageText() {
    if (_isEnglish) {
      text = {
        "name": "Raj Kumar",
        "edit": "Edit",
        "editProfile": "Edit Profile",
        "saved": "Saved",
        "comments": "Comments",
        "notifications": "Notifications",
        "following": "Following",
        "savedNews": "Saved News",
        "savedNewsSub": "0 news saved",
        "notificationSettings": "Notification Settings",
        "notificationSub": "Alerts and notifications",
        "language": "Language",
        "languageSub": "Telugu",
        "theme": "Theme",
        "themeSub": "Dark mode",
        "location": "Location",
        "shareApp": "Share App",
        "shareAppSub": "Share with friends",
        "aboutApp": "About App",
        "version": "Version 1.0.0",
        "logout": "Logout",
        "editSnack": "Edit profile – coming soon",
        "savedSnack": "Saved news – coming soon",
        "notifSnack": "Notification settings – coming soon",
        "langSnack": "Language change – coming soon",
        "themeSnack": "Theme settings – coming soon",
        "shareSnack": "Sharing app...",
        "aboutSnack": "సామాన్యుడు – Local News App v1.0.0",
        "logoutConfirm": "Are you sure you want to logout?",
        "logoutYes": "Logout",
        "logoutNo": "Cancel",
        "items": "items",
      };
    } else {
      text = {
        "name": "రాజ్ కుమార్",
        "edit": "ఎడిట్",
        "editProfile": "ప్రొఫైల్ ఎడిట్ చేయండి",
        "saved": "సేవ్ చేసినవి",
        "comments": "కామెంట్స్",
        "notifications": "నోటిఫికేషన్స్",
        "following": "ఫాలోయింగ్",
        "savedNews": "సేవ్ చేసిన వార్తలు",
        "savedNewsSub": "0 వార్తలు సేవ్ చేశారు",
        "notificationSettings": "నోటిఫికేషన్ సెట్టింగ్స్",
        "notificationSub": "నోటిఫికేషన్లు మరియు అలర్ట్స్",
        "language": "భాష",
        "languageSub": "తెలుగు",
        "theme": "థీమ్",
        "themeSub": "డార్క్ మోడ్",
        "location": "స్థానం",
        "shareApp": "యాప్ షేర్ చేయండి",
        "shareAppSub": "మీ స్నేహితులతో పంచుకోండి",
        "aboutApp": "యాప్ గురించి",
        "version": "వర్షన్ 1.0.0",
        "logout": "లాగ్ అవుట్",
        "editSnack": "ప్రొఫైల్ ఎడిట్ – త్వరలో",
        "savedSnack": "సేవ్ చేసిన వార్తలు – త్వరలో",
        "notifSnack": "నోటిఫికేషన్ సెట్టింగ్స్ – త్వరలో",
        "langSnack": "భాష మార్పు – త్వరలో",
        "themeSnack": "థీమ్ సెట్టింగ్స్ – త్వరలో",
        "shareSnack": "యాప్ షేర్ చేయడం...",
        "aboutSnack": "సామాన్యుడు – లోకల్ న్యూస్ యాప్ v1.0.0",
        "logoutConfirm": "మీరు లాగ్ అవుట్ చేయాలనుకుంటున్నారా?",
        "logoutYes": "లాగ్ అవుట్",
        "logoutNo": "రద్దు",
        "items": "అంశాలు",
      };
    }
    // Language subtitle shows current selection
    text["languageSub"] = _isEnglish ? "English" : "తెలుగు";
  }

  void _onEditProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEnglish ? "Please login first" : "ముందుగా లాగిన్ చేయండి")),
      );
      return;
    }

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          initialName: _profileName,
          initialPhone: _profileEmail,
          selectedLanguage: widget.selectedLanguage,
        ),
      ),
    );
    if (result != null && mounted) {
      final newName = result["name"] ?? _profileName;
      final newPhone = result["phone"] ?? _profileEmail;

      try {
        await ApiService.updateUserProfile(userId, newName, newPhone, _profileName);
        
        await prefs.setString('user_name', newName);
        await prefs.setString('user_phone', newPhone);

        setState(() {
          _profileName = newName;
          _profileEmail = newPhone;
        });
      } catch (e) {
        debugPrint("Update profile error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEnglish ? "Failed to update profile" : "ప్రొఫైల్ నవీకరణ విఫలమైంది")),
        );
      }
    }
  }

  void _onLogoutOrLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null || userId.isEmpty) {
       // Not logged in -> Go to Login Screen
       Navigator.push(
         context, 
         MaterialPageRoute(builder: (_) => LoginScreen(selectedLanguage: widget.selectedLanguage))
       );
       return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF0B2A45) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text(
            text["logout"]!,
            style: TextStyle(color: textColor),
          ),
          content: Text(
            text["logoutConfirm"]!,
            style: TextStyle(color: textColor.withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(text["logoutNo"]!, style: TextStyle(color: textColor.withOpacity(0.7))),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('user_id');
                await prefs.remove('user_phone');
                await prefs.remove('user_name');
                await ApiService.clearUserLikes();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguageScreen()),
                    (route) => false,
                  );
                }
              },
              child: Text(text["logoutYes"]!, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final double scale = (screenWidth / 390).clamp(0.85, 1.15);

    final isTablet = screenWidth > 600;
    final isLarge = screenWidth > 900;

    final horizontalPadding = (isTablet ? 32.0 : 16.0) * scale;
    final avatarRadius = (isTablet ? 40.0 : 28.0) * scale;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: 16 * scale),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.person,
                      color: Colors.black, size: avatarRadius),
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profileName,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        _profileEmail,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 11 * scale,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _onEditProfile,
                  icon: Icon(Icons.edit, size: 14 * scale, color: Colors.white),
                  label: Text(
                    isTablet ? text["editProfile"]! : text["edit"]!,
                    style: TextStyle(fontSize: 11 * scale, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F3B5B),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: (isTablet ? 16 : 10) * scale,
                      vertical: 8 * scale,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 24 * scale),

            isTablet
                ? GridView.count(
                    crossAxisCount: isLarge ? 4 : 3,
                    shrinkWrap: true,
                    crossAxisSpacing: 12 * scale,
                    mainAxisSpacing: 12 * scale,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatCard(
                          number: _savedCount.toString(),
                          label: text["saved"]!,
                          scale: scale),
                      StatCard(
                          number: _commentsCount.toString(),
                          label: text["comments"]!,
                          scale: scale),
                      StatCard(
                          number: _notificationsCount.toString(),
                          label: text["notifications"]!,
                          scale: scale),
                      StatCard(
                          number: "0",
                          label: text["following"]!,
                          scale: scale),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: StatCard(
                            number: _savedCount.toString(),
                            label: text["saved"]!,
                            scale: scale),
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: StatCard(
                            number: _commentsCount.toString(),
                            label: text["comments"]!,
                            scale: scale),
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: StatCard(
                            number: _notificationsCount.toString(),
                            label: text["notifications"]!,
                            scale: scale),
                      ),
                    ],
                  ),

            SizedBox(height: 24 * scale),

            SettingsTile(
              icon: Icons.bookmark_border,
              title: text["savedNews"]!,
              subtitle: "$_savedCount ${text["newsCount"] ?? (_isEnglish ? 'items' : 'అంశాలు')} ${text['saved']}",
              scale: scale,
              onTap: _navigateToSaved,
            ),
            SettingsTile(
              icon: Icons.notifications_none,
              title: text["notificationSettings"]!,
              subtitle: text["notificationSub"]!,
              scale: scale,
              onTap: _notificationSettings,
            ),
            SettingsTile(
              icon: Icons.language,
              title: text["language"]!,
              subtitle: text["languageSub"]!,
              scale: scale,
              onTap: _changeLanguage,
            ),
            SettingsTile(
              icon: Icons.dark_mode,
              title: text["theme"]!,
              subtitle: _currentTheme,
              scale: scale,
              onTap: _changeTheme,
            ),
            SettingsTile(
              icon: Icons.location_on,
              title: text["location"]!,
              subtitle: _currentLocation,
              scale: scale,
              onTap: _changeLocation,
            ),
            SettingsTile(
              icon: Icons.share,
              title: text["shareApp"]!,
              subtitle: text["shareAppSub"]!,
              scale: scale,
              onTap: () {
                Share.share(_isEnglish 
                  ? "Check out Samanyudu TV App for latest local news!" 
                  : "తాజా స్థానిక వార్తల కోసం సామాన్యుడు టీవీ యాప్‌ని చూడండి!");
              },
            ),
            SettingsTile(
              icon: Icons.info_outline,
              title: text["aboutApp"]!,
              subtitle: text["version"]!,
              scale: scale,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AboutScreen(
                    selectedLanguage: widget.selectedLanguage,
                  ),
                ),
              ),
            ),

            SizedBox(height: 24 * scale),

            ElevatedButton.icon(
              onPressed: _onLogoutOrLogin,
              icon: Icon((_profileEmail == "Not logged in" || _profileEmail == "లాగిన్ కాలేదు") ? Icons.login : Icons.logout, size: 18 * scale),
              label: Text(
                (_profileEmail == "Not logged in" || _profileEmail == "లాగిన్ కాలేదు")
                   ? (_isEnglish ? 'Login' : 'లాగిన్') 
                   : text["logout"]!,
                style: TextStyle(fontSize: 14 * scale),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 16 * scale : 14 * scale),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14 * scale),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String number;
  final String label;
  final double scale;

  const StatCard({
    super.key,
    required this.number,
    required this.label,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14 * scale),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            number,
            style: TextStyle(
              color: Colors.amber,
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 11 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double scale;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.scale,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: ListTile(
        onTap: onTap ?? () {},
        leading: Icon(
          icon,
          color: Colors.amber,
          size: (isTablet ? 26 : 22) * scale,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            fontSize: 14 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54,
            fontSize: 11 * scale,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38,
          size: 18 * scale,
        ),
      ),
    );
  }
}
