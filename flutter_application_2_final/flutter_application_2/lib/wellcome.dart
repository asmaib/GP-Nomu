import 'dart:async';
import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'onboarding.dart'; 

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    // After 5 seconds, navigate to OnboardingScreen
    Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
  

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1) Main content (e.g., logo) in the center
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Image.asset(
                'assets/logo.png', 
                width: screenWidth * 0.5,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 2) Waves (from back to front)
          // Wave #1 (darkest, tallest)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300, // The tallest wave
            child: AnimatedWaveWidget(
              waveColor: const Color(0xFF86B291), // darkest green
              waveHeight: 25,   // amplitude
              speed: 4,         // wave cycle in seconds
              offset: 0.0,      
            ),
          ),
          // Wave #2 (next darkest, slightly shorter)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 260,
            child: AnimatedWaveWidget(
              waveColor: const Color(0xFFAACFB3),
              waveHeight: 25,
              speed: 3,
              offset: math.pi / 2,
            ),
          ),
          // Wave #3 (lighter, shorter)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 220,
            child: AnimatedWaveWidget(
              waveColor: const Color(0xFFD2E8D9),
              waveHeight: 25,
              speed: 3,
              offset: math.pi,
            ),
          ),
          // Wave #4 (lightest, shortest)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 165,
            child: AnimatedWaveWidget(
              waveColor: const Color(0xFFE7EFE8),
              waveHeight: 25,
              speed: 2,
              offset: 3 * math.pi / 2,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// AnimatedWaveWidget: draws and animates a single sine wave
// -------------------------------------------------------------------
class AnimatedWaveWidget extends StatefulWidget {
  final Color waveColor;
  final double waveHeight;  // amplitude of the wave
  final double speed;       // duration (in seconds) for one wave cycle
  final double offset;      // phase offset for multiple waves

  const AnimatedWaveWidget({
    Key? key,
    required this.waveColor,
    this.waveHeight = 20.0,
    this.speed = 2.0,
    this.offset = 0.0,
  }) : super(key: key);

  @override
  _AnimatedWaveWidgetState createState() => _AnimatedWaveWidgetState();
}

class _AnimatedWaveWidgetState extends State<AnimatedWaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Repeat the animation forever
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.speed.toInt()),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds when _controller updates
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          painter: _WavePainter(
            animationValue: _controller.value,
            waveColor: widget.waveColor,
            waveHeight: widget.waveHeight,
            offset: widget.offset,
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------------
// _WavePainter: custom painter that draws a single sine wave
// -------------------------------------------------------------------
class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color waveColor;
  final double waveHeight;
  final double offset;

  _WavePainter({
    required this.animationValue,
    required this.waveColor,
    required this.waveHeight,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = waveColor;
    final path = Path();

    final double fullCycle = size.width;
    final double centerY = size.height / 2;

    // Start at the bottom-left
    path.moveTo(0, size.height);

    // Draw the sine wave from left to right
    for (double x = 0; x <= size.width; x++) {
      final double y = centerY +
          waveHeight *
              math.sin(
                (2 * math.pi * (x / fullCycle))    // wave frequency
                - (animationValue * 2 * math.pi)   // horizontal shift
                - offset,                          // phase offset
              );
      path.lineTo(x, y);
    }

    // Then close off at bottom-right
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
