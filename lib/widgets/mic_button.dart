import 'package:flutter/material.dart';
import 'package:speech_translator/models/translation_state.dart';

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

class _MicButtonState extends State<MicButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.state == AppState.listening || 
                          widget.state == AppState.translating ||
                          widget.state == AppState.speaking;

    return GestureDetector(
      onTap: widget.state == AppState.idle || widget.state == AppState.listening 
          ? widget.onPressed 
          : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = isActive ? _pulseAnimation.value : 1.0;
          
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _getGradient(),
                boxShadow: [
                  BoxShadow(
                    color: _getColor().withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _getIcon(),
                size: 50,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIcon() {
    switch (widget.state) {
      case AppState.idle:
        return Icons.mic;
      case AppState.listening:
        return Icons.stop;
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

  Color _getColor() {
    switch (widget.state) {
      case AppState.idle:
        return const Color(0xFF6366F1);
      case AppState.listening:
        return const Color(0xFFEF4444);
      case AppState.translating:
        return const Color(0xFFF59E0B);
      case AppState.speaking:
        return const Color(0xFF10B981);
      case AppState.error:
        return const Color(0xFFDC2626);
      case AppState.initializing:
        return Colors.grey;
    }
  }

  LinearGradient _getGradient() {
    final color = _getColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color,
        color.withOpacity(0.7),
      ],
    );
  }
}
