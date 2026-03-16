import 'package:flutter/material.dart';

/// A subtle, slow-moving animated mesh gradient background.
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
            gradient: LinearGradient(
              begin: Alignment(
                -1.0 + (_animation.value * 2),
                -1.0 + (_animation.value * 1.5),
              ),
              end: Alignment(
                1.0 - (_animation.value * 2),
                1.0 - (_animation.value * 1.5),
              ),
              colors: [
                const Color(0xFF111827), // Very dark gray
                Color.lerp(
                  const Color(0xFF1E1B4B), // Deep indigo
                  const Color(0xFF312E81), // Lighter indigo
                  _animation.value,
                )!,
                const Color(0xFF0F172A), // Dark slate
              ],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
