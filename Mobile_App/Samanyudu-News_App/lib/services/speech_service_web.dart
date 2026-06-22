// Uses browser Speech Synthesis API (same as admin dashboard) for clear Telugu & English.
import 'dart:html' as html;

/// Web: uses browser Speech Synthesis (same as admin). Import via speech_service.dart.
class SpeechService {
  html.SpeechSynthesis get _synth => html.window.speechSynthesis!;

  Future<void> init() async {
    _synth.getVoices();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> setSpeechRate(double rate) async {}
  Future<void> setPitch(double pitch) async {}
  Future<void> setVolume(double volume) async {}
  Future<void> setLanguage(String lang) async {}

  void cancel() {
    _synth.cancel();
  }

  bool get isSpeaking => _synth.speaking ?? false;

  void speak({
    required String text,
    required String lang,
    double rate = 0.9,
    double pitch = 1.0,
    void Function()? onComplete,
    void Function(String)? onError,
  }) {
    _synth.cancel();
    final utterance = html.SpeechSynthesisUtterance(text);
    utterance.rate = rate;
    utterance.pitch = pitch;
    utterance.lang = lang;

    final voices = _synth.getVoices();
    html.SpeechSynthesisVoice? preferredVoice;

    if (lang.startsWith('te')) {
      final teluguVoices = voices.where((v) => (v.lang ?? '').toLowerCase().contains('te')).toList();
      for (final v in teluguVoices) {
        if ((v.name ?? '').contains('Google')) {
          preferredVoice = v;
          break;
        }
      }
      if (preferredVoice == null) {
        for (final v in teluguVoices) {
          if ((v.name ?? '').toLowerCase().contains('kalpana')) {
            preferredVoice = v;
            break;
          }
        }
      }
      if (preferredVoice == null && teluguVoices.isNotEmpty) {
        preferredVoice = teluguVoices.first;
      }
    } else if (lang.startsWith('hi')) {
      final hindiVoices = voices.where((v) => (v.lang ?? '').toLowerCase().contains('hi')).toList();
      for (final v in hindiVoices) {
        if ((v.name ?? '').contains('Female') || (v.name ?? '').contains('Google')) {
          preferredVoice = v;
          break;
        }
      }
      preferredVoice ??= hindiVoices.isNotEmpty ? hindiVoices.first : null;
    } else {
      final enVoices = voices.where((v) {
        final l = (v.lang ?? '').toLowerCase();
        return l.startsWith('en-in') || l.startsWith('en_us') || l.startsWith('en-us') || l.startsWith('en-gb');
      }).toList();
      for (final v in enVoices) {
        final n = v.name ?? '';
        if ((v.lang == 'en-IN' || (v.lang ?? '').toLowerCase().startsWith('en-in')) &&
            (n.contains('Google') || n.contains('Heera') || n.contains('Rishi') || n.toLowerCase().contains('india'))) {
          preferredVoice = v;
          break;
        }
      }
      if (preferredVoice == null && enVoices.isNotEmpty) {
        for (final v in enVoices) {
          if ((v.lang ?? '').toLowerCase().startsWith('en-in')) {
            preferredVoice = v;
            break;
          }
        }
        preferredVoice ??= enVoices.first;
      }
      preferredVoice ??= enVoices.isNotEmpty ? enVoices.first : null;
      if (preferredVoice == null) {
        for (final v in voices) {
          if ((v.lang ?? '').toLowerCase().startsWith('en')) {
            preferredVoice = v;
            break;
          }
        }
      }
    }

    if (preferredVoice != null) {
      utterance.voice = preferredVoice;
    }

    utterance.onEnd.listen((_) {
      onComplete?.call();
    });
    utterance.onError.listen((_) {
      onError?.call('speech error');
    });

    _synth.speak(utterance);
  }
}
