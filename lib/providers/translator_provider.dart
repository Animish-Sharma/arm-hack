import 'package:flutter/foundation.dart';
import 'package:speech_translator/models/translation_state.dart';
import 'package:speech_translator/services/stt_service.dart';
import 'package:speech_translator/services/translation_service.dart';
import 'package:speech_translator/services/tts_service.dart';

/// Provider that orchestrates the STT (Whisper) → Gemma → TTS workflow.
class TranslatorProvider extends ChangeNotifier {
  final STTService _sttService = STTService();
  final TranslationService _translationService = TranslationService();
  final TTSService _ttsService = TTSService();

  TranslationState _state = TranslationState();
  TranslationState get state => _state;

  // Download progress forwarded from STTService (null = not downloading)
  double? get downloadProgress => _sttService.downloadProgress.value;

  /// Initialize all services.
  Future<void> initialize() async {
    try {
      // Listen for model download progress and forward to UI
      _sttService.downloadProgress.addListener(() {
        notifyListeners();
      });

      final sttOk = await _sttService.initialize();
      if (!sttOk) {
        _updateState(_state.copyWith(
          state: AppState.error,
          errorMessage: 'Microphone permission denied or model download failed',
        ));
        return;
      }

      await _translationService.initialize();
      await _ttsService.initialize();
    } catch (e) {
      _updateState(_state.copyWith(
        state: AppState.error,
        errorMessage: 'Initialization failed: $e',
      ));
    }
  }

  /// Toggle translation mode between English→Hindi and Hindi→English.
  void toggleTranslationMode() {
    final newMode = _state.translationMode == TranslationMode.englishToHindi
        ? TranslationMode.hindiToEnglish
        : TranslationMode.englishToHindi;
    _updateState(_state.copyWith(translationMode: newMode));
  }

  /// Start the translation workflow:
  ///   1. Record microphone audio (Whisper STT)
  ///   2. On stop → transcribe → translate with Gemma → speak
  Future<void> startTranslation() async {
    if (_state.state != AppState.idle) return;

    try {
      _updateState(_state.copyWith(state: AppState.listening));

      // Locale drives which Whisper model is loaded:
      //   en_US → English model (ggml-tiny-en-q4_0.bin)
      //   hi_IN → Hindi model   (ggml-tiny-hindi-q4_0.bin)
      final sourceLocale =
          _translationService.getSourceLanguageCode(_state.translationMode);

      await _sttService.startListening(
        localeId: sourceLocale,
        onResult: (recognizedText) async {
          if (recognizedText.isEmpty) {
            _updateState(_state.copyWith(
              state: AppState.error,
              errorMessage: 'No speech detected. Please try again.',
            ));
            return;
          }
          await _translateAndSpeak(recognizedText);
        },
      );
    } catch (e) {
      _updateState(_state.copyWith(
        state: AppState.error,
        errorMessage: 'Speech recognition failed: $e',
      ));
    }
  }

  /// Stop recording and trigger transcription.
  Future<void> stopListening() async {
    if (_state.state != AppState.listening) return;
    // State will transition to translating once transcription completes
    await _sttService.stopListening();
  }

  /// Translate text and speak the result.
  Future<void> _translateAndSpeak(String originalText) async {
    try {
      _updateState(_state.copyWith(state: AppState.translating));

      final translatedText = await _translationService.translate(
        text: originalText,
        mode: _state.translationMode,
      );

      if (translatedText == null || translatedText.isEmpty) {
        _updateState(_state.copyWith(
          state: AppState.error,
          errorMessage: 'Translation failed',
        ));
        return;
      }

      final entry = TranslationEntry(
        originalText: originalText,
        translatedText: translatedText,
        mode: _state.translationMode,
        timestamp: DateTime.now(),
      );

      _updateState(_state.copyWith(
        state: AppState.speaking,
        history: [..._state.history, entry],
      ));

      final targetLanguage =
          _translationService.getTargetLanguageCode(_state.translationMode);

      _ttsService.setCompletionHandler(() {
        _updateState(_state.copyWith(state: AppState.idle));
      });

      await _ttsService.speak(
        text: translatedText,
        languageCode: targetLanguage,
      );

      _updateState(_state.copyWith(state: AppState.idle));
    } catch (e) {
      _updateState(_state.copyWith(
        state: AppState.error,
        errorMessage: 'Translation/TTS failed: $e',
      ));
    }
  }

  void _updateState(TranslationState newState) {
    _state = newState;
    notifyListeners();
  }

  void clearError() {
    if (_state.state == AppState.error) {
      _updateState(_state.copyWith(state: AppState.idle, errorMessage: null));
    }
  }

  @override
  void dispose() {
    _sttService.dispose();
    _translationService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
