import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'location_screen.dart';
import '../widgets/app_logo.dart';

class PasswordValidationResult {
  final bool hasMinLength;
  final bool hasMaxLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;
  final bool hasNoSpaces;
  final bool isNotSameAsUserDetails;
  final bool isNotCommonPassword;
  final bool matchesConfirm;

  PasswordValidationResult({
    required this.hasMinLength,
    required this.hasMaxLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
    required this.hasNoSpaces,
    required this.isNotSameAsUserDetails,
    required this.isNotCommonPassword,
    required this.matchesConfirm,
  });

  bool get isValid =>
      hasMinLength &&
      hasMaxLength &&
      hasUppercase &&
      hasLowercase &&
      hasDigit &&
      hasSpecialChar &&
      hasNoSpaces &&
      isNotSameAsUserDetails &&
      isNotCommonPassword &&
      matchesConfirm;

  String get strength {
    int score = 0;
    if (hasMinLength) score++;
    if (hasUppercase) score++;
    if (hasLowercase) score++;
    if (hasDigit) score++;
    if (hasSpecialChar) score++;
    if (hasNoSpaces) score++;
    if (isNotSameAsUserDetails) score++;
    if (isNotCommonPassword) score++;

    if (score < 4) return "Weak";
    if (score < 7) return "Medium";
    return "Strong";
  }
}

