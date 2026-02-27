import 'package:flutter/services.dart';

class WhisperChannel {
  static const _channel = MethodChannel('com.armhack/whisper');

  static Future<bool> initWhisper(String modelPath) async {
    final result = await _channel.invokeMethod<bool>(
      'initWhisper',
      {'modelPath': modelPath},
    );
    return result ?? false;
  }

  static Future<String> transcribe(String audioPath, String language) async {
    final result = await _channel.invokeMethod<String>(
      'transcribe',
      {'audioPath': audioPath, 'language': language},
    );
    return result?.trim() ?? '';
  }

  static Future<void> freeWhisper() async {
    await _channel.invokeMethod<void>('freeWhisper');
  }
}
