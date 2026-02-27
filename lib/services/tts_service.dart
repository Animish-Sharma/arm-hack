import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);

    _isInitialized = true;
  }

  Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _tts.setLanguage(languageCode);

    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<bool> get isSpeaking async {
    final status = await _tts.awaitSpeakCompletion(true);
    return status;
  }

  Future<List<dynamic>> getAvailableLanguages() async {
    return await _tts.getLanguages;
  }

  void setCompletionHandler(Function() onComplete) {
    _tts.setCompletionHandler(onComplete);
  }

  void dispose() {
    _tts.stop();
  }
}
