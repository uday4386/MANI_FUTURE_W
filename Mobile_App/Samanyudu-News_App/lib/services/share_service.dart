
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:translator/translator.dart';
import '../services/api_service.dart';
import '../widgets/media_thumbnail_widget.dart';

class ShareService {
  static Future<void> showShareOptions(
    BuildContext context, 
    Map<String, dynamic> item, 
    String selectedLanguage,
  ) async {
    return _shareWithImage(context, item, selectedLanguage);
  }

  static Future<void> shareText(Map<String, dynamic> item) async {
    final title = item['title'] ?? '';
    final description = item['description'] ?? '';
    const String appLink = "https://play.google.com/store/apps/details?id=com.samanyudu.news"; 
    
    await Share.share("$title\n\n$description\n\nRead more on Samanyudu TV App:\n$appLink");
  }

  static Future<void> _shareWithImage(
    BuildContext context, 
    Map<String, dynamic> item, 
    String selectedLanguage,
  ) async {
    // Show loading
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: const Color(0xFFFFC107))),
    );

    try {
      final screenshotController = ScreenshotController();
      
      final isTelugu = selectedLanguage.contains('తెలుగు') || 
                       selectedLanguage.toLowerCase().contains('telugu');
      final targetLang = isTelugu ? 'te' : 'en';

      final title = await _getTranslatedString(item['title'] ?? '', targetLang);
      String description = await _getTranslatedString(item['description'] ?? '', targetLang);
      final imageUrl = item['image_url'];

      // Handle Marriage Details
      final type = item['type']?.toString().toLowerCase().trim() ?? '';
      final isMarriage = type == 'marriage' || type == 'పెళ్లి పందిరి' || type == 'పెళ్ళి పందిరి' || type == 'వివాహ వేడుక';
      
      String marriageDetailsStr = "";
      if (isMarriage) {
        marriageDetailsStr = _formatMarriageDetails(item, isTelugu);
        if (marriageDetailsStr.isNotEmpty) {
          description = "$description\n\n$marriageDetailsStr";
        }
      }
      final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());
      const String webLink = "https://play.google.com/store/apps/details?id=com.samanyudu.news";

      if (imageUrl != null && imageUrl.toString().isNotEmpty) {
        try {
          await precacheImage(NetworkImage(ApiService.normalizeUrl(imageUrl)), context);
        } catch (e) {
          debugPrint("Failed to precache image: $e");
        }
      }

      try {
        await precacheImage(const AssetImage('assets/app_logo_new.png'), context);
      } catch (e) {
        debugPrint("Failed to precache logo: $e");
      }

      // Create the Template Widget wrapped in Material and Directionality
      final shareWidget = Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Material(
          color: Colors.white,
          child: _buildShareTemplate(
            item: item,
            title: title,
            description: description,
            dateStr: dateStr,
            webLink: webLink,
            isTelugu: isTelugu,
          ),
        ),
      );

      debugPrint("Starting captureFromWidget...");
      final Uint8List imageBytes = await screenshotController.captureFromWidget(
        shareWidget,
        delay: const Duration(milliseconds: 900), 
        pixelRatio: 2.0,
        context: context,
      );
      debugPrint("Captured ${imageBytes.length} bytes");
      
      if (imageBytes.isEmpty) {
        throw Exception("Failed to capture image: Byte array is empty");
      }

      XFile file;
      if (kIsWeb) {
         file = XFile.fromData(
           imageBytes, 
           mimeType: 'image/jpeg', 
           name: 'news_share.jpg',
           lastModified: DateTime.now()
         );
      } else {
         final directory = await getTemporaryDirectory();
         final imagePath = await File('${directory.path}/news_share.jpg').create();
         await imagePath.writeAsBytes(imageBytes);
         file = XFile(imagePath.path, mimeType: 'image/jpeg');
      }

      // Dismiss loading
      if (context.mounted) Navigator.pop(context); 

      String shareCaption = "📲 యాప్ లింక్: $webLink\n\n$title\n";
      if (isMarriage && marriageDetailsStr.isNotEmpty) {
        shareCaption += "\n$marriageDetailsStr\n";
      }
      shareCaption += "\nమరింత సమాచారం కోసం మా యాప్ డౌన్లోడ్ చేసుకోండి.";

      await Share.shareXFiles(
        [file],
        text: shareCaption,
        subject: "News from Samanyudu TV",
      );

    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Error sharing image: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Share Error: $e")),
        );
      }
    }
  }

  static Widget _buildShareTemplate({
    required Map<String, dynamic> item,
    required String title,
    required String description,
    required String dateStr,
    required String webLink,
    required bool isTelugu,
  }) {
    // Aggressive Dynamic scaling for long content
    double titleFontSize = 19.0;
    double descriptionFontSize = 15.0;
    double textLineHeight = 1.5;
    double imageMaxHeight = 350.0;
    double verticalSpacing = 15.0;

    if (description.length > 800) {
      descriptionFontSize = 11.0;
      titleFontSize = 16.0;
      textLineHeight = 1.25;
      imageMaxHeight = 200.0;
      verticalSpacing = 8.0;
    } else if (description.length > 500) {
      descriptionFontSize = 12.5;
      titleFontSize = 17.5;
      textLineHeight = 1.35;
      imageMaxHeight = 250.0;
      verticalSpacing = 10.0;
    } else if (description.length > 250) {
      descriptionFontSize = 14.0;
      textLineHeight = 1.45;
    }

    final hasImage = (item['image_url']?.toString() ?? '').isNotEmpty;
    final hasVideo = (item['video_url']?.toString() ?? '').isNotEmpty;
    final hasLive = (item['live_link']?.toString() ?? '').isNotEmpty;
    
    double currentImageHeight = (hasImage || hasVideo || hasLive) ? imageMaxHeight : 120.0;

    return Container(
      width: 500,
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image / Video Thumbnail
              if (hasImage || hasVideo || hasLive)
                Container(
                  height: currentImageHeight,
                  width: double.infinity,
                  color: Colors.black,
                  child: MediaThumbnailWidget(
                    item: item,
                    height: currentImageHeight,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  height: currentImageHeight,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.newspaper, size: 50, color: Colors.grey),
                  ),
                ),

              // 3. Content Area
              Padding(
                // Increased top padding to ensure the overflowing centered logo doesn't cover text
                padding: const EdgeInsets.fromLTRB(18, 35, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSansTelugu(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: verticalSpacing),
                    Text(
                      description,
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.notoSansTelugu(
                        fontSize: descriptionFontSize,
                        color: Colors.black87,
                        height: textLineHeight,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),

          // 4. Footer
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 15),
            child: Column(
              children: [
                const Divider(color: Colors.grey, thickness: 0.5),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTelugu ? "సామాన్యుడు టీవీ - వేగంగా, నిజాయితీగా" : "Samanyudu TV - Fast & Honest",
                            style: GoogleFonts.notoSansTelugu(
                              fontSize: 10,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.notoSans(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      
      // 5. Central Floating Logo (Bridging the Image and Text blocks)
      Positioned(
        top: currentImageHeight - 30, // 30 is exactly half the total effective height of the logo container (46 box height + padding ~ 60)
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.asset(
              'assets/app_logo_new.png',
              height: 40,
              width: 160,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  static Future<String> _getTranslatedString(String text, String targetLang) async {
    if (text.isEmpty) return "";
    
    bool isTeluguTarget = targetLang.contains('te') || targetLang.contains('తెలుగు');
    bool hasTeluguChars = RegExp(r'[\u0c00-\u0c7f]').hasMatch(text);
    bool hasEnglishChars = RegExp(r'[a-zA-Z]').hasMatch(text);
    
    if (isTeluguTarget && !hasEnglishChars) return text;
    if (!isTeluguTarget && !hasTeluguChars) return text;

    try {
      final translator = GoogleTranslator();
      final translation = await translator.translate(text, to: isTeluguTarget ? 'te' : 'en');
      return translation.text;
    } catch (e) {
      debugPrint("Translation for share failed: $e");
      return text;
    }
  }

  static String _formatMarriageDetails(Map<String, dynamic> item, bool isTelugu) {
    if (item['marriage_details'] == null) return "";
    
    final d = Map<String, dynamic>.from(item['marriage_details']);
    final sb = StringBuffer();
    
    void addField(String enLabel, String teLabel, dynamic value) {
      if (value != null && value.toString().isNotEmpty && value.toString() != 'null') {
        sb.writeln("${isTelugu ? teLabel : enLabel}: ${value.toString()}");
      }
    }

    sb.writeln(isTelugu ? "--- వివాహ వివరాలు ---" : "--- Matrimonial Details ---");
    
    addField("Name", "పేరు", d['full_name']);
    addField("Gender", "లింగం", d['gender']);
    
    String ageStr = (d['age'] ?? '').toString();
    String dobStr = (d['date_of_birth'] ?? '').toString();
    String ageDob = "";
    if (ageStr.isNotEmpty && ageStr != 'null') ageDob = ageStr;
    if (dobStr.isNotEmpty && dobStr != 'null') {
      ageDob += ageDob.isEmpty ? dobStr : " ($dobStr)";
    }
    
    if (ageDob.isNotEmpty) {
       addField("Age/DOB", "వయస్సు/పుట్టిన తేదీ", ageDob);
    }
    
    addField("Education", "విద్య", d['highest_education']);
    addField("College", "కళాశాల", d['college_name']);
    addField("Occupation", "ఉద్యోగం", d['occupation']);
    addField("Company", "సంస్థ", d['company_name']);
    addField("Income", "ఆదాయం", d['annual_income']);
    
    String religion = (d['religion'] ?? '').toString();
    String caste = (d['caste'] ?? '').toString();
    String subCaste = (d['sub_caste'] ?? '').toString();
    String relCaste = "";
    if (religion.isNotEmpty && religion != 'null') relCaste = religion;
    if (caste.isNotEmpty && caste != 'null') {
      relCaste += relCaste.isEmpty ? caste : " - $caste";
    }
    if (subCaste.isNotEmpty && subCaste != 'null') {
      relCaste += relCaste.isEmpty ? subCaste : " ($subCaste)";
    }
    if (relCaste.isNotEmpty) {
      addField("Religion/Caste", "మతం/కులం", relCaste);
    }

    addField("Mother Tongue", "మాతృభాష", d['mother_tongue']);
    addField("Location", "ప్రాంతం", d['location']);
    addField("Native Place", "సొంత ఊరు", d['native_place']);
    
    if (d['is_contact_visible'] == true || d['is_contact_visible'] == 'true') {
      addField("Phone", "ఫోన్", d['phone_number']);
      addField("Email", "ఈమెయిల్", d['email']);
      addField("WhatsApp", "వాట్సాప్", d['whatsapp_number']);
    }
    
    return sb.toString();
  }
}
