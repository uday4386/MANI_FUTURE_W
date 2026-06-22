// Mobile/VM: uses flutter_tts for speech.
import 'package:flutter_tts/flutter_tts.dart';

/// Native: uses FlutterTts. Import via speech_service.dart.
class SpeechService {
  final FlutterTts _tts = FlutterTts();

  Future<void> init() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _tts.setSpeechRate(0.9);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch);
  }

  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume);
  }

  Future<void> setLanguage(String lang) async {
    await _tts.setLanguage(lang);
  }

  void cancel() {
    _tts.stop();
  }

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  Future<void> speak({
    required String text,
    required String lang,
    double rate = 0.9,
    double pitch = 1.0,
    void Function()? onComplete,
    void Function(String)? onError,
  }) async {
    await _tts.stop();
    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    _speaking = true;
    _tts.setCompletionHandler(() {
      _speaking = false;
      onComplete?.call();
    });
    _tts.setErrorHandler((msg) {
      _speaking = false;
      onError?.call(msg);
    });
    await _tts.speak(text);
  }
}
