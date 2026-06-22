// On web: browser Speech Synthesis (same as admin — clear Telugu & English).
// On mobile: Flutter TTS.
export 'speech_service_native.dart' if (dart.library.html) 'speech_service_web.dart';
