import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_translator/models/translation_state.dart';
import 'package:speech_translator/providers/translator_provider.dart';
import 'package:speech_translator/services/translation_service.dart';
import 'package:speech_translator/widgets/mic_button.dart';
import 'package:speech_translator/widgets/translation_log.dart';

/// Main home screen for the speech-to-speech translator
/// Features: dark mode, centered mic button, language toggle, translation log
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize services when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TranslatorProvider>();
      provider.initialize();
      
      // Listen for Hindi unavailable error
      provider.addListener(() {
        if (provider.state.errorMessage == 'HINDI_UNAVAILABLE') {
          _showHindiUnavailableDialog();
          provider.clearError();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),  // Dark background
      body: SafeArea(
        child: Column(
          children: [
            // Header with title and language toggle
            _buildHeader(),
            
            // Translation log (scrollable)
            Expanded(
              child: Consumer<TranslatorProvider>(
                builder: (context, provider, child) {
                  return TranslationLog(history: provider.state.history);
                },
              ),
            ),
            
            // Microphone button and status
            _buildMicSection(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Build header with title and language toggle
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.translate,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Voice Translator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Language toggle
          Consumer<TranslatorProvider>(
            builder: (context, provider, child) {
              return _buildLanguageToggle(provider);
            },
          ),
          
          const SizedBox(height: 8),
          
          // Optimization badge
          _buildOptimizationBadge(),
        ],
      ),
    );
  }

  /// Build language toggle switch
  Widget _buildLanguageToggle(TranslatorProvider provider) {
    final isEnglishToHindi = provider.state.translationMode == TranslationMode.englishToHindi;
    
    return GestureDetector(
      onTap: () => provider.toggleTranslationMode(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF6366F1),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageLabel('English', isEnglishToHindi),
            const SizedBox(width: 12),
            Icon(
              Icons.swap_horiz,
              color: const Color(0xFF6366F1),
              size: 24,
            ),
            const SizedBox(width: 12),
            _buildLanguageLabel('हिन्दी', !isEnglishToHindi),
          ],
        ),
      ),
    );
  }

  /// Build language label with highlight
  Widget _buildLanguageLabel(String text, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              )
            : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey.shade400,
          fontSize: 16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  /// Build optimization badge
  Widget _buildOptimizationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF065F46),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.speed,
            color: Color(0xFF10B981),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'Powered by Arm NEON • LiteRT XNNPACK',
            style: TextStyle(
              color: const Color(0xFF10B981),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build microphone section with button and status
  Widget _buildMicSection() {
    return Consumer<TranslatorProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Status text
            _buildStatusText(provider.state),
            
            const SizedBox(height: 20),
            
            // Microphone button
            MicButton(
              state: provider.state.state,
              onPressed: () {
                if (provider.state.state == AppState.listening) {
                  provider.stopListening();
                } else {
                  provider.startTranslation();
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Error message if any
            if (provider.state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  provider.state.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build status text based on current state
  Widget _buildStatusText(TranslationState state) {
    String text;
    Color color;

    switch (state.state) {
      case AppState.idle:
        text = 'Tap to start speaking';
        color = Colors.grey.shade400;
        break;
      case AppState.listening:
        text = 'Listening... (tap to stop)';
        color = const Color(0xFFEF4444);
        break;
      case AppState.translating:
        text = 'Translating with Gemma...';
        color = const Color(0xFFF59E0B);
        break;
      case AppState.speaking:
        text = 'Speaking translation...';
        color = const Color(0xFF10B981);
        break;
      case AppState.error:
        text = 'Error occurred';
        color = const Color(0xFFEF4444);
        break;
    }

    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Show dialog when Hindi language pack is not available
  void _showHindiUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 12),
            Text(
              'Hindi Not Available',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hindi speech recognition is not available on your device.',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'To use Hindi → English translation, you need to:',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '1. Tap "Open Settings" below\n'
              '2. Find "Offline speech recognition"\n'
              '3. Download "Hindi" language pack',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TranslatorProvider>().openLanguageSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
            ),
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
