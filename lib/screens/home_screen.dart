import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_translator/models/translation_state.dart';
import 'package:speech_translator/providers/translator_provider.dart';
import 'package:speech_translator/services/translation_service.dart';
import 'package:speech_translator/widgets/mic_button.dart';
import 'package:speech_translator/widgets/translation_log.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TranslatorProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),  // Dark background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            
            Expanded(
              child: Consumer<TranslatorProvider>(
                builder: (context, provider, child) {
                  return TranslationLog(history: provider.state.history);
                },
              ),
            ),
            
            _buildMicSection(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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
          
          Consumer<TranslatorProvider>(
            builder: (context, provider, child) {
              return _buildLanguageToggle(provider);
            },
          ),
          
          const SizedBox(height: 8),
          
          _buildOptimizationBadge(),
        ],
      ),
    );
  }

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
            _buildLanguageLabel('हिन्दी', !isEnglishToHindi),
            const SizedBox(width: 12),
            Icon(
              Icons.swap_horiz,
              color: const Color(0xFF6366F1),
              size: 24,
            ),
            const SizedBox(width: 12),
            _buildLanguageLabel('English', isEnglishToHindi),
          ],
        ),
      ),
    );
  }

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

  Widget _buildMicSection() {
    return Consumer<TranslatorProvider>(
      builder: (context, provider, child) {
        final progress = provider.downloadProgress;
        if (progress != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Column(
              children: [
                Text(
                  provider.loadingStatus,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF374151),
                  color: const Color(0xFF6366F1),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          );
        }

        if (provider.state.state == AppState.initializing) {
           return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Column(
              children: [
                const CircularProgressIndicator(color: Color(0xFF6366F1)),
                const SizedBox(height: 16),
                const Text(
                  'Loading Gemma & Whisper models...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                 Text(
                  'First run may take a few seconds',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildStatusText(provider.state),
            
            const SizedBox(height: 20),
            
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
      case AppState.initializing:
        text = 'Initializing...';
        color = Colors.grey.shade400;
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

}
