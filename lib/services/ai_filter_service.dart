// AI機能無効化のためAIフィルターサービス全体をコメントアウト
/*
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

class AIFilterService {
  static const MethodChannel _channel = MethodChannel('com.talkone.app/ai_filter');
  
  static AIFilterService? _instance;
  
  factory AIFilterService() {
    _instance ??= AIFilterService._internal();
    return _instance!;
  }
  
  AIFilterService._internal();
  
  bool _isInitialized = false;
  bool _isEnabled = false;
  
  // Filter parameters
  int threshold1 = 100;
  int threshold2 = 200;
  bool enableColorful = true;
  
  bool get isEnabled => _isEnabled;
  
  /// Initialize the AI filter service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _channel.invokeMethod('initializeAIFilter');
      _isInitialized = true;
      print('AI filter initialized on ${Platform.isAndroid ? 'Android' : 'iOS'}');
    } catch (e) {
      print('Failed to initialize AI filter on ${Platform.operatingSystem}: $e');
    }
  }
  
  /// Enable or disable the AI filter
  Future<void> setEnabled(bool enabled) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      await _channel.invokeMethod('enableAIFilter', {'enabled': enabled});
      _isEnabled = enabled;
    } catch (e) {
      print('Failed to set AI filter enabled state: $e');
    }
  }
  
  /// Update filter parameters
  Future<void> updateFilterParams({
    int? threshold1,
    int? threshold2,
    bool? colorful,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (threshold1 != null) this.threshold1 = threshold1;
    if (threshold2 != null) this.threshold2 = threshold2;
    if (colorful != null) this.enableColorful = colorful;
    
    try {
      await _channel.invokeMethod('setFilterParams', {
        'threshold1': this.threshold1,
        'threshold2': this.threshold2,
        'colorful': this.enableColorful,
      });
    } catch (e) {
      print('Failed to update filter params: $e');
    }
  }
  
  /// Release resources
  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      await _channel.invokeMethod('releaseAIFilter');
      _isInitialized = false;
      _isEnabled = false;
    } catch (e) {
      print('Failed to release AI filter: $e');
    }
  }
  
  /// Check if user has access to AI filter (amenity feature)
  bool hasAccess(double userRating) {
    // AI filter available for rating 4.0+ or for privacy mode
    return userRating >= 4.0;
  }
  
  /// Force enable for privacy mode (always hide face)
  bool get isPrivacyRequired => false; // Only for privacy mode calls
}
*/