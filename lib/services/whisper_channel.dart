import 'package:flutter/services.dart';

/// Dart wrapper around the "com.armhack/whisper" MethodChannel.
/// Calls into WhisperBridge.kt → whisper_jni.cpp → libwhisper.so
class WhisperChannel {
  static const _channel = MethodChannel('com.armhack/whisper');

  /// Load a GGML model file into the native whisper context.
  /// [modelPath] must be an absolute path to a .bin file on device storage.
  /// Returns true on success.
  static Future<bool> initWhisper(String modelPath) async {
    final result = await _channel.invokeMethod<bool>(
      'initWhisper',
      {'modelPath': modelPath},
    );
    return result ?? false;
  }

  /// Transcribe a 16kHz mono WAV file.
  /// [audioPath] — absolute path to the recorded WAV file.
  /// [language]  — ISO 639-1 code: "en" for English, "hi" for Hindi.
  /// Returns the recognized text (may be empty on failure).
  static Future<String> transcribe(String audioPath, String language) async {
    final result = await _channel.invokeMethod<String>(
      'transcribe',
      {'audioPath': audioPath, 'language': language},
    );
    return result?.trim() ?? '';
  }

  /// Release the native whisper context and free memory.
  static Future<void> freeWhisper() async {
    await _channel.invokeMethod<void>('freeWhisper');
  }
}