class SignupScreen extends StatefulWidget {
  final String selectedLanguage;
  const SignupScreen({super.key, required this.selectedLanguage});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isMobileSignup = true; // true = Mobile (Default), false = Email
  
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  bool _isObscure = true;
  late Map<String, String> text;
  PasswordValidationResult? _validationResult;

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _passwordController.addListener(_validatePasswordRealtime);
    _confirmPasswordController.addListener(_validatePasswordRealtime);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordRealtime);
    _confirmPasswordController.removeListener(_validatePasswordRealtime);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _validatePasswordRealtime() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.isEmpty) {
      setState(() {
        _validationResult = null;
      });
      return;
    }

    final hasMinLength = password.length >= 8;
    final hasMaxLength = password.length <= 20;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChar = password.contains(RegExp(r'[@#\$%\^&\*!\?_\-]'));
    final hasNoSpaces = !password.contains(' ');

    // User details check
    final firstName = _firstNameController.text.trim().toLowerCase();
    final lastName = _lastNameController.text.trim().toLowerCase();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();

    final passLower = password.toLowerCase();
    bool isNotSameAsUserDetails = true;
    if (firstName.isNotEmpty && passLower == firstName) isNotSameAsUserDetails = false;
    if (lastName.isNotEmpty && passLower == lastName) isNotSameAsUserDetails = false;
    if (firstName.isNotEmpty && lastName.isNotEmpty && passLower == "$firstName $lastName") isNotSameAsUserDetails = false;
    if (email.isNotEmpty && passLower == email) isNotSameAsUserDetails = false;
    if (phone.isNotEmpty && password == phone) isNotSameAsUserDetails = false;

    // Common passwords check
    final commonPasswords = ['password', '123456', '12345678', 'qwerty', 'admin', 'samanyudu'];
    final isNotCommonPassword = !commonPasswords.contains(passLower);

    final matchesConfirm = password == confirm && confirm.isNotEmpty;

    setState(() {
      _validationResult = PasswordValidationResult(
        hasMinLength: hasMinLength,
        hasMaxLength: hasMaxLength,
        hasUppercase: hasUppercase,
        hasLowercase: hasLowercase,
        hasDigit: hasDigit,
        hasSpecialChar: hasSpecialChar,
        hasNoSpaces: hasNoSpaces,
        isNotSameAsUserDetails: isNotSameAsUserDetails,
        isNotCommonPassword: isNotCommonPassword,
        matchesConfirm: matchesConfirm,
      );
    });
  }

  Widget _buildValidationRow(String ruleText, bool isMet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isMet ? Colors.green : (isDark ? Colors.white60 : Colors.black54);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ruleText,
              style: TextStyle(
                color: color,
                fontSize: 12,
                decoration: isMet ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthIndicator() {
    if (_validationResult == null) return const SizedBox.shrink();
    
    final strength = _validationResult!.strength;
    Color color;
    double progress;
    if (strength == "Weak") {
      color = Colors.red;
      progress = 0.33;
    } else if (strength == "Medium") {
      color = Colors.orange;
      progress = 0.66;
    } else {
      color = Colors.green;
      progress = 1.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isEnglish ? "Password Strength:" : "పాస్‌వర్డ్ బలం:",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              _isEnglish ? strength : (strength == "Weak" ? "బలహీనంగా" : strength == "Medium" ? "మధ్యమంగా" : "బలంగా"),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        if (!_validationResult!.matchesConfirm && _confirmPasswordController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEnglish ? "Passwords must match" : "పాస్‌వర్డ్‌లు సరిపోలాలి",
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  void _loadTranslations() {
    if (_isEnglish) {
      text = {
        "title": "Create Account",
        "subtitle": "Sign up to get started",
        "firstName": "First Name",
        "lastName": "Last Name",
        "email": "Email Address",
        "password": "Password",
        "confirmPassword": "Confirm Password",
        "phone": "Phone Number",
        "otp": "Verification Code",
        "sendOtp": "Sign Up",
        "verifyOtp": "Verify & Continue",
        "hasAccount": "Already have an account? Login",
        "error": "Error creating account",
        "verifyError": "Invalid or expired OTP",
        "passMismatch": "Passwords do not match",
        "invalidEmail": "Please enter a valid email",
        "invalidPhone": "Please enter a valid phone number",
        "otpSuccess": "OTP sent successfully, please check",
        "mobileOption": "Mobile",
        "emailOption": "Email",
        "resendOtp": "Resend OTP",
        "resendLink": "Resend Verification Link",
        "iHaveVerified": "I HAVE VERIFIED",
        "fillAll": "Please fill all fields",
        "linkSent": "Verification link sent! Please check your inbox.",
        "notVerified": "Email not verified yet. Please click the link in your email.",
        "nameRequired": "First and Last name are required",
        "syncFailed": "Successfully verified but failed to sync with server. Please try again.",
        "checkEmail": "Check your email for a verification link.",
        "passLengthWarn": "Password must be at least 6 characters long",
      };
    } else {
      text = {
        "title": "కొత్త ఖాతా",
        "subtitle": "ప్రారంభించడానికి సైన్ అప్ చేయండి",
        "firstName": "మొదటి పేరు",
        "lastName": "చివరి పేరు",
        "email": "ఇమెయిల్ చిరునామా",
        "password": "పాస్వర్డ్",
        "confirmPassword": "పాస్వర్డ్ నిర్ధారించండి",
        "phone": "ఫోన్ నంబర్",
        "otp": "ధృవీకరణ కోడ్",
        "sendOtp": "సైన్ అప్",
        "verifyOtp": "ధృవీకరించి కొనసాగండి",
        "hasAccount": "ఇప్పటికే ఖాతా ఉందా? లాగిన్ చేయండి",
        "error": "ఖాతా సృష్టించడంలో లోపం",
        "verifyError": "చెల్లని లేదా గడువు ముగిసిన OTP",
        "passMismatch": "పాస్వర్డ్లు సరిపోలలేదు",
        "invalidEmail": "దయచేసి సరైన ఇమెయిల్ నమోదు చేయండి",
        "invalidPhone": "దయచేసి సరైన ఫోన్ నంబర్ నమోదు చేయండి",
        "otpSuccess": "OTP విజయవంతంగా పంపబడింది",
        "mobileOption": "మొబైల్",
        "emailOption": "ఇమెయిల్",
        "resendOtp": "OTP మళ్ళీ పంపు",
        "resendLink": "ధృవీకరణ లింక్‌ను మళ్ళీ పంపు",
        "iHaveVerified": "నేను ధృవీకరించాను",
        "fillAll": "అన్ని ఫీల్డ్‌లు నింపండి",
        "linkSent": "ధృవీకరణ లింక్ పంపబడింది! దయచేసి మీ ఇన్‌బాక్స్‌ను తనిఖీ చేయండి.",
        "notVerified": "ఇమెయిల్ ఇంకా ధృవీకరించబడలేదు. దయచేసి మీ ఇమెయిల్‌లోని లింక్‌ను క్లిక్ చేయండి.",
        "nameRequired": "మొదటి మరియు చివరి పేరు అవసరం",
        "syncFailed": "విజయవంతంగా ధృవీకరించబడింది కానీ సర్వర్‌తో సమకాలీకరించడంలో విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.",
        "checkEmail": "ధృవీకరణ లింక్ కోసం మీ ఇమెయిల్ తనిఖీ చేయండి.",
        "passLengthWarn": "పాస్‌వర్డ్ కనీసం 6 అక్షరాల పొడవు ఉండాలి",
      };
    }
  }

  String _translateError(String error) {
    if (_isEnglish) return error;
    if (error.contains("Incorrect password")) return "తప్పు పాస్‌వర్డ్";
    if (error.contains("No account found with this phone number") || error.contains("No user found with this email")) return "ఈ ఖాతా కనుగొనబడలేదు";
    if (error.contains("No account found for this phone")) return "ఖాతా కనుగొనబడలేదు. దయచేసి ముందుగా సైన్ అప్ చేయండి.";
    if (error.contains("Invalid or expired OTP") || error.contains("verification failed")) return "చెల్లని లేదా గడువు ముగిసిన OTP";
    if (error.contains("Phone already registered")) return "ఫోన్ నంబర్ ఇప్పటికే నమోదు చేయబడింది";
    if (error.contains("All fields are required")) return "అన్ని ఫీల్డ్‌లు తప్పనిసరి";
    if (error.contains("Invalid email or password")) return "చెల్లని ఇమెయిల్ లేదా పాస్‌వర్డ్";
    if (error.contains("Invalid password")) return "తప్పు పాస్‌వర్డ్";
    return error;
  }

  Future<void> _sendEmailVerification() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text["fillAll"]!), backgroundColor: Colors.red));
      return;
    }

    _validatePasswordRealtime();
    if (_validationResult == null || !_validationResult!.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEnglish 
              ? "Please ensure the password meets all security conditions." 
              : "దయచేసి పాస్‌వర్డ్ అన్ని భద్రతా నిబంధనలను కలిగి ఉండేలా చూసుకోండి."), 
          backgroundColor: Colors.red
        ),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text["invalidEmail"]!), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Create account in Firebase
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        // 2. Set display name
        await firebaseUser.updateDisplayName("$firstName $lastName");
        
        // 3. Send verification email
        await firebaseUser.sendEmailVerification();

        if (mounted) {
          setState(() => _otpSent = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(text["linkSent"]!), 
                backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = _isEnglish ? "Signup failed" : "సైన్ అప్ విఫలమైంది";
      if (e.code == 'email-already-in-use') {
        message = _isEnglish ? "This email is already in use" : "ఈ ఇమెయిల్ ఇప్పటికే వాడుకలో ఉంది";
      } else if (e.code == 'invalid-email') {
        message = _isEnglish ? "Invalid email address" : "చెల్లని ఇమెయిల్ చిరునామా";
      } else if (e.code == 'weak-password') {
        message = _isEnglish ? "The password provided is too weak" : "పాస్‌వర్డ్ చాలా బలహీనంగా ఉంది";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translateError(e.toString().replaceAll("Exception: ", ""))), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignup() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _isLoading = true);
    try {
      // 1. Refresh user state from Firebase
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw "Authentication session lost. Please try signing up again.";
      }
      
      await firebaseUser.reload();
      if (!firebaseUser.emailVerified) {
        throw text["notVerified"]!;
      }

      // 2. Sync with local backend
      final result = await ApiService.registerWithFirebase(
        uid: firebaseUser.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
      );

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', result['user']['id'].toString());
        await prefs.setString('user_name', result['user']['name']);
        await prefs.setString('user_email', result['user']['email']);

        await ApiService.syncUserLikes(result['user']['id'].toString());
        await ApiService.syncSavedItems(result['user']['id'].toString());

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LocationScreen(selectedLanguage: widget.selectedLanguage),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      String errorMsg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translateError(errorMsg.replaceAll("Exception: ", ""))), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _verificationId;

  Future<void> _sendMobileOtp() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phoneInput = _phoneController.text.trim();
    final passwordInput = _passwordController.text.trim();
    final confirmInput = _confirmPasswordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || phoneInput.isEmpty || passwordInput.isEmpty || confirmInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text["fillAll"]!), backgroundColor: Colors.red),
      );
      return;
    }

    _validatePasswordRealtime();
    if (_validationResult == null || !_validationResult!.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEnglish 
              ? "Please ensure the password meets all security conditions." 
              : "దయచేసి పాస్‌వర్డ్ అన్ని భద్రతా నిబంధనలను కలిగి ఉండేలా చూసుకోండి."), 
          backgroundColor: Colors.red
        ),
      );
      return;
    }

    final phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(phoneInput)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text["invalidPhone"]!), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await ApiService.sendOtp(phoneInput, type: 'signup');
      if (success) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text["otpSuccess"]!), backgroundColor: Colors.green),
        );
      } else {
        throw "Failed to send OTP. Please try again later.";
      }
    } catch (e) {
      setState(() => _isLoading = false);
      String errorMsg = e.toString();
      if (errorMsg.contains("FirebaseException")) {
        errorMsg = "Authentication error occurred. Please try again.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translateError(errorMsg.replaceAll("Exception: ", ""))), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleMobileSignup() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    final password = _passwordController.text.trim();

    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? "Please enter the OTP" : "దయచేసి OTP నమోదు చేయండి"), backgroundColor: Colors.red));
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEnglish ? "Please enter a password" : "దయచేసి మీ పాస్‌వర్డ్ నమోదు చేయండి"), backgroundColor: Colors.red));
      return;
    }
    if (!_isMobileSignup) return; // Should not happen

    setState(() => _isLoading = true);
    try {
      // 1. Register with our backend directly using the OTP
      final result = await ApiService.registerWithMobile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        otp: otp,
        password: password, // Note: mobile flow might need password if intended
      );

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', result['user']['id'].toString());
        await prefs.setString('user_name', result['user']['name']);
        await prefs.setString('user_phone', result['user']['phone']);

        await ApiService.syncUserLikes(result['user']['id'].toString());
        await ApiService.syncSavedItems(result['user']['id'].toString());

        if (mounted) {
           Navigator.pushAndRemoveUntil(
             context,
             MaterialPageRoute(
               builder: (_) => LocationScreen(selectedLanguage: widget.selectedLanguage),
             ),
             (route) => false,
           );
        }
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains("FirebaseException")) {
        errorMsg = "Authentication error occurred. Please try again.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translateError(errorMsg.replaceAll("Exception: ", ""))), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFirebasePhoneSuccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = user.phoneNumber ?? _phoneController.text.trim();

    try {
      final result = await ApiService.registerWithFirebasePhone(
        uid: user.uid,
        phone: phone,
        firstName: firstName,
        lastName: lastName,
      );

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', result['user']['id'].toString());
        await prefs.setString('user_name', result['user']['name']);
        await prefs.setString('user_phone', result['user']['phone']);

        await ApiService.syncUserLikes(result['user']['id'].toString());
        await ApiService.syncSavedItems(result['user']['id'].toString());

        if (mounted) {
           Navigator.pushAndRemoveUntil(
             context,
             MaterialPageRoute(
               builder: (_) => LocationScreen(selectedLanguage: widget.selectedLanguage),
             ),
             (route) => false,
           );
        }
      }
    } catch (e) {
      debugPrint("API Sync Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text["syncFailed"]!)),
      );
    }
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
              onTap: () {
                setState(() {
                  _isMobileSignup = true;
                  _otpSent = false;
                  _verificationId = null; // Reset verification
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _isMobileSignup ? const Color(0xFFFFC107) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  text["mobileOption"]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isMobileSignup ? const Color(0xFF0B2A45) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isMobileSignup = false;
                  _otpSent = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !_isMobileSignup ? const Color(0xFFFFC107) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  text["emailOption"]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isMobileSignup ? const Color(0xFF0B2A45) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(fontSize: 32)),
              const SizedBox(height: 30),
              Text(
                text["title"]!,
                style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                text["subtitle"]!,
                style: TextStyle(color: subTextColor, fontSize: 16),
              ),
              const SizedBox(height: 30),
              
              _buildToggle(),
              
              const SizedBox(height: 30),

              // Name Row (Always visible)
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _firstNameController,
                      label: text["firstName"]!,
                      icon: Icons.person,
                      enabled: !_otpSent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      controller: _lastNameController,
                      label: text["lastName"]!,
                      enabled: !_otpSent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (!_isMobileSignup) ...[
                // EMAIL FLOW
                _buildField(
                  controller: _emailController,
                  label: text["email"]!,
                  icon: Icons.email,
                  enabled: !_otpSent,
                  keyboardType: TextInputType.emailAddress,
                ),
              ] else ...[
                // MOBILE FLOW
                _buildField(
                  controller: _phoneController,
                  label: text["phone"]!,
                  icon: Icons.phone,
                  enabled: !_otpSent,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              _buildField(
                controller: _passwordController,
                label: text["password"]!,
                icon: Icons.lock,
                isPassword: true,
                enabled: !_otpSent,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  text["passLengthWarn"]!,
                  style: TextStyle(color: subTextColor, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _confirmPasswordController,
                label: text["confirmPassword"]!,
                icon: Icons.lock_clock,
                isPassword: true,
                enabled: !_otpSent,
              ),
              _buildStrengthIndicator(),
              const SizedBox(height: 16),
              
              const SizedBox(height: 16),

              if (_otpSent) ...[
                if (_isMobileSignup) ...[
                  _buildField(
                    controller: _otpController,
                    label: text["otp"]!,
                    icon: Icons.security,
                    keyboardType: TextInputType.number,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mark_email_unread, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text["checkEmail"]!,
                            style: TextStyle(color: textColor, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : (_isMobileSignup ? _handleMobileSignup : _handleEmailSignup),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFF0B2A45), strokeWidth: 2))
                      : Text(_isMobileSignup ? text["verifyOtp"]! : text["iHaveVerified"]!, 
                          style: const TextStyle(color: Color(0xFF0B2A45), fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isLoading ? null : (_isMobileSignup ? _sendMobileOtp : _sendEmailVerification),
                  child: Text(
                    _isMobileSignup ? text["resendOtp"]! : (_isEnglish ? "Resend OTP" : "OTPని మళ్ళీ పంపండి"),
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : (_isMobileSignup ? _sendMobileOtp : _sendEmailVerification),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFF0B2A45), strokeWidth: 2))
                      : Text(text["sendOtp"]!, style: const TextStyle(color: Color(0xFF0B2A45), fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],

              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: textColor.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(text["hasAccount"]!, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool enabled = true,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: isPassword && _isObscure,
      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters ?? (keyboardType == TextInputType.phone || label.toLowerCase().contains('phone') || label.contains('ఫోన్')
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF173B60) : Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: icon != null ? Icon(icon, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54) : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            : null,
      ),
    );
  }
}
