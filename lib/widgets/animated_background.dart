import 'dart:math';
import 'package:flutter/material.dart';

/// An exotic AI-style flowing sweep gradient background.
class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              center: Alignment.center,
              transform: GradientRotation(_animation.value * 2 * pi),
              colors: const [
                Color(0xFF0F172A), // Slate
                Color(0xFF312E81), // Indigo
                Color(0xFF4C1D95), // Violet
                Color(0xFF1E1B4B), // Deep Purple
                Color(0xFF0F172A), // Slate
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
