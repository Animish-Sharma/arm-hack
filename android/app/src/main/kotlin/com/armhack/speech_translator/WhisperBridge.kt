package com.armhack.speech_translator

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.*

/**
 * WhisperBridge: Kotlin JNI bridge to libwhisper.so
 *
 * Flutter MethodChannel: "com.armhack/whisper"
 * Methods:
 *   initWhisper(modelPath: String) → Boolean
 *   transcribe(audioPath: String, language: String) → String
 *   freeWhisper() → void
 */
class WhisperBridge(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "WhisperBridge"
        const val CHANNEL = "com.armhack/whisper"

        init {
            try {
                System.loadLibrary("ggml")
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "Could not load libggml.so explicitly: ${e.message}")
            }
            System.loadLibrary("whisper")
            System.loadLibrary("whisper_jni")
        }
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initWhisper" -> {
                val modelPath = call.argument<String>("modelPath") ?: run {
                    result.error("INVALID_ARGS", "modelPath is required", null)
                    return
                }
                scope.launch {
                    try {
                        val success = nativeInitWhisper(modelPath)
                        withContext(Dispatchers.Main) { result.success(success) }
                    } catch (e: Exception) {
                        Log.e(TAG, "initWhisper failed: ${e.message}")
                        withContext(Dispatchers.Main) {
                            result.error("INIT_FAILED", e.message, null)
                        }
                    }
                }
            }

            "transcribe" -> {
                val audioPath = call.argument<String>("audioPath") ?: run {
                    result.error("INVALID_ARGS", "audioPath is required", null)
                    return
                }
                val language = call.argument<String>("language") ?: "en"
                scope.launch {
                    try {
                        val text = nativeTranscribe(audioPath, language)
                        withContext(Dispatchers.Main) { result.success(text) }
                    } catch (e: Exception) {
                        Log.e(TAG, "transcribe failed: ${e.message}")
                        withContext(Dispatchers.Main) {
                            result.error("TRANSCRIBE_FAILED", e.message, null)
                        }
                    }
                }
            }

            "freeWhisper" -> {
                scope.launch {
                    try {
                        nativeFreeWhisper()
                        withContext(Dispatchers.Main) { result.success(null) }
                    } catch (e: Exception) {
                        Log.e(TAG, "freeWhisper failed: ${e.message}")
                        withContext(Dispatchers.Main) {
                            result.error("FREE_FAILED", e.message, null)
                        }
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    fun destroy() {
        scope.cancel()
        channel.setMethodCallHandler(null)
    }

    // ── JNI declarations (implemented in whisper_jni.cpp) ──────────────────

    /** Initialize whisper context from a GGML model file. Returns true on success. */
    private external fun nativeInitWhisper(modelPath: String): Boolean

    /** Transcribe a 16kHz mono WAV file. Returns the recognized text. */
    private external fun nativeTranscribe(audioPath: String, language: String): String

    /** Free the whisper context and release all native memory. */
    private external fun nativeFreeWhisper()
}
