import 'package:flutter/material.dart';
import 'package:speech_translator/models/translation_state.dart';

/// Animated microphone button with visual feedback
/// Shows different states: idle, listening, processing
class MicButton extends StatefulWidget {
  final AppState state;
  final VoidCallback onPressed;

  const MicButton({
    super.key,
    required this.state,
    required this.onPressed,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with TickerProviderStateMixin {
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    
    // Create ripple animation for listening/processing state
    _rippleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
    );

    if (_shouldAnimate(widget.state)) {
      _rippleController.repeat();
    }
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate(widget.state) && !_shouldAnimate(oldWidget.state)) {
      _rippleController.repeat();
    } else if (!_shouldAnimate(widget.state) && _shouldAnimate(oldWidget.state)) {
      _rippleController.stop();
      _rippleController.value = 0.0;
    }
  }

  bool _shouldAnimate(AppState state) {
    return state == AppState.listening || 
           state == AppState.translating ||
           state == AppState.speaking;
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  Widget _buildRipple(double delay, Color color) {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        // Calculate the current value with delay
        double value = (_rippleController.value + delay) % 1.0;
        
        return Opacity(
          opacity: (1.0 - value).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1.0 + (value * 0.8), // Scale up to 1.8x
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.5),
                  width: 3.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    
    return GestureDetector(
      onTap: widget.state == AppState.idle || widget.state == AppState.listening 
          ? widget.onPressed 
          : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ripples
          if (_shouldAnimate(widget.state)) ...[
            _buildRipple(0.0, color),
            _buildRipple(0.33, color),
            _buildRipple(0.66, color),
          ],
          
          // Main Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _getGradient(color),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: _shouldAnimate(widget.state) ? 25 : 10,
                  spreadRadius: _shouldAnimate(widget.state) ? 8 : 2,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                _getIcon(),
                key: ValueKey(_getIcon()),
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get icon based on current state
  IconData _getIcon() {
    switch (widget.state) {
      case AppState.idle:
        return Icons.mic;
      case AppState.listening:
        return Icons.stop;  // Show stop icon to indicate tap will stop
      case AppState.translating:
        return Icons.translate;
      case AppState.speaking:
        return Icons.volume_up;
      case AppState.error:
        return Icons.error;
      case AppState.initializing:
        return Icons.hourglass_empty;
    }
  }

  /// Get color based on current state
  Color _getColor() {
    switch (widget.state) {
      case AppState.idle:
        return const Color(0xFF6366F1);  // Indigo
      case AppState.listening:
        return const Color(0xFFEF4444);  // Red (recording)
      case AppState.translating:
        return const Color(0xFFF59E0B);  // Amber (processing)
      case AppState.speaking:
        return const Color(0xFF10B981);  // Green (speaking)
      case AppState.error:
        return const Color(0xFFDC2626);  // Dark red
      case AppState.initializing:
        return Colors.grey;
    }
  }

  /// Get gradient based on current state
  LinearGradient _getGradient(Color color) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color,
        Color.lerp(color, Colors.black, 0.3)!,
      ],
    );
  }
}
