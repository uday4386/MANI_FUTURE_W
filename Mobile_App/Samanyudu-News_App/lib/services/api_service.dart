import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class ApiService {
  // Use the deployed API by default, but automatically use localhost when the
  // Flutter web app itself is opened from localhost/127.0.0.1.
  static const bool _forceLocal = false; // Must be false for production
  static const String _localIp = '192.168.0.19';
  static bool lastFetchOffline = false;

  static bool get _isRunningOnLocalWeb {
    if (!kIsWeb) return false;
    final host = Uri.base.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1';
  }

  static bool get _isLocal => _forceLocal || _isRunningOnLocalWeb || kDebugMode;

  static String get baseUrl {
    if (_isLocal) {
      if (kIsWeb) return 'http://localhost:5000/api';
      return 'http://$_localIp:5000/api';
    }
    // Production API on DigitalOcean
    return 'https://api.samanyudutv.in/api';
  }

  static String normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return "";
    var normalized = url;

    // If we are in local mode, we want to keep localhost or local IP URLs as they are
    if (_isLocal &&
        (normalized.contains('localhost') ||
            normalized.contains(_localIp) ||
            normalized.contains('127.0.0.1'))) {
      return normalized;
    }

    normalized = normalized.replaceAll(
      RegExp(r'^http://api\.samanyudutv.in'),
      'https://api.samanyudutv.in',
    );

    normalized = normalized.replaceAll(
      RegExp(r'^http://localhost:5000'),
      'https://api.samanyudutv.in',
    );

    normalized = normalized.replaceAll(
      RegExp(r'^http://127\.0\.0\.1:5000'),
      'https://api.samanyudutv.in',
    );

    normalized = normalized.replaceAll(
      RegExp(
        r'^http://(10\.\d+\.\d+\.\d+|172\.(1[6-9]|2[0-9]|3[0-1])\.\d+\.\d+|192\.168\.\d+\.\d+):5000',
      ),
      'https://api.samanyudutv.in',
    );

    if (kIsWeb && normalized.startsWith('http')) {
      bool isVideo = normalized.toLowerCase().endsWith('.mp4') || 
                     normalized.toLowerCase().endsWith('.webm') || 
                     normalized.toLowerCase().endsWith('.mov') ||
                     normalized.contains('/uploads/videos/');
      
      if (!normalized.contains('/api/image-proxy') && !isVideo) {
        normalized =
            '$baseUrl/image-proxy?url=${Uri.encodeComponent(normalized)}';
      }
    }

    return normalized;
  }

  // ============================
  // AUTH ROUTES
  // ============================
  static Future<bool> sendOtp(String phone, {String? type}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone, if (type != null) 'type': type}),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to send OTP');
    }
  }

  static Future<Map<String, dynamic>> resetPasswordMobile({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password-mobile'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'phone': phone,
        'otp': otp,
        'newPassword': newPassword,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Reset failed');
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone, 'otp': otp}),
    );
    if (response.statusCode == 200) {
      return json.decode(
        response.body,
      ); // Should return { success, message, user }
    } else {
      String errMsg = 'Invalid OTP or verification failed';
      try {
        final data = json.decode(response.body);
        if (data['error'] != null) errMsg = data['error'];
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  static Future<Map<String, dynamic>> registerWithMobile({
    required String firstName,
    required String lastName,
    required String phone,
    required String otp,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register-mobile'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'otp': otp,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      String errMsg = 'Registration failed';
      try {
        final data = json.decode(response.body);
        if (data['error'] != null) errMsg = data['error'];
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  static Future<Map<String, dynamic>> loginWithMobile(
    String phone,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login-mobile'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone, 'password': password}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      String errMsg = 'Login failed';
      try {
        final data = json.decode(response.body);
        if (data['error'] != null) errMsg = data['error'];
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  static Future<Map<String, dynamic>> loginWithOtp(
    String phone,
    String otp,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login-otp'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone, 'otp': otp}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final data = json.decode(response.body);
      throw Exception(data['error'] ?? 'Login failed');
    }
  }

  // Email Auth Methods
  static Future<bool> sendEmailOtp(String email, {String type = "signup"}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-email-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'type': type}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) return true;
      throw data['error'] ?? "Failed to send OTP";
    } catch (e) { throw e.toString(); }
  }

  static Future<Map<String, dynamic>> registerWithEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String otp,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register-email'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'otp': otp,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      String msg = 'Registration failed';
      try {
        final data = json.decode(response.body);
        msg = data['error'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<Map<String, dynamic>> loginWithEmail(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login-email'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      String msg = 'Login failed';
      try {
        final data = json.decode(response.body);
        msg = data['error'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  // ============================
  // USER ROUTES
  // ============================
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/user/$userId/stats'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load user stats');
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile(
    String userId,
    String name,
    String phone,
    String oldName,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user/$userId/profile'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'phone': phone, 'oldName': oldName}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update profile: ${response.body}');
    }
  }

  static Future<void> syncUserLikes(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/$userId/likes'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<String> newsLikes = List<String>.from(
          (data['news'] as List).map((x) => x.toString()),
        );
        final List<String> shortsLikes = List<String>.from(
          (data['shorts'] as List).map((x) => x.toString()),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('liked_news_ids', newsLikes);
        await prefs.setStringList('liked_shorts_ids', shortsLikes);
      }
    } catch (e) {
      debugPrint('Error syncing user likes: $e');
    }
  }

  static Future<void> syncSavedItems(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/$userId/saved'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<String> newsSaved = List<String>.from(
          (data['news'] as List).map((x) => x.toString()),
        );
        final List<String> shortsSaved = List<String>.from(
          (data['shorts'] as List).map((x) => x.toString()),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('saved_news_ids', newsSaved);
        await prefs.setStringList('saved_shorts_ids', shortsSaved);
      }
    } catch (e) {
      debugPrint('Error syncing saved items: $e');
    }
  }

  static Future<void> clearSavedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_news_ids', []);
      await prefs.setStringList('saved_shorts_ids', []);
    } catch (e) {
      debugPrint('Error clearing local saved items: $e');
    }
  }

  static Future<void> saveItem(
    String userId,
    String itemId,
    String itemType,
    bool isSaving,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/$userId/save'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'item_id': itemId,
        'item_type': itemType,
        'action': isSaving ? 'save' : 'unsave',
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update saved item');
    }
  }

  static Future<void> clearUserLikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('liked_news_ids', []);
      await prefs.setStringList('liked_shorts_ids', []);
    } catch (e) {
      debugPrint('Error clearing local user likes: $e');
    }
  }

  static Future<void> clearAllUserData() async {
    await clearUserLikes();
    await clearSavedItems();
  }

  // ============================
  // NEWS ROUTES
  // ============================
  static Future<List<dynamic>> getNews() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/news')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> news = json.decode(response.body);
        lastFetchOffline = false;
        await DatabaseService().cacheNews(news);
        return news;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network error in getNews, trying cache: $e');
      lastFetchOffline = true;
      final cachedNews = await DatabaseService().getCachedNews();
      if (cachedNews.isNotEmpty) {
        return cachedNews;
      }
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getNewsItem(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/article/$id'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load news item');
    }
  }

  static Future<int> likeNews(
    String newsId,
    String userId,
    bool isLiking,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/news/$newsId/like'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'action': isLiking ? 'like' : 'unlike',
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['likes'] ?? 0;
    } else {
      throw Exception('Failed to update news like');
    }
  }

  // ============================
  // SHORTS ROUTES
  // ============================
  static Future<List<dynamic>> getShorts() async {
    final response = await http.get(Uri.parse('$baseUrl/shorts'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load shorts');
    }
  }

  static Future<List<dynamic>> getShortComments(String shortId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/shorts/$shortId/comments'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load comments');
    }
  }

  static Future<void> deleteShortComment(String commentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/shorts/comments/$commentId'),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete comment');
    }
  }

  static Future<int> likeShort(
    String shortId,
    String userId,
    bool isLiking,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shorts/$shortId/like'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'action': isLiking ? 'like' : 'unlike',
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['likes'] ?? 0;
    } else {
      throw Exception('Failed to update short like');
    }
  }

  static Future<void> viewShort(String shortId) async {
    try {
      await http.post(Uri.parse('$baseUrl/shorts/$shortId/view'));
    } catch (e) {
      print("viewShort pending on backend");
    }
  }

  static Future<dynamic> postComment(
    String shortId,
    String userId,
    String userName,
    String commentText,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shorts/comments'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'short_id': shortId,
        'user_id': userId,
        'user_name': userName,
        'comment_text': commentText,
      }),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to post comment');
    }
  }

  // ============================
  // ADVERTISEMENTS ROUTES
  // ============================
  static Future<List<dynamic>> getAdvertisements() async {
    final response = await http.get(Uri.parse('$baseUrl/advertisements'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load advertisements');
    }
  }

  // ============================
  // UPLOAD AND POST ROUTES
  // ============================
  static Future<String> uploadMedia(List<int> bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(responseBody);
      return jsonResponse['url'];
    } else {
      throw Exception('Failed to upload media: $responseBody');
    }
  }

  static Future<void> createPendingNews(Map<String, dynamic> newsData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/news'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(newsData),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to submit news');
    }
  }

  static Future<Map<String, dynamic>> registerWithFirebase({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register-firebase'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'uid': uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
      }),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> registerWithFirebasePhone({
    required String uid,
    required String phone,
    String? firstName,
    String? lastName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register-firebase-phone'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'uid': uid,
        'phone': phone,
        'firstName': firstName,
        'lastName': lastName,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to sync phone user: ${response.body}');
    }
  }

  // ============================
  // SETTINGS ROUTES
  // ============================
    static Future<bool> resetPasswordEmail({required String email, required String otp, required String newPassword}) async {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/reset-password-email'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({"email": email, "otp": otp, "newPassword": newPassword}),
        );
        if (response.statusCode == 200) return true;
        
        final data = json.decode(response.body);
        throw data["error"] ?? "Failed to reset password";
      } catch (e) { 
        if (e is FormatException) throw "Server Error: Invalid response from server";
        throw e.toString(); 
      }
    }

  static Future<bool> isMaintenanceMode() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/admin/settings/maintenance'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['enabled'] == true || data['enabled'] == 'true';
      }
      return false;
    } catch (e) {
      debugPrint('Error checking maintenance mode: $e');
      return false;
    }
  }

  static Future<bool> verifyEmail(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Verification failed');
    }
  }
}
