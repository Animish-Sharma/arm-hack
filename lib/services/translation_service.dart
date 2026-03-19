import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Translation modes supported by the app
enum TranslationMode { englishToHindi, hindiToEnglish }

/// Service for on-device translation using Gemma LLM
/// Leverages LiteRT XNNPACK delegate with Arm NEON instructions for optimized inference
class TranslationService {
  dynamic _gemmaModel;
  dynamic _session; // Persistent session to slash latency
  bool _isInitialized = false;
  bool _isSessionClean = false;

  // Download progress callback (0.0 – 1.0), null when not downloading
  ValueNotifier<double?> downloadProgress = ValueNotifier(null);

  /// URL to the Gemma model file (INT4 quantized)
  static const String modelUrl =
      'https://huggingface.co/ashirbadsahu/arm-hack/resolve/main/gemma3-1b-it-int4.task';
  static const String modelFilename = 'gemma3-1b-it-int4.task';

  /// System instruction for translation-only output
  /// This ensures Gemma returns ONLY the translated text without explanations
  static const String systemInstruction =
      'You are a strict translation tool. '
      'Translate the input and output ONLY the translated text. '
      'Do not include definitions, pronunciations, greetings, or explanations. '
      'Do not use bullet points'
      'Output only the raw translation.';

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Ensure model file is present (download if missing)
      final modelFile = await _ensureModel();
      final modelPath = modelFile.path;

      // Set the model path using the ModelFileManager (Legacy API)
      final modelManager = FlutterGemmaPlugin.instance.modelManager;
      await modelManager.setModelPath(modelPath);

      // Create Gemma model instance using the Legacy API
      // The model uses INT4 quantization for efficient inference
      _gemmaModel = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        maxTokens:
            1024, // Reduced from 1024 to massively lower KV cache allocation latency for short translation strings
        preferredBackend: PreferredBackend
            .cpu, // Switched to CPU to correctly utilize XNNPACK Arm NEON optimzations
      );

      _isInitialized = true;
      print('Gemma model initialized successfully from: $modelPath');
      print('Using LiteRT XNNPACK delegate with Arm NEON optimization');

      return _isInitialized;
    } catch (e) {
      print('Error initializing Gemma: $e');
      return false;
    }
  }

  Future<void> _resetSession() async {
    if (_session != null) await _session.close();
    _session = await _gemmaModel!.createSession(
      temperature: 0.0, // Greedy decoding for raw speed [cite: 181]
      randomSeed: 1,
      topK: 1,
    );
    _isSessionClean = true;
  }

  /// Pre-allocates the session before translation is actually requested
  Future<void> prepareSession() async {
    if (!_isInitialized) return;
    await _resetSession();
  }

  Future<File> _ensureModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${appDir.path}/$modelFilename');

    if (await modelFile.exists()) {
      print('TranslationService: model already cached: ${modelFile.path}');
      return modelFile;
    }

    print('TranslationService: downloading $modelFilename from $modelUrl ...');
    downloadProgress.value = 0.0;

    try {
      final request = http.Request('GET', Uri.parse(modelUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download model: HTTP ${response.statusCode}',
        );
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = modelFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          downloadProgress.value = received / total;
        }
      }

      await sink.flush();
      await sink.close();

      print('TranslationService: downloaded $modelFilename');
      return modelFile;
    } catch (e) {
      downloadProgress.value = null;
      // Clean up partial file
      if (await modelFile.exists()) {
        await modelFile.delete();
      }
      rethrow;
    } finally {
      downloadProgress.value = null;
    }
  }

  /// Translate text based on the selected mode
  /// Returns the translated text or null if translation fails
  Future<String?> translate({
    required String text,
    required TranslationMode mode,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return null;
    }

    try {
      // 1. Reset context window so the model doesn't get "confused" by previous runs
      if (!_isSessionClean) {
        await _resetSession();
      }
      _isSessionClean = false;

      final String prompt = _buildPrompt(text, mode);

      // 2. Direct Query: Optimized for LiteRT XNNPACK/Arm NEON path
      await _session.addQueryChunk(Message.text(text: prompt, isUser: true));

      final String response = await _session.getResponse();

      // 3. Post-processing to clean output without LLM overhead
      return _cleanResponse(response);
    } catch (e) {
      print('Translation error: $e');
      _isInitialized = false;
      return null;
    }
  }

  String _cleanResponse(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'^Hindi:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^English:\s*', caseSensitive: false), '')
        .split('\n')
        .first; // Prevent multi-line hallucinations
  }

  /// Build the translation prompt based on mode
  String _buildPrompt(String text, TranslationMode mode) {
    // Clear, direct instructions for complete translation
    if (mode == TranslationMode.englishToHindi) {
      return 'Translate the complete sentence from English to Hindi. Only output the Hindi translation, nothing else.\n\nEnglish: "$text"\n\nHindi translation:';
    } else {
      return 'Translate the complete sentence from Hindi to English. Only output the English translation, nothing else.\n\nHindi: "$text"\n\nEnglish translation:';
    }
  }

  /// Get target language code for TTS based on translation mode
  String getTargetLanguageCode(TranslationMode mode) {
    switch (mode) {
      case TranslationMode.englishToHindi:
        return 'hi-IN'; // Hindi
      case TranslationMode.hindiToEnglish:
        return 'en-US'; // English
    }
  }

  /// Get source language code for STT based on translation mode
  /// Falls back to English if Hindi is not available on the device
  String getSourceLanguageCode(TranslationMode mode) {
    switch (mode) {
      case TranslationMode.englishToHindi:
        return 'en_US'; // English
      case TranslationMode.hindiToEnglish:
        return 'hi_IN'; // Hindi
    }
  }

  /// Dispose resources
  void dispose() {
    // Cleanup if needed
  }
}
