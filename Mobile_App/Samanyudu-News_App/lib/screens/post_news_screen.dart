import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

class PostNewsScreen extends StatefulWidget {
  final String selectedLanguage;
  const PostNewsScreen({super.key, required this.selectedLanguage});

  @override
  State<PostNewsScreen> createState() => _PostNewsScreenState();
}

class _PostNewsScreenState extends State<PostNewsScreen> {
  late Map<String, String> text;
  // bool useCurrentLocation = false;
  String? selectedCategory;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  int charCount = 0;

  // Matrimonial Controllers
  final TextEditingController _mFullNameController = TextEditingController();
  final TextEditingController _mDobController = TextEditingController();
  final TextEditingController _mAgeController = TextEditingController();
  final TextEditingController _mNativePlaceController = TextEditingController();
  final TextEditingController _mReligionController = TextEditingController();
  final TextEditingController _mCasteController = TextEditingController();
  final TextEditingController _mSubCasteController = TextEditingController();
  final TextEditingController _mMotherTongueController = TextEditingController();
  final TextEditingController _mEducationController = TextEditingController();
  final TextEditingController _mCollegeController = TextEditingController();
  final TextEditingController _mOccupationController = TextEditingController();
  final TextEditingController _mCompanyController = TextEditingController();
  final TextEditingController _mIncomeController = TextEditingController();
  final TextEditingController _mFatherNameController = TextEditingController();
  final TextEditingController _mFatherOccController = TextEditingController();
  final TextEditingController _mMotherNameController = TextEditingController();
  final TextEditingController _mMotherOccController = TextEditingController();
  final TextEditingController _mSiblingsController = TextEditingController();
  final TextEditingController _mPhoneController = TextEditingController();
  final TextEditingController _mEmailController = TextEditingController();
  final TextEditingController _mWhatsappController = TextEditingController();

  String _mGender = 'Male';
  bool _mContactVisible = false;
  bool _isSubmitting = false;
  XFile? _imageFile;
  XFile? _videoFile;
  String _displayName = "Mobile User";

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final ImageSource? source = await _showSourcePicker(isVideo: false);
    if (source == null) return;

