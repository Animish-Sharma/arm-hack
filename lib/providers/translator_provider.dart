import 'package:flutter/foundation.dart';
import 'package:speech_translator/models/translation_state.dart';
import 'package:speech_translator/services/stt_service.dart';
import 'package:speech_translator/services/translation_service.dart';
import 'package:speech_translator/services/tts_service.dart';

/// Provider that orchestrates the STT → Gemma → TTS workflow
/// Manages state transitions and coordinates all services
class TranslatorProvider extends ChangeNotifier {
  final STTService _sttService = STTService();
  final TranslationService _translationService = TranslationService();
  final TTSService _ttsService = TTSService();

  TranslationState _state = TranslationState();
  TranslationState get state => _state;

  bool _isHindiAvailable = false;
  bool get isHindiAvailable => _isHindiAvailable;

  /// Initialize all services
  Future<void> initialize() async {
    try {
      await _sttService.initialize();
      await _translationService.initialize();
      await _ttsService.initialize();
      
      // Check if Hindi STT is available
      _isHindiAvailable = await _sttService.isLocaleAvailable('hi_IN');
      print('Hindi STT available: $_isHindiAvailable');
    } catch (e) {
      _updateState(_state.copyWith(
        state: AppState.error,
        errorMessage: 'Initialization failed: $e',
      ));
    }
  }

  /// Toggle translation mode between English→Hindi and Hindi→English
  void toggleTranslationMode() {
    final newMode = _state.translationMode == TranslationMode.englishToHindi
        ? TranslationMode.hindiToEnglish
        : TranslationMode.englishToHindi;

    _updateState(_state.copyWith(translationMode: newMode));
    
    // Check if switching to Hindi mode without Hindi STT available
    if (newMode == TranslationMode.hindiToEnglish && !_isHindiAvailable) {
      // Set a flag to show dialog in UI
      _updateState(_state.copyWith(
        errorMessage: 'HINDI_UNAVAILABLE',
      ));
    }
  }

  /// Start the translation workflow
  /// 1. Start listening to microphone
  /// 2. On speech finalization, translate with Gemma
  /// 3. Speak the translated text
  Future<void> startTranslation() async {
    if (_state.state != AppState.idle) return;

    try {
      // Update state to listening
      _updateState(_state.copyWith(state: AppState.listening));

      // Get the source language based on current mode
      final sourceLocale = _translationService.getSourceLanguageCode(_state.translationMode);

      // Start listening
      await _sttService.startListening(
        localeId: sourceLocale,
        onResult: (recognizedText) async {
          // Speech finalized, stop listening
          await _sttService.stopListening();

          // Translate the text
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

  /// Stop listening (cancel current operation)
  Future<void> stopListening() async {
    await _sttService.stopListening();
    _updateState(_state.copyWith(state: AppState.idle));
  }

  /// Translate text and speak the result
  Future<void> _translateAndSpeak(String originalText) async {
    try {
      // Update state to translating (show loading animation)
      _updateState(_state.copyWith(state: AppState.translating));

      // Translate using Gemma
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

      // Add to history
      final entry = TranslationEntry(
        originalText: originalText,
        translatedText: translatedText,
        mode: _state.translationMode,
        timestamp: DateTime.now(),
      );

      final updatedHistory = [..._state.history, entry];

      // Update state to speaking
      _updateState(_state.copyWith(
        state: AppState.speaking,
        history: updatedHistory,
      ));

      // Get target language for TTS
      final targetLanguage = _translationService.getTargetLanguageCode(_state.translationMode);

      // Set completion handler to return to idle state
      _ttsService.setCompletionHandler(() {
        _updateState(_state.copyWith(state: AppState.idle));
      });

      // Speak the translated text
      await _ttsService.speak(
        text: translatedText,
        languageCode: targetLanguage,
      );

      // If TTS completes immediately, update state
      _updateState(_state.copyWith(state: AppState.idle));
    } catch (e) {
      _updateState(_state.copyWith(
        state: AppState.error,
        errorMessage: 'Translation/TTS failed: $e',
      ));
    }
  }

  /// Update state and notify listeners
  void _updateState(TranslationState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    if (_state.state == AppState.error) {
      _updateState(_state.copyWith(
        state: AppState.idle,
        errorMessage: null,
      ));
    }
  }

  /// Open system settings to download offline language packs
  Future<void> openLanguageSettings() async {
    await _sttService.openOfflineLanguageSettings();
  }

  @override
  void dispose() {
    _sttService.dispose();
    _translationService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
