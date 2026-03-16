import 'dart:math';
import 'package:flutter/material.dart';

/// A dynamic animated audio wave visualizer
class AudioWave extends StatefulWidget {
  final bool isAnimating;
  final Color color;
  final double height;
  final int barCount;

  const AudioWave({
    super.key,
    this.isAnimating = false,
    this.color = const Color(0xFF6366F1),
    this.height = 40.0,
    this.barCount = 15,
  });

  @override
  State<AudioWave> createState() => _AudioWaveState();
}

class _AudioWaveState extends State<AudioWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _controller.repeat();
      } else {
        _controller.animateTo(0, duration: const Duration(milliseconds: 300));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (index) {
              // Calculate a pseudo-random height based on time and index to make waves
              final double phase = (index / widget.barCount) * 2 * pi;
              final double amplitude = widget.isAnimating 
                  ? (sin((_controller.value * 2 * pi) + phase) + 1) / 2 
                  : 0.1;
              
              // Make middle bars taller
              final double heightMultiplier = 1.0 - (2 * (index / (widget.barCount - 1) - 0.5)).abs();

              final double barHeight = max(
                widget.height * 0.1, 
                widget.height * amplitude * heightMultiplier
              );

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 4,
                height: barHeight,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.isAnimating ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ] : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
