import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'main_navigation.dart';
import 'signup_screen.dart';
import 'location_screen.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  final String selectedLanguage;
  const LoginScreen({super.key, required this.selectedLanguage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isObscure = true;
  bool _isMobileLogin = true;
  bool _otpSent = false;
  bool _isForgotPasswordFlow = false;
  late Map<String, String> text;

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _checkExistingSession();
  }

  void _loadTranslations() {
    if (_isEnglish) {
      text = {
        "title": "Welcome Back",
        "subtitle": "Login to your account",
        "email": "Email Address",
        "password": "Password",
        "login": "Login",
        "skip": "Skip for now",
        "noAccount": "Don't have an account? Sign Up",
        "error": "Authentication failed",
        "invalidEmail": "Please enter a valid email",
        "phone": "Phone Number",
        "invalidPhone": "Please enter a valid phone number",
        "mobileOption": "Mobile",
        "emailOption": "Email",
        "forgotPassword": "Forgot Password?",
        "resendOtp": "Resend OTP",
        "forgotPassOtp": "Forgot Password? Login with OTP",
        "verifyOtp": "Verify OTP",
        "newPassword": "New Password",
        "otp": "Verification Code",
        "resetTitle": "Reset Password",
        "resetSubTitle": "An OTP will be sent to your email to reset password.",
        "cancel": "Cancel",
        "sendOtpBtn": "Send OTP",
        "resetBtn": "Reset",
        "resetSuccess": "Password reset successful!",
        "enterPhone": "Enter Phone Number",
        "enterOtp": "Enter OTP",
        "passLengthWarn": "Password must be at least 6 characters long",
      };
    } else {
      text = {
        "title": "తిరిగి స్వాగతం",
        "subtitle": "మీ ఖాతాలోకి లాగిన్ చేయండి",
        "email": "ఇమెయిల్ చిరునామా",
        "password": "పాస్‌వర్డ్",
        "login": "లాగిన్",
        "skip": "తరువాత లాగిన్ చేస్తాను",
        "noAccount": "ఖాతా లేదా? ఇక్కడ సైన్ అప్ చేయండి",
        "error": "ధృవీకరణ విఫలమైంది",
        "invalidEmail": "దయచేసి సరైన ఇమెయిల్ నమోదు చేయండి",
        "phone": "ఫోన్ నంబర్",
        "invalidPhone": "దయచేసి సరైన ఫోన్ నంబర్ నమోదు చేయండి",
        "mobileOption": "మొబైల్",
        "emailOption": "ఇమెయిల్",
        "forgotPassword": "పాస్‌వర్డ్ మర్చిపోయారా?",
        "resendOtp": "OTP మళ్ళీ పంపు",
        "forgotPassOtp": "పాస్‌వర్డ్ మర్చిపోయారా? OTP తో లాగిన్ అవ్వండి",
        "verifyOtp": "OTP ని ధృవీకరించండి",
        "newPassword": "కొత్త పాస్‌వర్డ్",
        "otp": "అంకెల సంకేతాన్ని నమోదు చేయండి",
        "resetTitle": "పాస్‌వర్డ్ రీసెట్",
        "resetSubTitle": "పాస్‌వర్డ్ రీసెట్ చేయడానికి మీ ఇమెయిల్‌కు OTP పంపబడుతుంది.",
        "cancel": "రద్దు",
        "sendOtpBtn": "OTP పంపు",
        "resetBtn": "రీసెట్",
        "resetSuccess": "పాస్‌వర్డ్ రీసెట్ విజయవంతమైంది!",
        "enterPhone": "ఫోన్ నంబర్ నమోదు చేయండి",
        "enterOtp": "OTP ని నమోదు చేయండి",
        "passLengthWarn": "పాస్‌వర్డ్ కనీసం 6 అక్షరాల పొడవు ఉండాలి",
      };
    }
  }

  String _translateError(dynamic error) {
    String errorStr = "Authentication failed. Please try again.";
    try {
      errorStr = error.toString();
    } catch (_) {}
    errorStr = errorStr.replaceAll("Exception: ", "");
    if (_isEnglish) return errorStr;
    if (errorStr.toLowerCase().contains("invalid email")) return "దయచేసి సరైన ఇమెయిల్ నమోదు చేయండి";
    if (errorStr.toLowerCase().contains("wrong password") || errorStr.toLowerCase().contains("incorrect password")) return "తప్పు పాస్‌వర్డ్";
    if (errorStr.toLowerCase().contains("no account found")) return "ఖాతా కనుగొనబడలేదు";
    if (errorStr.toLowerCase().contains("invalid or expired otp")) return "చెల్లని లేదా గడువు ముగిసిన OTP";
    return errorStr;
  }

  void _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null && userId.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainNavigation(selectedLanguage: widget.selectedLanguage)));
      }
    }
  }

  void _skip() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LocationScreen(selectedLanguage: widget.selectedLanguage)));
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? "Please fill all fields" : "దయచేసి అన్ని వివరాలను నమోదు చేయండి"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.loginWithEmail(email, password);

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', result['user']['id'].toString());
        await prefs.setString('user_name', result['user']['name'] ?? 'User');
        await prefs.setString('user_email', result['user']['email'] ?? email);
        await _syncUserData(result['user']['id'].toString());
        
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainNavigation(selectedLanguage: widget.selectedLanguage)));
        }
      } else {
        throw Exception("Login failed");
      }
    } catch (e) {
      String message = _isEnglish ? "Login failed" : "లాగిన్ విఫలమైంది";
      try {
        String eStr = e.toString();
        if (eStr.contains('user-not-found')) {
          message = _isEnglish ? "No account found for this email" : "ఈ ఇమెయిల్‌తో ఎటువంటి ఖాతా కనుగొనబడలేదు";
        } else if (eStr.contains('wrong-password') || eStr.contains('invalid-credential')) {
          message = _isEnglish ? "Incorrect password" : "తప్పు పాస్‌వర్డ్";
        } else if (eStr.contains('invalid-email')) {
          message = _isEnglish ? "Invalid email address" : "చెల్లని ఇమెయిల్ చిరునామా";
        } else {
          message = _translateError(e);
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMobilePasswordLogin() async {
     final phone = _phoneController.text.trim();
     final pass = _passwordController.text.trim();
     if (phone.isEmpty || pass.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(_isEnglish ? "Please fill all fields" : "దయచేసి అన్ని వివరాలను నమోదు చేయండి"), backgroundColor: Colors.red),
       );
       return;
     }
     // Validate phone is exactly 10 digits
     final phoneRegex = RegExp(r'^\d{10}$');
     if (!phoneRegex.hasMatch(phone)) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(_isEnglish ? "Please enter a valid 10-digit phone number" : "దయచేసి 10 అంకెల ఫోన్ నంబర్ నమోదు చేయండి"),
           backgroundColor: Colors.red,
         ),
       );
       return;
     }
     setState(() => _isLoading = true);
     try {
       final result = await ApiService.loginWithMobile(phone, pass);
       if (result['success'] == true) {
         final prefs = await SharedPreferences.getInstance();
         await prefs.setString('user_id', result['user']['id'].toString());
         await prefs.setString('user_name', result['user']['name'] ?? 'User');
         await prefs.setString('user_phone', result['user']['phone']);
         await _syncUserData(result['user']['id'].toString());
         if (mounted) {
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainNavigation(selectedLanguage: widget.selectedLanguage)));
         }
       }
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_translateError(e)), backgroundColor: Colors.red));
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  Future<void> _handleMobileSubmit({bool resend = false, bool isForgotPasswordFlow = false}) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text["invalidPhone"]!), backgroundColor: Colors.red),
      );
      return;
    }
    // Validate phone is exactly 10 digits
    final phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEnglish ? "Please enter a valid 10-digit phone number" : "దయచేసి 10 అంకెల ఫోన్ నంబర్ నమోదు చేయండి"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await ApiService.sendOtp(phone, type: isForgotPasswordFlow ? 'reset' : 'login');
      if (success) {
        setState(() { _otpSent = true; _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? "OTP Sent Successfully" : "OTP విజయవంతంగా పంపబడింది"), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_translateError(e)), backgroundColor: Colors.red));
    }
  }

  Future<void> _syncUserData(String userId) async {
    try {
       await ApiService.syncUserLikes(userId);
       await ApiService.syncSavedItems(userId);
    } catch (e) {
      try { debugPrint("Sync Error: $e"); } catch (_) {}
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    final otpController = TextEditingController();
    final newPassController = TextEditingController();
    final phoneController = TextEditingController();
    bool otpSent = false;
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : Colors.black87;
          final subTextColor = isDark ? Colors.white70 : Colors.black54;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF173B60) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(text["resetTitle"] ?? "Reset Password", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otpSent ? (_isEnglish ? "Enter the OTP sent and your new password." : "పంపిన OTP మరియు కొత్త పాస్‌వర్డ్‌ను నమోదు చేయండి.") : text["resetSubTitle"] ?? "",
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (!otpSent) ...[
                    if (!_isMobileLogin)
                      TextField(
                        controller: emailController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: text["email"],
                          prefixIcon: Icon(Icons.email, color: subTextColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    else
                      TextField(
                        controller: phoneController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: text["phone"],
                          prefixIcon: Icon(Icons.phone, color: subTextColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                  ] else ...[
                    TextField(
                      controller: otpController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: text["otp"],
                        prefixIcon: Icon(Icons.security, color: subTextColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassController,
                      style: TextStyle(color: textColor),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: text["newPassword"],
                        helperText: text["passLengthWarn"],
                        helperStyle: const TextStyle(fontSize: 11),
                        prefixIcon: Icon(Icons.lock, color: subTextColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(text["cancel"] ?? "Cancel", style: TextStyle(color: subTextColor)),
              ),
              ElevatedButton(
                onPressed: isDialogLoading ? null : () async {
                  final target = _isMobileLogin ? phoneController.text.trim() : emailController.text.trim();
                  if (target.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_isEnglish ? "Please enter details" : "దయచేసి వివరాలను నమోదు చేయండి"), backgroundColor: Colors.red)
                    );
                    return;
                  }

                  if (!otpSent) {
                    if (!_isMobileLogin) {
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(target)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(text["invalidEmail"]!), backgroundColor: Colors.red)
                        );
                        return;
                      }
                    } else {
                      final phoneRegex = RegExp(r'^\d{10}$');
                      if (!phoneRegex.hasMatch(target)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(text["invalidPhone"]!), backgroundColor: Colors.red)
                        );
                        return;
                      }
                    }
                  }

                  setDialogState(() => isDialogLoading = true);
                  try {
                  if (!otpSent) {
                    if (!_isMobileLogin) {
                      // 1. First verify if email exists in our records
                      try {
                        await ApiService.verifyEmail(target);
                      } catch (e) {
                         setDialogState(() => isDialogLoading = false);
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text(_isEnglish ? "No account found with this email address" : "ఈ ఇమెయిల్ చిరునామాతో ఎటువంటి ఖాతా కనుగొనబడలేదు"), backgroundColor: Colors.red)
                         );
                         return;
                      }

                      // 2. If exists, send Email OTP
                      final success = await ApiService.sendEmailOtp(target, type: "reset");
                      if (success) {
                        setDialogState(() { otpSent = true; isDialogLoading = false; });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_isEnglish ? "OTP sent to your email!" : "OTP మీ ఇమెయిల్‌కు పంపబడింది!"), backgroundColor: Colors.green)
                        );
                      }
                    } else {
                      final success = await ApiService.sendOtp(target, type: "reset");
                      if (success) {
                        setDialogState(() { otpSent = true; isDialogLoading = false; });
                      }
                    }
                  } else {
                    // Handle OTP submission for both mobile and email
                    final otp = otpController.text.trim();
                    final newPass = newPassController.text.trim();
                    if (otp.isEmpty || newPass.isEmpty) throw "Please fill all fields";
                    if (newPass.length < 6) throw text["passLengthWarn"]!;
                    
                    bool success = false;
                    if (!_isMobileLogin) {
                      success = await ApiService.resetPasswordEmail(email: target, otp: otp, newPassword: newPass);
                    } else {
                      success = (await ApiService.resetPasswordMobile(phone: target, otp: otp, newPassword: newPass))['success'] == true;
                    }
                    
                    if (success) {
                      if (context.mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text["resetSuccess"]!), backgroundColor: Colors.green));
                    }
                  }
                  } catch (e) {
                    setDialogState(() => isDialogLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_translateError(e)), backgroundColor: Colors.red));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107)),
                child: isDialogLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(otpSent ? text["resetBtn"]! : text["sendOtpBtn"]!, style: const TextStyle(color: Color(0xFF0B2A45))),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final fieldColor = isDark ? const Color(0xFF173B60) : Colors.grey[200];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Center(child: AppLogo(fontSize: 32)),
              const SizedBox(height: 30),
              Text(
                text["title"]!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                text["subtitle"]!,
                textAlign: TextAlign.center,
                style: TextStyle(color: subTextColor, fontSize: 16),
              ),
              const SizedBox(height: 30),
              
              _buildToggle(),
              
              const SizedBox(height: 30),

              if (!_isMobileLogin) ...[
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: text["email"],
                    labelStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: fieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.email, color: subTextColor),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ] else ...[
                 TextField(
                  controller: _phoneController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: text["phone"],
                    labelStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: fieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.phone, color: subTextColor),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: _isForgotPasswordFlow ? text["newPassword"] : text["password"],
                  labelStyle: TextStyle(color: subTextColor),
                  filled: true,
                  fillColor: fieldColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.lock, color: subTextColor),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off, color: subTextColor),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () { _showForgotPasswordDialog(); },
                  child: Text(text["forgotPassword"]!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : (_isMobileLogin ? _handleMobilePasswordLogin : _handleEmailSubmit),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFF0B2A45), strokeWidth: 2))
                    : Text(text["login"]!, style: const TextStyle(color: Color(0xFF0B2A45), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SignupScreen(selectedLanguage: widget.selectedLanguage)));
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: textColor.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(text["noAccount"]!, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF173B60) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isMobileLogin = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _isMobileLogin ? const Color(0xFFFFC107) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    text["mobileOption"]!,
                    style: TextStyle(
                      color: _isMobileLogin ? const Color(0xFF0B2A45) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isMobileLogin = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !_isMobileLogin ? const Color(0xFFFFC107) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    text["emailOption"]!,
                    style: TextStyle(
                      color: !_isMobileLogin ? const Color(0xFF0B2A45) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