    if (kIsWeb) {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) setState(() => _imageFile = image);
      return;
    }

    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      if (Theme.of(context).platform == TargetPlatform.android) {
        // Android 13+ check
        status = await Permission.photos.request();
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }
    }

    if (status.isGranted || status.isLimited) {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() => _imageFile = image);
      }
    } else {
      _showPermissionDeniedDialog(source == ImageSource.camera ? "Camera" : "Photos");
    }
  }

  Future<void> _pickVideo() async {
    final ImageSource? source = await _showSourcePicker(isVideo: true);
    if (source == null) return;

    if (kIsWeb) {
      final XFile? video = await _picker.pickVideo(source: source);
      if (video != null) setState(() => _videoFile = video);
      return;
    }

    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      if (Theme.of(context).platform == TargetPlatform.android) {
        status = await Permission.videos.request();
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }
    }

    if (status.isGranted || status.isLimited) {
      final XFile? video = await _picker.pickVideo(source: source);
      if (video != null) {
        setState(() => _videoFile = video);
      }
    } else {
      _showPermissionDeniedDialog(source == ImageSource.camera ? "Camera" : "Videos");
    }
  }

  Future<ImageSource?> _showSourcePicker({required bool isVideo}) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFFC107)),
              title: Text(
                isVideo ? 'Take Video' : 'Take Photo',
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFFFC107)),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }


  void _showPermissionDeniedDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Permission Denied"),
        content: Text("Please enable $type access in settings to upload media."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  /// Map mobile app category labels to admin dashboard DB type values
  static String _categoryToDbType(String? displayCategory) {
    if (displayCategory == null) return 'Others';
    final c = displayCategory.toLowerCase();
    
    // Explicit mappings for all app categories
    if (c.contains('andhra') || c.contains('ఆంధ్ర')) return 'AndhraPradesh';
    if (c.contains('telangana') || c.contains('తెలంగాణ')) return 'Telangana';
    if (c.contains('national') || c.contains('జాతీ')) return 'National';
    if (c.contains('internat') || c.contains('అంతర్జాతీ')) return 'International';
    if (c.contains('crime') || c.contains('క్రైం')) return 'Crime';
    if (c.contains('education') || c.contains('విద్య')) return 'Education';
    if (c.contains('job') || c.contains('ఉద్యోగ')) return 'Jobs';
    if (c.contains('business') || c.contains('వ్యాపారం')) return 'Business';
    if (c.contains('sports') || c.contains('క్రీడలు')) return 'Sports';
    if (c.contains('agri') || c.contains('వ్యవసాయం')) return 'Agriculture';
    if (c.contains('marriage') || c.contains('పెళ్ళి') || c.contains('పందిరి') || c.contains('వివాహ') || c.contains('వేడుక')) return 'Marriage';
    if (c.contains('real estate') || c.contains('రియల్ ఎస్టేట్')) return 'RealEstate';
    if (c.contains('bhakthi') || c.contains('భక్తి')) return 'Bhakthi';
    if (c.contains('health') || c.contains('ఆరోగ్యం')) return 'Health';
    
    return 'Others';
  }

  @override
  void initState() {
    super.initState();
    _loadLanguageText();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    final savedName = prefs.getString('user_name');
    if (savedName != null && savedName.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _displayName = savedName;
        });
      }
    }
  }

  void _loadLanguageText() {
    final lang = widget.selectedLanguage.toLowerCase();

    if (lang.contains("english")) {
      text = {
        "title": "Post Article",
        "subtitle": "Share what’s happening around you",
        "headlineHint": "Enter a catchy headline...",
        "descHint": "Write about the event or topic...",
        "chars": "characters",
        "media": "Photo / Video",
        "photo": "Upload Photo",
        "video": "Upload Video",
        "location": "Location",
        "locationHint": "Enter the place of event",
        "useMyLocation": "Use my current location",
        "category": "Category",
        "categoryHint": "Select Category",
        "submit": "Submit",
        "success": "News submitted successfully!",
        "error": "Please fill all required fields before submitting.",
        "guidelinesTitle": "Guidelines:",
        "guideline1":
        "Submit only verified and truthful information. Fake news may be removed.",
        "guideline2":
        "Ensure attached photos/videos follow community standards.",
      };
    } else {
      text = {
        "title": "పోస్ట్ ఆర్టికల్",
        "subtitle": "మీ చుట్టూ జరుగుతున్న సంఘటనలను పంచుకోండి",
        "headlineHint": "వార్త శీర్షికను ఇక్కడ రాయండి...",
        "descHint": "సంఘటనను లేదా ముఖ్య విషయాలను ఇక్కడ రాయండి...",
        "chars": "అక్షరాలు",
        "media": "ఫోటోలు / వీడియో",
        "photo": "ఫోటో అప్‌లోడ్",
        "video": "వీడియో అప్‌లోడ్",
        "location": "స్థానం",
        "locationHint": "సంఘటన జరిగిన స్థానం",
        "useMyLocation": "నా ప్రదేశం నుండి ఉపయోగించండి",
        "category": "వర్గం",
        "categoryHint": "వర్గాన్ని ఎంచుకోండి",
        "submit": "సమర్పించండి",
        "success": "వార్త విజయవంతంగా సమర్పించబడింది!",
        "error": "దయచేసి సమర్పించే ముందు అన్ని వివరాలు పూరించండి.",
        "guidelinesTitle": "మార్గదర్శకాలు:",
        "guideline1":
        "నిజమైన మరియు ధృవీకరించిన సమాచారాన్ని మాత్రమే పంపండి. తప్పుడు వార్తలు తొలగించబడవచ్చు.",
        "guideline2":
        "జత చేసిన ఫోటోలు/వీడియోలు సమాజ నిబంధనలను అనుసరించాలి.",
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic theme colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final accent = isDark ? const Color(0xFFFFC107) : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final iconColor = isDark ? Colors.white70 : Colors.black54;

    final size = MediaQuery.of(context).size;
    final double scale = (size.width / 390).clamp(0.85, 1.1);
    final isEnglish = widget.selectedLanguage.toLowerCase().contains("english");

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          text["title"]!,
          style: TextStyle(
            color: textColor,
            fontSize: 18 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              text["subtitle"]!,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Headline
              TextField(
                controller: _titleController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: text["headlineHint"],
                  hintStyle: TextStyle(color: hintColor),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              TextField(
                controller: _descController,
                onChanged: (val) => setState(() => charCount = val.length),
                maxLines: 5,
                maxLength: 5000,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: text["descHint"],
                  hintStyle: TextStyle(color: hintColor),
                  filled: true,
                  fillColor: cardColor,
                  counterText: "$charCount / 5000 ${text["chars"]}",
                  counterStyle:
                  TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Media upload
              Text(
                text["media"]!,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMediaCard(
                      Icons.camera_alt, 
                      text["photo"]!, 
                      _pickImage, 
                      _imageFile != null
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMediaCard(
                      Icons.videocam, 
                      text["video"]!, 
                      _pickVideo, 
                      _videoFile != null
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Location
              // Location
              TextField(
                controller: _locationController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: text["locationHint"],
                  hintStyle: TextStyle(color: hintColor),
                  prefixIcon:
                  Icon(Icons.location_on, color: iconColor),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Category
              Text(
                text["category"]!,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
              ),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                style: TextStyle(color: textColor),
                dropdownColor: cardColor,
                decoration: InputDecoration(
                  hintText: text["categoryHint"],
                  hintStyle: TextStyle(color: hintColor),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.black12),
                  ),
                ),
                items: [
                  {'en': 'Andhra Pradesh', 'te': 'ఆంధ్రప్రదేశ్'},
                  {'en': 'Telangana', 'te': 'తెలంగాణ'},
                  {'en': 'National', 'te': 'జాతీయం'},
                  {'en': 'International', 'te': 'అంతర్జాతీయ'},
                  {'en': 'Crime Report', 'te': 'క్రైం రిపోర్ట్'},
                  {'en': 'Education', 'te': 'విద్య'},
                  {'en': 'Jobs', 'te': 'ఉద్యోగం'},
                  {'en': 'Business', 'te': 'వ్యాపారం'},
                  {'en': 'Sports', 'te': 'క్రీడలు'},
                  {'en': 'Agriculture', 'te': 'వ్యవసాయం'},
                  {'en': 'Vivaha Veduka', 'te': 'వివాహ వేడుక'},
                  {'en': 'Real Estate', 'te': 'రియల్ ఎస్టేట్'},
                  {'en': 'Bhakthi', 'te': 'భక్తి'},
                  {'en': 'Health', 'te': 'ఆరోగ్యం'},
                  {'en': 'Others', 'te': 'ఇతరం'},
                ].map((cat) {
                  return DropdownMenuItem<String>(
                    value: isEnglish ? cat['en'] : cat['te'],
                    child: Text(isEnglish ? cat['en']! : cat['te']!),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => selectedCategory = val);
                },
              ),
              const SizedBox(height: 20),

              if (_categoryToDbType(selectedCategory) == 'Marriage') ...[
                _buildMatrimonialForm(scale, textColor, cardColor, hintColor, isDark),
                const SizedBox(height: 20),
              ],

              // Guidelines
              Container(
                padding: EdgeInsets.all(14 * scale),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF102F50) : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text["guidelinesTitle"]!,
                      style: const TextStyle(
                        color: const Color(0xFFFFC107),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("• ${text["guideline1"]!}",
                        style:
                        TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text("• ${text["guideline2"]!}",
                        style:
                        TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _validateAndSubmit,
                icon: _isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Icon(Icons.send, color: Colors.black),
                label: Text(
                  _isSubmitting
                      ? (widget.selectedLanguage.toLowerCase().contains("english") ? "Submitting..." : "సమర్పిస్తోంది...")
                      : text["submit"]!,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 45 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCard(IconData icon, String label, VoidCallback onTap, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFC107).withOpacity(0.2) : cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? const Color(0xFFFFC107) 
              : (isDark ? Colors.transparent : Colors.black12)
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? Icons.check_circle : icon, 
                color: isSelected ? const Color(0xFFFFC107) : (isDark ? Colors.white70 : Colors.black54), 
                size: 24
              ),
              const SizedBox(height: 6),
              Text(
                isSelected ? "Selected" : label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFFC107) : (isDark ? Colors.white54 : Colors.black54), 
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String label) {
    final isSelected = selectedCategory == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
        isSelected ? const Color(0xFFFFC107) : (isDark ? const Color(0xFF173B60) : Colors.white),
        foregroundColor: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black),
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade400),
        ),
      ),
      onPressed: () => setState(() => selectedCategory = label),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 🔹 Validate and submit — saves to Supabase with status 'pending' for admin approval
  Future<void> _validateAndSubmit() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final location = _locationController.text.trim();

    if (title.isEmpty || desc.isEmpty || location.isEmpty || selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text["error"]!),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? imageUrl;
      String? videoUrl;

      // Upload Image
      if (_imageFile != null) {
        final size = await _imageFile!.length();
        if (size > 300 * 1024 * 1024) throw "Image must be less than 300MB"; 

        final bytes = await _imageFile!.readAsBytes();
        final ext = _imageFile!.name.split('.').last;
        final safeName = '${DateTime.now().millisecondsSinceEpoch}_image.$ext';
        
        imageUrl = await ApiService.uploadMedia(bytes, safeName);
      }

      // Upload Video
      if (_videoFile != null) {
        final size = await _videoFile!.length();
        if (size > 300 * 1024 * 1024) throw "Video must be less than 300MB";

        final bytes = await _videoFile!.readAsBytes();
        final ext = _videoFile!.name.split('.').last;
        final safeName = '${DateTime.now().millisecondsSinceEpoch}_video.$ext';
        
        videoUrl = await ApiService.uploadMedia(bytes, safeName);
      }

      final dbType = _categoryToDbType(selectedCategory);
      
      Map<String, dynamic>? marriageDetails;
      if (dbType == 'Marriage') {
        marriageDetails = {
          'full_name': _mFullNameController.text.trim(),
          'gender': _mGender,
          'date_of_birth': _mDobController.text.trim(),
          'age': int.tryParse(_mAgeController.text.trim()),
          'profile_photo': imageUrl, // Use the uploaded image as profile photo
          'location': _locationController.text.trim(),
          'native_place': _mNativePlaceController.text.trim(),
          'religion': _mReligionController.text.trim(),
          'caste': _mCasteController.text.trim(),
          'sub_caste': _mSubCasteController.text.trim(),
          'mother_tongue': _mMotherTongueController.text.trim(),
          'highest_education': _mEducationController.text.trim(),
          'college_name': _mCollegeController.text.trim(),
          'occupation': _mOccupationController.text.trim(),
          'company_name': _mCompanyController.text.trim(),
          'annual_income': _mIncomeController.text.trim(),
          'father_name': _mFatherNameController.text.trim(),
          'father_occupation': _mFatherOccController.text.trim(),
          'mother_name': _mMotherNameController.text.trim(),
          'mother_occupation': _mMotherOccController.text.trim(),
          'siblings': _mSiblingsController.text.trim(),
          'phone_number': _mPhoneController.text.trim(),
          'email': _mEmailController.text.trim(),
          'whatsapp_number': _mWhatsappController.text.trim(),
          'is_contact_visible': _mContactVisible,
        };
      }

      await ApiService.createPendingNews({
        'title': title,
        'description': desc,
        'area': location,
        'type': dbType,
        'is_breaking': false,
        'author': _displayName,
        'status': 'pending',
        'image_url': imageUrl,
        'video_url': videoUrl,
        if (marriageDetails != null) 'marriage_details': marriageDetails,
      });

      if (!mounted) return;
      final isEnglish = widget.selectedLanguage.toLowerCase().contains("english");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEnglish
                ? "News submitted! It will appear in User Approvals on the admin dashboard."
                : "వార్త సమర్పించబడింది! ఇది అడ్మిన్ డాష్‌బోర్డ్‌లో యూజర్ అప్రూవల్స్‌లో కనిపిస్తుంది.",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // Reset form
      _titleController.clear();
      _descController.clear();
      _locationController.clear();
      setState(() {
        selectedCategory = null;
        charCount = 0;
        // useCurrentLocation = false;
        _isSubmitting = false;
        _imageFile = null;
        _videoFile = null;
        
        // Reset matrimonial fields
        _mFullNameController.clear();
        _mDobController.clear();
        _mAgeController.clear();
        _mNativePlaceController.clear();
        _mReligionController.clear();
        _mCasteController.clear();
        _mSubCasteController.clear();
        _mMotherTongueController.clear();
        _mEducationController.clear();
        _mCollegeController.clear();
        _mOccupationController.clear();
        _mCompanyController.clear();
        _mIncomeController.clear();
        _mFatherNameController.clear();
        _mFatherOccController.clear();
        _mMotherNameController.clear();
        _mMotherOccController.clear();
        _mSiblingsController.clear();
        _mPhoneController.clear();
        _mEmailController.clear();
        _mWhatsappController.clear();
        _mGender = 'Male';
        _mContactVisible = false;
      });
    } catch (e) {
      debugPrint("Error submitting news: $e");
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildMatrimonialForm(double scale, Color textColor, Color cardColor, Color hintColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("👤 Basic Details", scale, textColor),
        _buildField(_mFullNameController, "Full Name", Icons.person, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                "Gender",
                ['Male', 'Female', 'Other'],
                _mGender,
                (val) => setState(() => _mGender = val!),
                cardColor, textColor, isDark
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField(_mDobController, "DOB (DD/MM/YYYY)", Icons.calendar_today, hintColor, cardColor, textColor, isDark),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildField(_mAgeController, "Age", Icons.numbers, hintColor, cardColor, textColor, isDark, keyboardType: TextInputType.number),
        
        const SizedBox(height: 20),
        _buildSectionTitle("📍 Personal Info", scale, textColor),
        _buildField(_mNativePlaceController, "Native Place", Icons.home, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        _buildField(_mReligionController, "Religion", Icons.church, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildField(_mCasteController, "Caste", Icons.people, hintColor, cardColor, textColor, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildField(_mSubCasteController, "Sub-Caste", Icons.people_outline, hintColor, cardColor, textColor, isDark)),
          ],
        ),
        const SizedBox(height: 10),
        _buildField(_mMotherTongueController, "Mother Tongue", Icons.language, hintColor, cardColor, textColor, isDark),

        const SizedBox(height: 20),
        _buildSectionTitle("🎓 Education & Career", scale, textColor),
        _buildField(_mEducationController, "Highest Education", Icons.school, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        _buildField(_mCollegeController, "College/University", Icons.apartment, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        _buildField(_mOccupationController, "Occupation", Icons.work, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        _buildField(_mCompanyController, "Company Name", Icons.business, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        _buildField(_mIncomeController, "Annual Income", Icons.currency_rupee, hintColor, cardColor, textColor, isDark),

        const SizedBox(height: 20),
        _buildSectionTitle("👨‍👩‍👧 Family Details", scale, textColor),
        _buildField(_mFatherNameController, "Father's Name", Icons.person, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        _buildField(_mFatherOccController, "Father's Occupation", Icons.work_outline, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        _buildField(_mMotherNameController, "Mother's Name", Icons.person_outline, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        _buildField(_mMotherOccController, "Mother's Occupation", Icons.work_outline, hintColor, cardColor, textColor, isDark),
        const SizedBox(height: 10),
        _buildField(_mSiblingsController, "Siblings (e.g., 1 Brother, 2 Sisters)", Icons.family_restroom, hintColor, cardColor, textColor, isDark),

        const SizedBox(height: 20),
        _buildSectionTitle("📞 Contact Details", scale, textColor),
        _buildField(_mPhoneController, "Phone Number", Icons.phone, hintColor, cardColor, textColor, isDark, keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        _buildField(_mEmailController, "Email", Icons.email, hintColor, cardColor, textColor, isDark, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _buildField(_mWhatsappController, "WhatsApp Number", Icons.chat, hintColor, cardColor, textColor, isDark, keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        SwitchListTile(
          title: Text("Show Contact to Public?", style: TextStyle(color: textColor, fontSize: 14)),
          value: _mContactVisible,
          onChanged: (val) => setState(() => _mContactVisible = val),
          activeColor: const Color(0xFFFFC107),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, double scale, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(color: textColor, fontSize: 16 * scale, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, Color hintColor, Color cardColor, Color textColor, bool isDark, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor, fontSize: 14),
        prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54, size: 20),
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.black12),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String hint, List<String> items, String value, Function(String?) onChanged, Color cardColor, Color textColor, bool isDark) {
    return DropdownButtonFormField<String>(
      value: value,
      style: TextStyle(color: textColor),
      dropdownColor: cardColor,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.black12),
        ),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}
