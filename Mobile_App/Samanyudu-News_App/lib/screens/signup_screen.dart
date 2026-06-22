import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'location_screen.dart';
import '../widgets/app_logo.dart';



enum _PasswordFieldType { password, confirm }

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
  bool _isObscurePassword = true;
  bool _isObscureConfirm = true;
  late Map<String, String> text;

  // Per-field error tracking for highlighting missing fields
  bool _firstNameError = false;
  bool _lastNameError = false;
  bool _phoneError = false;
  bool _emailError = false;
  bool _passwordError = false;
  bool _confirmPasswordError = false;

  bool get _isEnglish =>
      widget.selectedLanguage.toLowerCase().contains("english") ||
      widget.selectedLanguage.contains("ఇంగ్లీష్");

  void _onPasswordChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_onPasswordChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
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

    // Per-field validation with error highlighting
    setState(() {
      _firstNameError = firstName.isEmpty;
      _lastNameError = lastName.isEmpty;
      _emailError = email.isEmpty;
      _passwordError = password.isEmpty;
      _confirmPasswordError = confirm.isEmpty;
    });

    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text["nameRequired"]!), backgroundColor: Colors.red));
      return;
    }

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text["fillAll"]!), backgroundColor: Colors.red));
      return;
    }

    if (password != confirm) {
      setState(() => _confirmPasswordError = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text["passMismatch"]!), backgroundColor: Colors.red));
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text["passLengthWarn"]!), backgroundColor: Colors.red),
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
      final success = await ApiService.sendEmailOtp(email, type: 'signup');
      if (success) {
        if (mounted) {
          setState(() {
            _otpSent = true;
            _isLoading = false;
            // Clear all field errors on success
            _firstNameError = false;
            _lastNameError = false;
            _emailError = false;
            _passwordError = false;
            _confirmPasswordError = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEnglish ? "OTP sent to your email" : "మీ ఇమెయిల్‌కి OTP పంపబడింది"), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception("Failed to send OTP. Please try again later.");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      String errorMsg = _isEnglish ? "Signup failed. Please try again." : "సైన్ అప్ విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.";
      try {
        errorMsg = _translateError(e.toString().replaceAll("Exception: ", ""));
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleEmailSignup() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
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

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.registerWithEmail(
        firstName: firstName,
        lastName: lastName,
        email: email,
        otp: otp,
        password: password,
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
      String errorMsg = _isEnglish ? "Signup failed. Please try again." : "సైన్ అప్ విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.";
      try {
        errorMsg = _translateError(e.toString().replaceAll("Exception: ", ""));
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
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

    // Per-field validation with error highlighting
    bool hasErrors = false;
    setState(() {
      _firstNameError = firstName.isEmpty;
      _lastNameError = lastName.isEmpty;
      _phoneError = phoneInput.isEmpty;
      _passwordError = passwordInput.isEmpty;
      _confirmPasswordError = confirmInput.isEmpty;
    });

    if (firstName.isEmpty || lastName.isEmpty) {
      hasErrors = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text["nameRequired"]!), backgroundColor: Colors.red),
      );
    }

    // Validate phone is exactly 10 digits
    final phoneRegex = RegExp(r'^\d{10}$');
    if (phoneInput.isEmpty || !phoneRegex.hasMatch(phoneInput)) {
      setState(() => _phoneError = true);
      if (!hasErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEnglish
                ? "Please enter a valid 10-digit phone number"
                : "దయచేసి 10 అంకెల ఫోన్ నంబర్ నమోదు చేయండి"),
            backgroundColor: Colors.red,
          ),
        );
      }
      hasErrors = true;
    }

    if (passwordInput.isEmpty) {
      hasErrors = true;
    }

    // Confirm password must be filled and match
    if (confirmInput.isEmpty) {
      setState(() => _confirmPasswordError = true);
      if (!hasErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEnglish
                ? "Please enter the confirm password"
                : "దయచేసి నిర్ధారణ పాస్‌వర్డ్ నమోదు చేయండి"),
            backgroundColor: Colors.red,
          ),
        );
      }
      hasErrors = true;
    } else if (passwordInput != confirmInput) {
      setState(() => _confirmPasswordError = true);
      if (!hasErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text["passMismatch"]!), backgroundColor: Colors.red),
        );
      }
      hasErrors = true;
    }

    if (hasErrors) return;

    if (passwordInput.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text["passLengthWarn"]!), backgroundColor: Colors.red),
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
          // Clear all field errors on success
          _firstNameError = false;
          _lastNameError = false;
          _phoneError = false;
          _passwordError = false;
          _confirmPasswordError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text["otpSuccess"]!), backgroundColor: Colors.green),
        );
      } else {
        throw "Failed to send OTP. Please try again later.";
      }
    } catch (e) {
      setState(() => _isLoading = false);
      String errorMsg = "Authentication error occurred. Please try again.";
      try {
        errorMsg = e.toString();
        if (errorMsg.contains("FirebaseException")) {
          errorMsg = "Authentication error occurred. Please try again.";
        }
        errorMsg = _translateError(errorMsg.replaceAll("Exception: ", ""));
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
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
      String errorMsg = "Authentication error occurred. Please try again.";
      try {
        errorMsg = e.toString();
        if (errorMsg.contains("FirebaseException")) {
          errorMsg = "Authentication error occurred. Please try again.";
        }
        errorMsg = _translateError(errorMsg.replaceAll("Exception: ", ""));
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
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
      try { debugPrint("API Sync Error: $e"); } catch (_) {}
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
                      hasError: _firstNameError,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildField(
                      controller: _lastNameController,
                      label: text["lastName"]!,
                      enabled: !_otpSent,
                      hasError: _lastNameError,
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
                  hasError: _emailError,
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
                  hasError: _phoneError,
                ),
              ],

              const SizedBox(height: 16),

              _buildField(
                controller: _passwordController,
                label: text["password"]!,
                icon: Icons.lock,
                isPassword: true,
                enabled: !_otpSent,
                hasError: _passwordError,
                passwordFieldType: _PasswordFieldType.password,
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
                hasError: _confirmPasswordError,
                passwordFieldType: _PasswordFieldType.confirm,
              ),
              if (_confirmPasswordController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Row(
                    children: [
                      Icon(
                        _passwordController.text == _confirmPasswordController.text
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _passwordController.text == _confirmPasswordController.text
                            ? Colors.green
                            : Colors.red,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _passwordController.text == _confirmPasswordController.text
                            ? (_isEnglish ? "Passwords match" : "పాస్‌వర్డ్‌లు సరిపోలాయి")
                            : (_isEnglish ? "Passwords do not match" : "పాస్‌వర్డ్‌లు సరిపోలలేదు"),
                        style: TextStyle(
                          color: _passwordController.text == _confirmPasswordController.text
                              ? Colors.green
                              : Colors.red,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              
              const SizedBox(height: 16),

              if (_otpSent) ...[
                _buildField(
                  controller: _otpController,
                  label: text["otp"]!,
                  icon: Icons.security,
                  keyboardType: TextInputType.number,
                ),

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
                      : Text(_isMobileSignup ? text["verifyOtp"]! : (text["verifyOtp"] ?? (_isEnglish ? "Verify & Continue" : "ధృవీకరించి కొనసాగండి")), 
                          style: const TextStyle(color: Color(0xFF0B2A45), fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isLoading ? null : (_isMobileSignup ? _sendMobileOtp : _sendEmailVerification),
                  child: Text(
                    _isMobileSignup ? text["resendOtp"]! : (_isEnglish ? "Resend OTP" : "OTP మళ్ళీ పంపు"),
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
                      : Text(_isMobileSignup ? text["sendOtp"]! : (text["signUp"] ?? (_isEnglish ? "Sign Up" : "సైన్ అప్")), style: const TextStyle(color: Color(0xFF0B2A45), fontSize: 18, fontWeight: FontWeight.bold)),
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
    bool hasError = false,
    _PasswordFieldType passwordFieldType = _PasswordFieldType.password,
  }) {
    // Determine which obscure state to use based on field type
    final bool isObscured = isPassword
        ? (passwordFieldType == _PasswordFieldType.confirm ? _isObscureConfirm : _isObscurePassword)
        : false;

    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: isObscured,
      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
      keyboardType: keyboardType,
      onChanged: (_) {
        // Clear error highlight when user starts typing
        if (hasError) {
          setState(() {
            if (controller == _firstNameController) _firstNameError = false;
            if (controller == _lastNameController) _lastNameError = false;
            if (controller == _phoneController) _phoneError = false;
            if (controller == _emailController) _emailError = false;
            if (controller == _passwordController) _passwordError = false;
            if (controller == _confirmPasswordController) _confirmPasswordError = false;
          });
        }
      },
      inputFormatters: inputFormatters ?? (keyboardType == TextInputType.phone || label.toLowerCase().contains('phone') || label.contains('ఫోన్')
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hasError ? Colors.red : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF173B60) : Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: hasError ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: hasError ? const BorderSide(color: Colors.red, width: 2.0) : const BorderSide(color: Color(0xFFFFC107), width: 1.5),
        ),
        prefixIcon: icon != null ? Icon(icon, color: hasError ? Colors.red : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)) : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscured ? Icons.visibility : Icons.visibility_off,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                ),
                onPressed: () {
                  setState(() {
                    if (passwordFieldType == _PasswordFieldType.confirm) {
                      _isObscureConfirm = !_isObscureConfirm;
                    } else {
                      _isObscurePassword = !_isObscurePassword;
                    }
                  });
                },
              )
            : null,
      ),
    );
  }
}
