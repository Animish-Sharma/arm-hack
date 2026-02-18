package com.armhack.speech_translator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var whisperBridge: WhisperBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        whisperBridge = WhisperBridge(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        whisperBridge?.destroy()
        whisperBridge = null
        super.onDestroy()
    }
}
