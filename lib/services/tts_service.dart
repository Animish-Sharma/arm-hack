import 'package:flutter_tts/flutter_tts.dart';

/// Service for Text-to-Speech functionality
/// Handles speech synthesis with automatic language configuration
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  /// Initialize the TTS service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);  // Normal speech rate
    await _tts.setPitch(1.0);

    _isInitialized = true;
  }

  /// Speak the given text in the specified language
  /// [text] - The text to speak
  /// [languageCode] - Language code (e.g., 'en-US', 'hi-IN')
  Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Set the language before speaking
    await _tts.setLanguage(languageCode);

    // Speak the text
    await _tts.speak(text);
  }

  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Check if currently speaking
  Future<bool> get isSpeaking async {
    final status = await _tts.awaitSpeakCompletion(true);
    return status;
  }

  /// Get available languages
  Future<List<dynamic>> getAvailableLanguages() async {
    return await _tts.getLanguages;
  }

  /// Set completion callback
  void setCompletionHandler(Function() onComplete) {
    _tts.setCompletionHandler(onComplete);
  }

  /// Dispose resources
  void dispose() {
    _tts.stop();
  }
}
