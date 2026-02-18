# Voice Translator - Arm Hack Project

A high-performance, privacy-focused **Speech-to-Speech Translator** for Android, powered by on-device AI.

This application leverages **Google Gemma** (via MediaPipe/LiteRT) for translation and **OpenAI Whisper** (via C++ JNI) for speech recognition, optimized specifically for **Arm® processors** using NEON™ SIMD instructions and the XNNPACK delegate.

## Key Features

-   **On-Device Translation**: No internet required for core functionality.
-   **Speech-to-Text (STT)**: Whisper Tiny model running via a custom C++ JNI bridge for low latency.
-   **Machine Translation (MT)**: Gemma-3 1B INT4 quantized model running on the GPU/CPU using LiteRT (MediaPipe).
-   **Text-to-Speech (TTS)**: Native Android TTS integration.
-   **Dual Mode**: English → Hindi and Hindi → English support.
-   **Performance Optimized**:
    -   **Arm NEON & XNNPACK**: Acceleration for heavy matrix operations.
    -   **Model Caching**: Whisper models kept in memory to eliminate loading latency between utterances.
    -   **Optimized Inference**: Tuned `topK` and `maxTokens` for faster, deterministic translation.

## User Interface

-   **Modern Dark UI**: Clean, distraction-free interface.
-   **Real-time Feedback**: Loading states, pulse animations during recording.
-   **Translation History**: Scrollable log of previous translations.
-   **Audio Feedback**: Automatically speaks out the translated text.

## Technology Stack

-   **Framework**: Flutter (Dart)
-   **Speech Recognition**: [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) (C++) integrated via JNI.
-   **LLM Inference**: [MediaPipe LLM Inference](https://developers.google.com/mediapipe/solutions/genai/llm_inference) (`flutter_gemma`).
-   **Text-to-Speech**: `flutter_tts` package.
-   **State Management**: `Provider` architecture.

## Performance Optimizations

1.  **Whisper Model Caching**: The application caches the loaded Whisper model in the C++ layer. The first recording incurs a model load cost, but subsequent recordings in the same language use the cached context, reducing **STT startup latency** significantly.
2.  **LiteRT Delegate**: Gemma runs using the LiteRT XNNPACK delegate, which utilizes Arm NEON instructions to speed up INT4 model inference.
3.  **App Profiling**: Built-in benchmarking logs track:
    -   STT Latency
    -   Translation Latency
    -   TTS Latency
    -   Total Pipeline Latency

## Setup & Installation

### Prerequisites
-   Flutter SDK (3.x+)
-   Android SDK & NDK (25.2+)
-   Physical Android Device (Emulator support is limited for GPU delegates)

### Instructions

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/yourusername/speech_translator.git
    cd speech_translator
    ```

2.  **Download Models**:
    -   **Gemma Model**: Download `gemma3-1b-it-int4.task` and place it in your device's `Download/` folder.
        -   *Note: The app expects the model at `/storage/emulated/0/Download/gemma3-1b-it-int4.task`.*
    -   **Whisper Models**: The app will automatically download `ggml-tiny-en-q4_0.bin` and `ggml-tiny-hindi-q4_0.bin` on first run.

3.  **Run the App**:
    ```bash
    flutter run --release
    ```
    *Using `--release` is recommended for accurate performance testing.*

## Project Structure

-   `android/app/src/main/cpp/`: Native C++ code for Whisper integration (`whisper_jni.cpp`, `whisper.h`).
-   `lib/services/`: Core logic services.
    -   `stt_service.dart`: Manages recording and Whisper JNI calls.
    -   `translation_service.dart`: Handles Gemma LLM inference.
    -   `tts_service.dart`: Manages Text-to-Speech.
-   `lib/providers/`: State management logic (`TranslatorProvider`).
-   `lib/ui/`: UI components and screens.

## Troubleshooting

-   **"No permissions found"**: Ensure you grant Microphone and Storage permissions when prompted.
-   **App Hangs on Initial Load**: The first run downloads ~70MB of Whisper models. Check your internet connection.
-   **Translation Hangs**: Ensure the Gemma model file exists in the correct path.