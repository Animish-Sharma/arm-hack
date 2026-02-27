# Benchmarking & Performance

This document details the benchmarking methodology used to evaluate the performance of the Voice Translator application and the metrics achieved through on-device optimizations.

## What is Benchmarked?

The application actively measures and logs the following metrics for every translation turn:

*   **STT Latency (ms):** Time taken by the Whisper C++ engine to transcribe the recorded audio into text.
*   **Translation Latency (ms):** Time taken by the Gemma 1B INT4 model to generate the translated text.
*   **TTS Latency (ms):** Time taken by the native Android TTS engine to synthesize and complete speaking the translation.
*   **Total Pipeline Latency (ms):** The end-to-end turnaround time from the moment the user stops speaking to the end of the translated audio playback.
*   **LLM Tokens Per Second (TPS):** Estimated generation speed of the Gemma model during the translation phase.
*   **CPU Usage (%):** The peak CPU utilization of the application process during the translation pipeline.
*   **Memory Usage (MB):** The Total PSS (Proportional Set Size) memory footprint of the application.

## How it is Benchmarked

The application includes built-in telemetry in the `TranslatorProvider` that records millisecond-level timestamps for each stage. These metrics are formatted as JSON and output to the Android Logcat under the `flutter` tag with a specific `BENCHMARK_DATA:` prefix.

To automate the collection and include system-level metrics, we use a companion Python script (`benchmark_logger.py`):
1.  **Logcat Parsing:** The script continuously reads the `adb logcat` stream to extract the JSON payloads containing latencies and TPS.
2.  **System Polling:** A background thread in the script continuously polls `adb shell dumpsys cpuinfo` and `adb shell dumpsys meminfo` to monitor the app's real-time CPU and Memory utilization.
3.  **Data Aggregation:** The script merges the application-level latencies with the system-level resource metrics and appends them as a new row in `benchmark_results.csv`.

## Performance Metrics (Sample Results)

Based on recent comprehensive testing on an Arm v8 device, the application achieved the following average performance metrics for an end-to-end translation pipeline:

| Metric | Measured Average |
| :--- | :--- |
| **STT Engine Time (Whisper Tiny)** | ~4,800 ms |
| **Translation Time (Gemma 1B)** | ~3,800 ms |
| **TTS Synthesis Time** | ~1,900 ms |
| **Total Turnaround Time** | **~10.5 seconds** |
| **LLM Generation Speed** | **~1.1 Tokens / Second** |
| **Peak Memory Usage (RAM)** | **~1,350 MB** |

### Optimization Impact
The application maintains a low memory footprint (~1.35GB) despite running two complex neural networks (Whisper and Gemma 1B) locally. This is primarily due to the **INT4 Quantization** of the models. Furthermore, leveraging the **LiteRT XNNPACK delegate with Arm NEON instructions** allows the Gemma model to achieve a consistent token generation rate on edge devices without relying on cloud APIs.
