import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'whisper_channel.dart';

/// Whisper model info
class _WhisperModel {
  final String filename;
  final String url;
  final String language; // ISO 639-1 code for whisper ("en" or "hi")

  const _WhisperModel({
    required this.filename,
    required this.url,
    required this.language,
  });
}

/// Available Whisper models.
/// English model → used when source language is English (en→hi mode).
/// Hindi model   → used when source language is Hindi   (hi→en mode).
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

/// STT service backed by Whisper Tiny via libwhisper.so JNI bridge.
///
/// Flow:
///   1. [initialize] — request mic permission, ensure model files are present
///      (download from HuggingFace if missing).
///   2. [startListening] — begin recording 16kHz mono WAV to a temp file.
///   3. [stopListening]  — stop recording, run Whisper transcription,
///      deliver result via [onResult] callback.
///
/// Language selection:
///   localeId "en_US" → English model (ggml-tiny-en-q4_0.bin)
///   localeId "hi_IN" → Hindi model   (ggml-tiny-hindi-q4_0.bin)
class STTService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isInitialized = false;
  bool _isListening = false;
  String? _currentAudioPath;
  Function(String)? _onResult;
  _WhisperModel? _activeModel;

  // Download progress callback (0.0 – 1.0), null when not downloading
  ValueNotifier<double?> downloadProgress = ValueNotifier(null);

  // ── Initialization ────────────────────────────────────────────────────────

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('STTService: microphone permission denied');
      return false;
    }

    // Ensure both model files are present (download if missing)
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

  // ── Model management ──────────────────────────────────────────────────────

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

  // ── Recording & transcription ─────────────────────────────────────────────

  /// Start recording microphone audio.
  /// [localeId] — "en_US" for English model, "hi_IN" for Hindi model.
  /// [onResult] — called with the transcribed text when [stopListening] is invoked.
  Future<void> startListening({
    required Function(String) onResult,
    required String localeId,
  }) async {
    if (!_isInitialized) await initialize();
    if (_isListening) return;

    // Select the correct model for the source language
    _activeModel = localeId.startsWith('hi') ? _kHindiModel : _kEnglishModel;
    _onResult = onResult;

    // Temp WAV file for this recording session
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

  /// Stop recording and run Whisper transcription.
  /// The result is delivered via the [onResult] callback passed to [startListening].
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;

    final audioPath = await _recorder.stop();
    debugPrint('STTService: recording stopped → $audioPath');

    if (audioPath == null || _activeModel == null || _onResult == null) return;

    try {
      // Load the correct model (re-init only if model changed)
      final modelPath = await _modelPath(_activeModel!);
      final ok = await WhisperChannel.initWhisper(modelPath);
      if (!ok) {
        debugPrint('STTService: whisper init failed');
        _onResult!('');
        return;
      }

      final text = await WhisperChannel.transcribe(audioPath, _activeModel!.language);
      debugPrint('STTService: transcription = "$text"');
      _onResult!(text);
    } catch (e) {
      debugPrint('STTService: transcription error: $e');
      _onResult!('');
    }
  }

  // ── Compatibility helpers (used by TranslatorProvider) ────────────────────

  bool get isListening => _isListening;

  /// Whisper handles both languages natively — always returns true.
  Future<bool> isLocaleAvailable(String localeId) async => true;

  /// No-op: Whisper doesn't need system language settings.
  Future<void> openOfflineLanguageSettings() async {}

  void dispose() {
    _recorder.dispose();
    WhisperChannel.freeWhisper();
    downloadProgress.dispose();
  }
}
