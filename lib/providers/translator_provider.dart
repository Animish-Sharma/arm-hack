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

  double? get downloadProgress {
    if (_sttService.downloadProgress.value != null) {
      return _sttService.downloadProgress.value;
    }
    if (_translationService.downloadProgress.value != null) {
      return _translationService.downloadProgress.value;
    }
    return null;
  }
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


  void toggleTranslationMode() {
    final newMode = _state.translationMode == TranslationMode.englishToHindi
        ? TranslationMode.hindiToEnglish
        : TranslationMode.englishToHindi;
    _updateState(_state.copyWith(translationMode: newMode));
  }


  Future<void> startTranslation() async {
    if (_state.state != AppState.idle) return;

    try {
      _updateState(_state.copyWith(state: AppState.listening));


      final sourceLocale =
          _translationService.getSourceLanguageCode(_state.translationMode);

      await _sttService.startListening(
        localeId: sourceLocale,
        onResult: (recognizedText) async {
          print('[Debug] onResult callback called. _benchmarkStartTime=$_benchmarkStartTime');
          int? sttLatencyMs;
          if (_benchmarkStartTime != null) {
             final sttLatency = DateTime.now().difference(_benchmarkStartTime!);
             sttLatencyMs = sttLatency.inMilliseconds;
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
          await _translateAndSpeak(recognizedText, sttLatencyMs: sttLatencyMs);
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

  Future<void> stopListening() async {
    print('[Debug] stopListening called. Current state: ${_state.state}');
    if (_state.state != AppState.listening) {
      print('[Debug] stopListening: Not in listening state. Ignoring.');
      return;
    }
    _benchmarkStartTime = DateTime.now();
    print('[Benchmark] Stop received. Processing started at ${_benchmarkStartTime!.toIso8601String()}');
    

    _updateState(_state.copyWith(state: AppState.translating));

    await _sttService.stopListening();
  }


  Future<void> _translateAndSpeak(String originalText, {int? sttLatencyMs}) async {
    try {
      _updateState(_state.copyWith(state: AppState.translating));

      final transStart = DateTime.now();
      final translatedText = await _translationService.translate(
        text: originalText,
        mode: _state.translationMode,
      );
      final transEnd = DateTime.now();
      final transLatencyMs = transEnd.difference(transStart).inMilliseconds;
      print('[Benchmark] Translation Latency: ${transLatencyMs}ms');

      int estimatedTokens = 0;
      double tokensPerSecond = 0.0;
      if (translatedText != null && translatedText.isNotEmpty) {
        // Rough estimate: 1 token ≈ 4 characters
        estimatedTokens = (translatedText.length / 4).ceil();
        if (transLatencyMs > 0) {
          tokensPerSecond = estimatedTokens / (transLatencyMs / 1000.0);
        }
      }
      print('[Benchmark] Estimated Output Tokens: $estimatedTokens, LLM TPS: ${tokensPerSecond.toStringAsFixed(2)}');

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
      _ttsService.setCompletionHandler(() {
        final ttsEnd = DateTime.now();
        final ttsLatencyMs = ttsEnd.difference(ttsStart).inMilliseconds;
        print('[Benchmark] TTS Latency: ${ttsLatencyMs}ms');
        
        int? totalLatencyMs;
        if (_benchmarkStartTime != null) {
             totalLatencyMs = ttsEnd.difference(_benchmarkStartTime!).inMilliseconds;
             print('[Benchmark] Total Pipeline Latency: ${totalLatencyMs}ms');
        }
        
        try {
          final benchmarkData = {
            'timestamp': DateTime.now().toIso8601String(),
            'input_text': originalText,
            'input_language': _translationService.getSourceLanguageCode(_state.translationMode),
            'translated_text': translatedText,
            'output_language': _translationService.getTargetLanguageCode(_state.translationMode),
            'stt_latency_ms': sttLatencyMs,
            'translation_latency_ms': transLatencyMs,
            'tts_latency_ms': ttsLatencyMs,
            'total_latency_ms': totalLatencyMs,
            'estimated_tokens': estimatedTokens,
            'tokens_per_second': double.parse(tokensPerSecond.toStringAsFixed(2)),
          };
          print('BENCHMARK_DATA: ${jsonEncode(benchmarkData)}');
        } catch (e) {
          print('Error encoding benchmark data: $e');
        }

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