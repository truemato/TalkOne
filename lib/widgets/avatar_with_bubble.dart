import 'package:flutter/material.dart';

class AvatarWithBubble extends StatelessWidget {
  final double outerSize;
  final double innerSize;
  final String? bubbleText;
  final double bubbleFontSize;
  final Animation<double>? pulseAnim;
  final Animation<Offset>? slideAnim;
  final Animation<double>? fadeAnim;

  const AvatarWithBubble({
    super.key,
    required this.outerSize,
    required this.innerSize,
    this.bubbleText,
    this.bubbleFontSize = 14.0,
    this.pulseAnim,
    this.slideAnim,
    this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: outerSize,
      height: outerSize + outerSize * 0.2,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (bubbleText != null && slideAnim != null && fadeAnim != null)
            Positioned(
              top: 0,
              right: outerSize * 0.1,
              child: SlideTransition(
                position: slideAnim!,
                child: FadeTransition(
                  opacity: fadeAnim!,
                  child: _buildSpeechBubble(),
                ),
              ),
            ),
          Positioned(
            top: outerSize * 0.08,
            child: pulseAnim != null
                ? AnimatedBuilder(
                    animation: pulseAnim!,
                    builder: (context, child) => Transform.scale(
                      scale: pulseAnim!.value,
                      child: child,
                    ),
                    child: _buildOuterCircle(),
                  )
                : _buildOuterCircle(),
          ),
          Positioned(
            top: outerSize * 0.08 + (outerSize - innerSize) / 2,
            left: (outerSize - innerSize) / 2,
            child: _buildInnerCircle(),
          ),
        ],
      ),
    );
  }

  Widget _buildOuterCircle() {
    return Container(
      width: outerSize,
      height: outerSize,
      decoration: const BoxDecoration(
        color: Color(0xFFC1BEE2),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildInnerCircle() {
    return Container(
      width: innerSize,
      height: innerSize,
      decoration: const BoxDecoration(
        color: Color(0xFFD9D9D9),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.person, size: 40, color: Colors.white),
      ),
    );
  }

  Widget _buildSpeechBubble() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F1F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            bubbleText!,
            style: TextStyle(
              color: const Color(0xFF1E1E1E),
              fontSize: bubbleFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(20, 10),
          painter: _TrianglePainter(const Color(0xFFF8F1F1)),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}