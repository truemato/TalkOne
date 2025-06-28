import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

// Triangle Painter for speech bubble pointer
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0)
          ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpeechBubble extends StatelessWidget {
  final String text;
  final double fontSize;

  const SpeechBubble({required this.text, required this.fontSize, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.bubblePaddingHorizontal,
            vertical: AppSizes.bubblePaddingVertical,
          ),
          decoration: BoxDecoration(
            color: AppColors.bubbleBackground,
            borderRadius: BorderRadius.circular(AppSizes.bubbleBorderRadius),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bubbleText(fontSize),
          ),
        ),
        const CustomPaint(
          size: Size(AppSizes.pointerWidth, AppSizes.pointerHeight),
          painter: _TrianglePainter(AppColors.bubbleBackground),
        ),
      ],
    );
  }
}
