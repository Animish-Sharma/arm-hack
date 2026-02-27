#include <jni.h>
#include <string>
#include <vector>
#include <cstring>
#include <android/log.h>
#include "whisper.h"

#define LOG_TAG "WhisperJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Global whisper context (one at a time)
static struct whisper_context* g_ctx = nullptr;

// ── Helper: read a 16-bit mono WAV file into float samples ─────────────────
// Whisper expects 32-bit float PCM at 16 kHz mono.
static bool read_wav(const char* path,
                     std::vector<float>& out_samples,
                     int& out_sample_rate) {
    FILE* f = fopen(path, "rb");
    if (!f) {
        LOGE("Cannot open WAV: %s", path);
        return false;
    }

    // Skip RIFF header (44 bytes standard WAV header)
    char header[44];
    if (fread(header, 1, 44, f) != 44) {
        LOGE("Failed to read WAV header");
        fclose(f);
        return false;
    }

    // Parse sample rate from header (bytes 24-27)
    out_sample_rate = *reinterpret_cast<int32_t*>(header + 24);

    // Read 16-bit PCM samples and convert to float
    std::vector<int16_t> raw;
    int16_t sample;
    while (fread(&sample, sizeof(int16_t), 1, f) == 1) {
        raw.push_back(sample);
    }
    fclose(f);

    out_samples.resize(raw.size());
    for (size_t i = 0; i < raw.size(); ++i) {
        out_samples[i] = static_cast<float>(raw[i]) / 32768.0f;
    }
    return true;
}

// ── JNI: nativeInitWhisper ─────────────────────────────────────────────────
extern "C" JNIEXPORT jboolean JNICALL
Java_com_armhack_speech_1translator_WhisperBridge_nativeInitWhisper(
        JNIEnv* env, jobject /* this */, jstring modelPath) {

    // Free any existing context
    if (g_ctx) {
        whisper_free(g_ctx);
        g_ctx = nullptr;
    }

    const char* path = env->GetStringUTFChars(modelPath, nullptr);
    LOGI("Loading whisper model: %s", path);

    // Use default params
    struct whisper_context_params cparams = whisper_context_default_params();
    g_ctx = whisper_init_from_file_with_params(path, cparams);
    
    env->ReleaseStringUTFChars(modelPath, path);

    if (!g_ctx) {
        LOGE("whisper_init_from_file_with_params failed");
        return JNI_FALSE;
    }
    LOGI("Whisper model loaded OK");
    return JNI_TRUE;
}

// ── JNI: nativeTranscribe ──────────────────────────────────────────────────
extern "C" JNIEXPORT jstring JNICALL
Java_com_armhack_speech_1translator_WhisperBridge_nativeTranscribe(
        JNIEnv* env, jobject /* this */, jstring audioPath, jstring language) {

    if (!g_ctx) {
        LOGE("Whisper context not initialized");
        return env->NewStringUTF("");
    }

    const char* wav_path = env->GetStringUTFChars(audioPath, nullptr);
    const char* lang     = env->GetStringUTFChars(language,  nullptr);

    std::vector<float> samples;
    int sample_rate = 0;
    bool ok = read_wav(wav_path, samples, sample_rate);
    env->ReleaseStringUTFChars(audioPath, wav_path);

    if (!ok || samples.empty()) {
        env->ReleaseStringUTFChars(language, lang);
        return env->NewStringUTF("");
    }

    // Configure whisper params
    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.language            = lang;
    params.translate           = false;
    params.no_context          = true;
    params.single_segment      = false;
    params.print_realtime      = false;
    params.print_progress      = false;
    params.print_timestamps    = false;
    params.print_special       = false;
    params.n_threads           = 4;

    int ret = whisper_full(g_ctx, params, samples.data(), (int)samples.size());
    env->ReleaseStringUTFChars(language, lang);

    if (ret != 0) {
        LOGE("whisper_full failed: %d", ret);
        return env->NewStringUTF("");
    }

    // Concatenate all segments
    std::string result;
    int n_segments = whisper_full_n_segments(g_ctx);
    for (int i = 0; i < n_segments; ++i) {
        const char* text = whisper_full_get_segment_text(g_ctx, i);
        if (text) result += text;
    }

    LOGI("Transcription: %s", result.c_str());
    return env->NewStringUTF(result.c_str());
}

// ── JNI: nativeFreeWhisper ─────────────────────────────────────────────────
extern "C" JNIEXPORT void JNICALL
Java_com_armhack_speech_1translator_WhisperBridge_nativeFreeWhisper(
        JNIEnv* /* env */, jobject /* this */) {
    if (g_ctx) {
        whisper_free(g_ctx);
        g_ctx = nullptr;
        LOGI("Whisper context freed");
    }
}
