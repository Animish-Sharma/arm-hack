import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

/// Service for Speech-to-Text functionality
/// Handles microphone permissions and speech recognition
class STTService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      return false;
    }

    // Initialize speech-to-text
    _isInitialized = await _speech.initialize(
      onError: (error) => print('STT Error: $error'),
      onStatus: (status) => print('STT Status: $status'),
    );

    return _isInitialized;
  }

  /// Start listening to microphone input
  /// [onResult] callback receives the recognized text
  /// [localeId] specifies the language (e.g., 'en_US', 'hi_IN')
  Future<void> startListening({
    required Function(String) onResult,
    required String localeId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      localeId: localeId,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  /// Stop listening to microphone input
  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Check if currently listening
  bool get isListening => _speech.isListening;

  /// Get available locales for speech recognition
  Future<List<stt.LocaleName>> getAvailableLocales() async {
    return await _speech.locales();
  }

  /// Check if a specific locale is available on the device
  Future<bool> isLocaleAvailable(String localeId) async {
    if (!_isInitialized) {
      await initialize();
    }
    final locales = await _speech.locales();
    return locales.any((locale) => locale.localeId == localeId);
  }

  /// Open Android voice settings for offline language download
  /// This guides users to download missing language packs
  Future<void> openOfflineLanguageSettings() async {
    try {
      // Import is conditional - only works on Android
      final AndroidIntent intent = AndroidIntent(
        action: 'android.settings.VOICE_INPUT_SETTINGS',
      );
      await intent.launch();
    } catch (e) {
      print('Error opening settings: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _speech.cancel();
  }
}
