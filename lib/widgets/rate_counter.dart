import 'package:flutter/material.dart';

class RateCounter extends StatelessWidget {
  final int rate;
  final Animation<int>? countAnim;
  final double labelFontSize;
  final double valueFontSize;
  final String label;

  const RateCounter({
    super.key,
    this.rate = 0,
    this.countAnim,
    this.labelFontSize = 24.0,
    this.valueFontSize = 48.0,
    this.label = 'RATE',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: labelFontSize,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 8),
        if (countAnim != null)
          AnimatedBuilder(
            animation: countAnim!,
            builder: (context, child) => Text(
              '${countAnim!.value}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1E1E),
              ),
            ),
          )
        else
          Text(
            '$rate',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E1E1E),
            ),
          ),
      ],
    );
  }
}