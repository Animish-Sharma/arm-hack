import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'whisper_channel.dart';

class _WhisperModel {
  final String filename;
  final String url;
  final String language;

  const _WhisperModel({
    required this.filename,
    required this.url,
    required this.language,
  });
}

const _kEnglishModel = _WhisperModel(
  filename: 'ggml-tiny-en-q4_0.bin',
  url: 'https://huggingface.co/ashirbadsahu/arm-hack/resolve/main/models/ggml-tiny-en-q4_0.bin',
  language: 'en',
);

const _kHindiModel = _WhisperModel(
  filename: 'ggml-tiny-hindi-q4_0.bin',
  url: 'https://huggingface.co/ashirbadsahu/arm-hack/resolve/main/models/ggml-tiny-hindi-q4_0.bin',
  language: 'hi',
);

class STTService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isInitialized = false;
  bool _isListening = false;
  String? _currentAudioPath;
  Function(String)? _onResult;
  _WhisperModel? _activeModel;

  ValueNotifier<double?> downloadProgress = ValueNotifier(null);

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('STTService: microphone permission denied');
      return false;
    }

    try {
      await _ensureModel(_kEnglishModel);
      await _ensureModel(_kHindiModel);
    } catch (e) {
      debugPrint('STTService: model download failed: $e');
      return false;
    }

    _isInitialized = true;
    debugPrint('STTService: initialized (Whisper Tiny)');
    return true;
  }

  Future<String> _modelsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/whisper_models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> _modelPath(_WhisperModel model) async {
    final dir = await _modelsDir();
    return '$dir/${model.filename}';
  }

  Future<void> _ensureModel(_WhisperModel model) async {
    final path = await _modelPath(model);
    if (await File(path).exists()) {
      debugPrint('STTService: model already cached: ${model.filename}');
      return;
    }

    debugPrint('STTService: downloading ${model.filename} …');
    downloadProgress.value = 0.0;

    final request = http.Request('GET', Uri.parse(model.url));
    final response = await request.send();

    if (response.statusCode != 200) {
      downloadProgress.value = null;
      throw Exception(
          'Failed to download ${model.filename}: HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    int received = 0;
    final sink = File(path).openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        downloadProgress.value = received / total;
      }
    }

    await sink.flush();
    await sink.close();
    downloadProgress.value = null;
    debugPrint('STTService: downloaded ${model.filename}');
  }

  Future<void> startListening({
    required Function(String) onResult,
    required String localeId,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isListening) return;

    _activeModel = localeId.startsWith('hi') ? _kHindiModel : _kEnglishModel;
    _onResult = onResult;

    final tmpDir = await getTemporaryDirectory();
    _currentAudioPath = '${tmpDir.path}/whisper_input.wav';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: _currentAudioPath!,
    );

    _isListening = true;
    debugPrint('STTService: recording started → $_currentAudioPath');
  }

  String? _currentLoadedModelPath;

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;

    final audioPath = await _recorder.stop();
    debugPrint('STTService: recording stopped → $audioPath');

    if (audioPath == null || _activeModel == null || _onResult == null) return;

    try {
      final modelPath = await _modelPath(_activeModel!);
      
      if (_currentLoadedModelPath != modelPath) {
         debugPrint('STTService: loading model $modelPath ...');
         final ok = await WhisperChannel.initWhisper(modelPath);
         if (!ok) {
           debugPrint('STTService: whisper init failed');
           _onResult!('');
           return;
         }
         _currentLoadedModelPath = modelPath;
      } else {
        debugPrint('STTService: model already loaded: $modelPath');
      }

      final text = await WhisperChannel.transcribe(audioPath, _activeModel!.language);
      debugPrint('STTService: transcription = "$text"');
      _onResult!(text);
    } catch (e) {
      debugPrint('STTService: transcription error: $e');
      _onResult!('');
    }
  }

  bool get isListening => _isListening;

  Future<bool> isLocaleAvailable(String localeId) async => true;

  Future<void> openOfflineLanguageSettings() async {}

  void dispose() {
    _recorder.dispose();
    WhisperChannel.freeWhisper();
    downloadProgress.dispose();
  }
}
