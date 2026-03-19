import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_translator/providers/translator_provider.dart';
import 'package:speech_translator/widgets/translation_log.dart';
import 'package:speech_translator/widgets/animated_background.dart';
import 'package:speech_translator/services/translation_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Let AnimatedBackground show through
        body: AnimatedBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Consumer<TranslatorProvider>(
                    builder: (context, provider, child) {
                      final history = provider.state.history;
                      final engToHin = history.where((e) => e.mode == TranslationMode.englishToHindi).toList();
                      final hinToEng = history.where((e) => e.mode == TranslationMode.hindiToEnglish).toList();

                      return TabBarView(
                        children: [
                          TranslationLog(history: engToHin),
                          TranslationLog(history: hinToEng),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withOpacity(0.5),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.history,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _showClearHistoryDialog(context);
                      },
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.white70,
                      tooltip: 'Clear History',
                    ),
                  ],
                ),
              ),
              TabBar(
                indicatorColor: const Color(0xFF6366F1),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.5),
                tabs: const [
                  Tab(text: 'English → Hindi'),
                  Tab(text: 'Hindi → English'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text('Clear History', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to clear your translation history? This cannot be undone.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                context.read<TranslatorProvider>().clearHistory();
                Navigator.of(context).pop();
              },
              child: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444))),
            ),
          ],
        );
      },
    );
  }
}
