import 'dart:convert';
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

  // Unified download progress (0.0 - 1.0)
  double? get downloadProgress {
    if (_sttService.downloadProgress.value != null) {
      return _sttService.downloadProgress.value;
    }
    if (_translationService.downloadProgress.value != null) {
      return _translationService.downloadProgress.value;
    }
    return null;
  }

  // Status message for the loading screen
  String get loadingStatus {
    if (_sttService.downloadProgress.value != null) {
      return 'Downloading Whisper model...';
    }
    if (_translationService.downloadProgress.value != null) {
      return 'Downloading Gemma model...';
    }
    return 'Loading models...';
  }

  /// Initialize all services.
  Future<void> initialize() async {
    _updateState(_state.copyWith(state: AppState.initializing));
    try {
      // Listen for download progress from both services
      void onProgress() => notifyListeners();
      
      _sttService.downloadProgress.addListener(onProgress);
      _translationService.downloadProgress.addListener(onProgress);

      final sttOk = await _sttService.initialize();
      if (!sttOk) {
        _updateState(_state.copyWith(
          state: AppState.error,
          errorMessage: 'Microphone permission denied or Whisper model download failed',
        ));
        return;
      }

      final transOk = await _translationService.initialize();
      if (!transOk) {
         _updateState(_state.copyWith(
          state: AppState.error,
          errorMessage: 'Gemma model initialization/download failed',
        ));
        return;
      }

      await _ttsService.initialize();
      
      _sttService.downloadProgress.removeListener(onProgress);
      _translationService.downloadProgress.removeListener(onProgress);
      
      _updateState(_state.copyWith(state: AppState.idle));
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
          print('[Debug] onResult callback called. _benchmarkStartTime=$_benchmarkStartTime');
          int sttLatencyMs = 0;
          if (_benchmarkStartTime != null) {
             sttLatencyMs = DateTime.now().difference(_benchmarkStartTime!).inMilliseconds;
             print('[Benchmark] STT Latency: ${sttLatencyMs}ms');
          } else {
             print('[Benchmark] STT Latency: Skipped (_benchmarkStartTime is null)');
          }
           
          if (recognizedText.isEmpty) {
            _updateState(_state.copyWith(
              state: AppState.error,
              errorMessage: 'No speech detected. Please try again.',
            ));
            return;
          }
          await _translateAndSpeak(recognizedText, sttLatencyMs);
        },
      );
    } catch (e) {
      _updateState(_state.copyWith(
        state: AppState.error,
        errorMessage: 'Speech recognition failed: $e',
      ));
    }
  }

  DateTime? _benchmarkStartTime;

  /// Stop recording and trigger transcription.
  Future<void> stopListening() async {
    print('[Debug] stopListening called. Current state: ${_state.state}');
    if (_state.state != AppState.listening) {
      print('[Debug] stopListening: Not in listening state. Ignoring.');
      return;
    }
    _benchmarkStartTime = DateTime.now();
    print('[Benchmark] Stop received. Processing started at ${_benchmarkStartTime!.toIso8601String()}');
    
    // Update UI immediately to processing state while STT runs
    // We use 'translating' as a general "processing" state for the UI
    _updateState(_state.copyWith(state: AppState.translating));

    await _sttService.stopListening();
  }

  /// Translate text and speak the result.
  Future<void> _translateAndSpeak(String originalText, int sttLatencyMs) async {
    try {
      _updateState(_state.copyWith(state: AppState.translating));

      final transStart = DateTime.now();
      final translatedText = await _translationService.translate(
        text: originalText,
        mode: _state.translationMode,
      );
      final transEnd = DateTime.now();
      final translationLatencyMs = transEnd.difference(transStart).inMilliseconds;
      print('[Benchmark] Translation Latency: ${translationLatencyMs}ms');

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

      final ttsStart = DateTime.now();
      
      // We'll consider TTS "processing" time as the time until the speak command is issued
      // plus the time it takes to synthesize.
      // Since flutter_tts is async, we'll measure the time until the completion handler fires
      // if possible, but the original code had completion handler setup.
      // Actually, wait, the original code had:
      // _ttsService.setCompletionHandler(() { ... });
      // await _ttsService.speak(...);
      // The completion handler is called when speaking FINISHES.
      // This includes the duration of the speech itself.
      // "TTS Latency" usually refers to time to *start* speaking (Time to First Audio).
      // But for a full pipeline benchmark, total time is also interesting.
      // Let's stick to the previous pattern: measure until completion for now as per original code.
      
      // I will refactor to use a Completer for the TTS to ensure we can await it if needed,
      // but sticking to the existing pattern is less risky.
      // I need to inject the logging into the completion handler or after.
      // The original code printed latency in the completion handler.
      // I will move the logging logic there.

      _ttsService.setCompletionHandler(() {
        final ttsEnd = DateTime.now();
        final ttsLatencyMs = ttsEnd.difference(ttsStart).inMilliseconds;
        print('[Benchmark] TTS Latency: ${ttsLatencyMs}ms');
        
        final totalLatencyMs = sttLatencyMs + translationLatencyMs + ttsLatencyMs;
        if (_benchmarkStartTime != null) {
             print('[Benchmark] Total Pipeline Latency: ${totalLatencyMs}ms');
        }

        // Log structured benchmark data
        final benchmarkData = {
          'timestamp': DateTime.now().toIso8601String(),
          'input_text': originalText,
          'input_language': _state.translationMode == TranslationMode.englishToHindi ? 'en' : 'hi',
          'translated_text': translatedText,
          'output_language': _state.translationMode == TranslationMode.englishToHindi ? 'hi' : 'en',
          'stt_latency_ms': sttLatencyMs,
          'translation_latency_ms': translationLatencyMs,
          'tts_latency_ms': ttsLatencyMs,
          'total_latency_ms': totalLatencyMs,
        };
        print('BENCHMARK_DATA: ${jsonEncode(benchmarkData)}');

        _updateState(_state.copyWith(state: AppState.idle));
      });

      await _ttsService.speak(
        text: translatedText,
        languageCode: targetLanguage,
      );


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

