import 'package:flutter/material.dart';

/// Edit profile screen – same theme and colors as the app.
class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String selectedLanguage;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.selectedLanguage,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  // static const bgColor = Color(0xFF041627);
  // static const cardColor = Color(0xFF132F4C);
  // static final accentYellow = isDark ? const Color(0xFFFFC107) : Colors.black;

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  late String _title;
  late String _nameHint;
  late String _phoneHint;
  late String _save;
  late String _cancel;
  late String _savedMsg;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _setStrings();
  }

  void _setStrings() {
    if (_isEnglish) {
      _title = "Edit Profile";
      _nameHint = "Your name";
      _phoneHint = "Phone number";
      _save = "Save";
      _cancel = "Cancel";
      _savedMsg = "Profile updated";
    } else {
      _title = "ప్రొఫైల్ ఎడిట్";
      _nameHint = "మీ పేరు";
      _phoneHint = "ఫోన్ నంబర్";
      _save = "సేవ్";
      _cancel = "రద్దు";
      _savedMsg = "ప్రొఫైల్ నవీకరించబడింది";
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSave() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_savedMsg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, {"name": name, "phone": phone});
  }

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.15);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white70 : Colors.black54;
    final accentYellow = const Color(0xFFFFC107);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: TextStyle(
            color: textColor,
            fontSize: 18 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: _nameHint,
                  labelStyle: TextStyle(color: hintColor, fontSize: 14 * scale),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: isDark ? BorderSide.none : const BorderSide(color: Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentYellow, width: 1.5),
                  ),
                ),
              ),
              SizedBox(height: 16 * scale),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: _phoneHint,
                  labelStyle: TextStyle(color: hintColor, fontSize: 14 * scale),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: isDark ? BorderSide.none : const BorderSide(color: Colors.black12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentYellow, width: 1.5),
                  ),
                ),
              ),
              SizedBox(height: 32 * scale),
              ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentYellow,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _save,
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 12 * scale),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  _cancel,
                  style: TextStyle(color: hintColor, fontSize: 14 * scale),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
