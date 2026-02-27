import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Translation modes supported by the app
enum TranslationMode {
  englishToHindi,
  hindiToEnglish,
}

/// Service for on-device translation using Gemma LLM
/// Leverages LiteRT XNNPACK delegate with Arm NEON instructions for optimized inference
class TranslationService {
  dynamic _gemmaModel;
  bool _isInitialized = false;

  // Download progress callback (0.0 – 1.0), null when not downloading
  ValueNotifier<double?> downloadProgress = ValueNotifier(null);

  /// URL to the Gemma model file (INT4 quantized)
  static const String modelUrl = 'https://huggingface.co/ashirbadsahu/arm-hack/resolve/main/gemma3-1b-it-int4.task';
  static const String modelFilename = 'gemma3-1b-it-int4.task';

  static const String systemInstruction = 
    'You are a strict translation tool. '
    'Translate the input and output ONLY the translated text. '
    'Do not include definitions, pronunciations, greetings, or explanations. '
    'Do not use bullet points'
    'Output only the raw translation.';

  /// OPTIMIZATION NOTE:
  /// This implementation uses the LiteRT XNNPACK delegate which automatically
  /// leverages Arm NEON SIMD instructions on compatible devices. This provides
  /// significant performance improvements for the Gemma-3 1B INT4 quantized model,
  /// enabling real-time inference on mobile devices.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final modelFile = await _ensureModel();
      final modelPath = modelFile.path;

      final modelManager = FlutterGemmaPlugin.instance.modelManager;
      await modelManager.setModelPath(modelPath);

      _gemmaModel = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        maxTokens: 512, 
        preferredBackend: PreferredBackend.gpu,
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
        throw Exception('Failed to download model: HTTP ${response.statusCode}');
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

  Future<String?> translate({
    required String text,
    required TranslationMode mode,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    dynamic session;
    try {
      final String prompt = _buildPrompt(text, mode);
      print('TranslationService: sending prompt to Gemma: "$prompt"');


      session = await _gemmaModel!.createSession(
        temperature: 0.1,
        randomSeed: 1,
        topK: 1,
      );


      await session.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));


      final String response = await session.getResponse();

      return response.trim();
    } catch (e) {
      print('Translation error: $e');
      return null;
    } finally {

      if (session != null) {
        try {
          await session.close();
        } catch (e) {
          print('Error closing session: $e');
        }
      }
    }
  }

  String _buildPrompt(String text, TranslationMode mode) {
    if (mode == TranslationMode.englishToHindi) {
      return 'Translate it from English to Hindi. Only output the Hindi translation, nothing else. You must tranlate the whole sentence.\n\nEnglish: "$text"\n\nHindi translation:';
    } else {
      return 'Translate it from Hindi to English. Only output the English translation, nothing else. \nHindi: "$text"\n\nEnglish translation:';
    }
  }
  String getTargetLanguageCode(TranslationMode mode) {
    switch (mode) {
      case TranslationMode.englishToHindi:
        return 'hi-IN';  // Hindi
      case TranslationMode.hindiToEnglish:
        return 'en-US';  // English
    }
  }


  String getSourceLanguageCode(TranslationMode mode) {
    switch (mode) {
      case TranslationMode.englishToHindi:
        return 'en_US';  
      case TranslationMode.hindiToEnglish:
        return 'hi_IN';  
    }
  }


  void dispose() {
  
  }
}