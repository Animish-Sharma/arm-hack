import 'package:speech_translator/services/translation_service.dart';

/// Represents the current state of the translation workflow
enum AppState {
  idle,           // Ready to start
  listening,      // Recording speech
  translating,    // Gemma is processing
  speaking,       // TTS is playing
  error,          // Error occurred
}

/// Represents a single translation entry in the history
class TranslationEntry {
  final String originalText;
  final String translatedText;
  final TranslationMode mode;
  final DateTime timestamp;

  TranslationEntry({
    required this.originalText,
    required this.translatedText,
    required this.mode,
    required this.timestamp,
  });

  /// Get formatted mode string for display
  String get modeString {
    switch (mode) {
      case TranslationMode.englishToHindi:
        return 'English → Hindi';
      case TranslationMode.hindiToEnglish:
        return 'Hindi → English';
    }
  }
}

/// Application state model
class TranslationState {
  final AppState state;
  final TranslationMode translationMode;
  final List<TranslationEntry> history;
  final String? errorMessage;

  TranslationState({
    this.state = AppState.idle,
    this.translationMode = TranslationMode.englishToHindi,
    this.history = const [],
    this.errorMessage,
  });

  TranslationState copyWith({
    AppState? state,
    TranslationMode? translationMode,
    List<TranslationEntry>? history,
    String? errorMessage,
  }) {
    return TranslationState(
      state: state ?? this.state,
      translationMode: translationMode ?? this.translationMode,
      history: history ?? this.history,
      errorMessage: errorMessage,
    );
  }
}
