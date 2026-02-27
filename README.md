# Voice Translator - Arm Hack Project

- Project for the BharatSoc Hackathon by [Animish Sharma](https://github.com/Animish-Sharma) (CSTAR), [Ashirbard Sahu](https://github.com/ashirbadsahu) (CVEST) and [Divyansh Atri](https://github.com/Divyansh-Atri) (CCNSB) under the guidance of [Prof. Priyesh Shukla](https://www.iiit.ac.in/faculty/priyesh-shukla/) (CVEST)
 <hr/>
A high-performance, privacy-focused **Speech-to-Speech Translator** for Android, powered by on-device AI, leveraging Arm Neon.

App is only for android devices with armv8 architecture.

This application leverages **Google Gemma** (via MediaPipe/LiteRT) for translation and **OpenAI Whisper** (via C++ JNI) for speech recognition, optimized specifically for **Arm® processors** using NEON™ SIMD instructions and the XNNPACK delegate.

## Key Features

-   **On-Device Translation**: No internet required for core functionality(internet is required for first time use to download models).
-   **Speech-to-Text (STT)**: Whisper Tiny model running via a custom C++ JNI bridge for low latency.
-   **Machine Translation (MT)**: Gemma-3 1B INT4 quantized model running on the GPU/CPU using LiteRT (MediaPipe).
-   **Text-to-Speech (TTS)**: Native Android TTS integration.
-   **Dual Mode**: English → Hindi and Hindi → English support.
-   **Performance Optimized**:
    -   **Arm NEON & XNNPACK**: Acceleration for heavy matrix operations.
    -   **Model Caching**: Whisper models kept in memory to eliminate loading latency between utterances.
    -   **Optimized Inference**: Reduced `maxTokens` to 512 and tuned `topK` for faster, deterministic translation.

## User Interface

-   **Modern Dark UI**: Clean, distraction-free interface.
-   **Real-time Feedback**: Loading states, pulse animations during recording.
-   **Translation History**: Scrollable log of previous translations.
-   **Audio Feedback**: Automatically speaks out the translated text.

## Technology Stack

-   **Framework**: Flutter (Dart)
-   **Speech Recognition**: [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) (C++) integrated via JNI.
-   **LLM Inference**: [MediaPipe LLM Inference](https://developers.google.com/mediapipe/solutions/genai/llm_inference) (`flutter_gemma`).
-   **Text-to-Speech**: `flutter_tts` package leveraging native Android TTS.
-   **State Management**: `Provider` architecture.

## Performance Optimizations

1.  **Whisper Model Caching**: The application caches the loaded Whisper model in the C++ layer. The first recording incurs a model load cost, but subsequent recordings in the same language use the cached context, reducing **STT startup latency** significantly.
2.  **LiteRT Delegate**: Gemma runs using the LiteRT XNNPACK delegate, which utilizes Arm NEON instructions to speed up INT4 model inference.
3.  **App Profiling**: Built-in benchmarking logs track:
    -   STT Latency
    -   Translation Latency
    -   TTS Latency
    -   Total Pipeline Latency

## Benchmarking Tool

To capture real-time performance metrics (STT, Translation, TTS latencies) to a CSV file on your host computer:

1.  **Connect your device** via USB and ensure ADB is authorized.
2.  **Run the logger script** (requires Python 3):
    ```bash
    python benchmark_logger.py
    ```
3.  **Use the App**: Perform translations. The script will automatically detect the logs and append them to `benchmark_results.csv`.

## Detailed Documentation

For a deeper dive into the engineering decisions and performance of this application, please review the following documents:

*   [System Architecture & Data Flow](docs/ARCHITECTURE.md): Details the internal pipeline and the specific model choices (Gemma INT4, Whisper Q4_0).
*   [Benchmarking & Performance](docs/BENCHMARKS.md): Explains the built-in tracing tools and how Arm NEON/XNNPACK optimizations yield low-latency inference.
*   [Technical Challenges & Solutions](docs/CHALLENGES.md): Covers how we resolved LLM hallucinations, mitigated C++ context cold starts, and managed asynchronous JNI states.

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
    -   **Automatic Download**: The app will automatically download the necessary models on the first run:
        -   **Gemma Model**: `gemma3-1b-it-int4.task` (~1GB)
        -   **Whisper Models**: `ggml-tiny-en-q4_0.bin` and `ggml-tiny-hindi-q4_0.bin`
    -   *Note: Please ensure you have a stable internet connection for the first launch.*

3.  **Run the App**:
    ```bash
    flutter run --release
    ```
    *Using `--release` is recommended for accurate performance testing.*

## Project Structure

-   `android/app/src/main/cpp/`: Native C++ code for Whisper integration (`whisper_jni.cpp`, `whisper.h`).
-   `lib/services/`: Core logic services.
    -   `stt_service.dart`: Manages recording and Whisper JNI calls.
    -   `translation_service.dart`: Handles Gemma LLM inference (automatic model download & INT4 inference).
    -   `tts_service.dart`: Manages Text-to-Speech.
-   `lib/providers/`: State management logic (`TranslatorProvider`).
-   `lib/ui/`: UI components and screens.

## Troubleshooting

-   **"No permissions found"**: Ensure you grant Microphone and Storage permissions when prompted.
-   **App Hangs on Initial Load**: The first run downloads large model files (Gemma ~1GB, Whisper ~70MB). Check your internet connection and wait for the loading spinner to complete.
-   **Translation Hangs**: If the download was interrupted, clear the app data to force a re-download.