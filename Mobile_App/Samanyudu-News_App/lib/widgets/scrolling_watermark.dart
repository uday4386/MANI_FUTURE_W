import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScrollingWatermark extends StatefulWidget {
  const ScrollingWatermark({super.key});

  @override
  State<ScrollingWatermark> createState() => _ScrollingWatermarkState();
}

class _ScrollingWatermarkState extends State<ScrollingWatermark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    width - (_controller.value * (width + 150)),
                    0,
                  ),
                  child: child,
                );
              },
              child: Container(
                height: 20,
                alignment: Alignment.centerLeft,
                // Removed white background and shadow to make it completely transparent
                child: Opacity(
                  opacity: 0.95, // slight transparency so it blends into the video naturally
                  child: Image.asset(
                    'assets/app_logo_new.png',
                    height: 14, // Even smaller size
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
