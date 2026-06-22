import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'screens/splash_screen.dart';

// import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:ui';

import 'theme_notifier.dart'; // Import the singleton
import 'services/notification_service.dart';
import 'screens/main_navigation.dart';
// Create a global key for ScaffoldMessenger to allow showing SnackBars from anywhere
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // For Web, Firebase initialization requires explicit options which are usually in firebase_options.dart
    // Since we are running for verification in Chrome, we can skip or handle it gracefully.
    if (!kIsWeb) {
      await Firebase.initializeApp();
      debugPrint("Firebase initialized successfully");
      
      // Background messaging
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      
      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      debugPrint("Running on Web: Skipping Android/iOS specific Firebase initialization");
    }
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }


  final prefs = await SharedPreferences.getInstance();
  final mode = prefs.getString('theme_mode') ?? 'light';
  themeNotifier.value = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;

  // Initialize Notification Service
  if (!kIsWeb) {
    NotificationService().init(scaffoldMessengerKey);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        // Debug print to confirm mode update
        debugPrint("Rebuilding MaterialApp with mode: $mode");
        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF041627),
            cardColor: const Color(0xFF112F4A),
            primaryColor: const Color(0xFF0B2A45),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Colors.white,
            ),
            colorScheme: const ColorScheme.dark(
               primary: Color(0xFF0B2A45),
               secondary: const Color(0xFFFFC107),
            ),
             // Define specific text styles if needed
          ),
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: Colors.white,
            cardColor: Colors.white,
            primaryColor: const Color(0xFF0B2A45),
            colorScheme: const ColorScheme.light(
               primary: Color(0xFF0B2A45),
               secondary: const Color(0xFFFFC107),
            ),
            appBarTheme: const AppBarTheme(
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}


