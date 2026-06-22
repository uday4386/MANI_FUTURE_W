import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../screens/vertical_news_pager.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final ValueNotifier<int> updateCount = ValueNotifier<int>(0);
  
  GlobalKey<ScaffoldMessengerState>? _scaffoldKey;
  bool _isEnabled = false;
  static String? pendingArticleId;

  Future<void> init(GlobalKey<ScaffoldMessengerState> key) async {
    _scaffoldKey = key;
    
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('notifications_enabled') ?? true;

    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    }

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle local notification click
        if (details.payload != null) {
          _handleDeepLink(details.payload!);
        }
      },
    );

    // Get FCM Token (optional, for individual targeting)
    String? token = await _fcm.getToken();
    debugPrint("FCM Token: $token");

    // Handle incoming messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM Message received in foreground: ${message.notification?.title}");
      _showLocalNotification(message);
      if (_isEnabled) {
        updateCount.value++;
      }
    });

    // Handle background click (when app is opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
       debugPrint("FCM Message clicked: ${message.notification?.title}");
       _handleMessage(message);
    });

    // Check for initial message (if app was terminated)
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Subscribe to a general topic (e.g., 'news')
    await _fcm.subscribeToTopic('news');
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data.containsKey('id')) {
      _handleDeepLink(message.data['id']);
    }
  }

  Future<void> _handleDeepLink(String articleId) async {
    try {
      // Fetch article data
      final article = await ApiService.getNewsItem(articleId);
      
      // Get saved language
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('selected_language') ?? 'Telugu';


      // Navigate to detail view
      if (navigatorKey.currentState != null) {
        // Clear any pending ID since we're handling it now
        pendingArticleId = null;
        
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => VerticalNewsPager(
              newsList: [article],
              initialIndex: 0,
              selectedLanguage: language,
            ),
          ),
        );
      } else {
        // App is still starting up, save for later
        pendingArticleId = articleId;
        debugPrint("Navigator state is null, saved pendingArticleId: $articleId");
      }
    } catch (e) {
      debugPrint("Error handling deep link: $e");
      _showInAppBanner("Could not open article. Please check your connection.");
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    String? articleId = message.data['id'];

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            importance: Importance.max,
            priority: Priority.high,
            icon: 'ic_notification',
            largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
          ),
        ),
        payload: articleId,
      );
    }
  }

  void _showInAppBanner(String message) {
    _scaffoldKey?.currentState?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0B2A45),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> toggle(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    _isEnabled = enabled;
    
    if (enabled) {
      await _fcm.subscribeToTopic('news');
    } else {
      await _fcm.unsubscribeFromTopic('news');
    }
  }
}
