import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName = 'TalkOne';
  static const String appVersion = '1.0.0';
  
  // Time Constants
  static const int callDurationSeconds = 180; // 3 minutes
  static const int matchingTimeoutSeconds = 30;
  static const int matchingRangeExpansionInterval = 10;
  
  // Rating Constants
  static const double defaultRating = 3.0;
  static const double minRating = 1.0;
  static const double maxRating = 5.0;
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  
  // Animation Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);
}

class AppTextStyles {
  static TextStyle titleText(double fontSize) => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF4E3B7A),
  );
  
  static TextStyle bubbleText(double fontSize) => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF1E1E1E),
  );
  
  static TextStyle rateLabel(double fontSize) => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
    color: const Color(0xFF1E1E1E),
  );
  
  static TextStyle rateValue(double fontSize) => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF1E1E1E),
  );
}