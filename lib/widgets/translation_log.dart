import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:speech_translator/models/translation_state.dart';
import 'package:intl/intl.dart';

/// Scrollable log displaying translation history
/// Shows original and translated text pairs with timestamps
class TranslationLog extends StatefulWidget {
  final List<TranslationEntry> history;

  const TranslationLog({super.key, required this.history});

  @override
  State<TranslationLog> createState() => _TranslationLogState();
}

class _TranslationLogState extends State<TranslationLog> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<TranslationEntry> _localHistory;

  @override
  void initState() {
    super.initState();
    _localHistory = List.from(widget.history);
  }

  @override
  void didUpdateWidget(TranslationLog oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check for new items added
    if (widget.history.length > oldWidget.history.length) {
      // Find the new items (assuming they are appended to the end)
      for (int i = oldWidget.history.length; i < widget.history.length; i++) {
        _localHistory.add(widget.history[i]);
        // Insert at the beginning of the list since we use reverse: true
        _listKey.currentState?.insertItem(
          0,
          duration: const Duration(milliseconds: 500),
        );
      }
    } else if (widget.history.length < oldWidget.history.length) {
      // Handle clear case
      final int removedCount = _localHistory.length;
      for (int i = removedCount - 1; i >= 0; i--) {
        final entry = _localHistory.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildItem(entry, animation),
          duration: const Duration(milliseconds: 300),
        );
      }
    }
  }

  Widget _buildItem(TranslationEntry entry, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TranslationCard(entry: entry),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_localHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1F2937).withOpacity(0.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.history_toggle_off,
                size: 64,
                color: const Color(0xFF6366F1).withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No translations yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your translation history will appear here.\nTap the microphone on the Home tab to start.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedList(
      key: _listKey,
      reverse: true, // Show latest at bottom
      padding: const EdgeInsets.all(16),
      initialItemCount: _localHistory.length,
      itemBuilder: (context, index, animation) {
        // Because it's reversed, index 0 is the newest item (at the end of the list)
        final entry = _localHistory[_localHistory.length - 1 - index];
        return _buildItem(entry, animation);
      },
    );
  }
}

/// Card displaying a single translation entry with glassmorphism
class TranslationCard extends StatefulWidget {
  final TranslationEntry entry;

  const TranslationCard({super.key, required this.entry});

  @override
  State<TranslationCard> createState() => _TranslationCardState();
}

class _TranslationCardState extends State<TranslationCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with mode and timestamp
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.entry.modeString,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          timeFormat.format(widget.entry.timestamp),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Original text
                    _TextSection(
                      label: 'Original',
                      text: widget.entry.originalText,
                      color: const Color(0xFF60A5FA), // Light blue
                    ),

                    const SizedBox(height: 12),

                    // Divider
                    Divider(color: Colors.white.withOpacity(0.1)),

                    const SizedBox(height: 12),

                    // Translated text
                    _TextSection(
                      label: 'Translated',
                      text: widget.entry.translatedText,
                      color: const Color(0xFF34D399), // Light green
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section showing labeled text
class _TextSection extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _TextSection({
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
