import 'package:flutter/material.dart';

class AppAnimations {
  // Animation Curves
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.bounceOut;
  static const Curve elasticCurve = Curves.elasticOut;
  
  // Animation Durations
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 500);
  static const Duration longDuration = Duration(milliseconds: 1000);
  
  // Pulse Animation Configuration
  static const double pulseMinScale = 1.0;
  static const double pulseMaxScale = 1.1;
  
  // Slide Animation Configuration
  static const Offset slideStartOffset = Offset(0, 0.5);
  static const Offset slideEndOffset = Offset.zero;
  
  // Fade Animation Configuration
  static const double fadeStartOpacity = 0.0;
  static const double fadeEndOpacity = 1.0;
  
  // Button Press Animation
  static const double buttonPressScale = 0.95;
}