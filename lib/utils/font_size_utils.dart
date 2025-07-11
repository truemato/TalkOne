import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// フォントサイズ調整ユーティリティ
/// 
/// iPad SDKからiPhone SDKに変更した際のフォントはみ出し問題を解決するため、
/// 一律でフォントサイズを調整するシステムです。
class FontSizeUtils {
  // フォントサイズ調整値（px）
  static const double _fontSizeReduction = 3.0;
  
  /// 調整されたフォントサイズを取得
  /// 
  /// [originalSize] 元のフォントサイズ
  /// [minSize] 最小フォントサイズ（デフォルト: 10.0）
  static double getAdjustedFontSize(double originalSize, {double minSize = 10.0}) {
    final adjustedSize = originalSize - _fontSizeReduction;
    return adjustedSize < minSize ? minSize : adjustedSize;
  }
  
  /// Google Fonts Noto Sans（調整済み）
  static TextStyle notoSans({
    required double fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    double minSize = 10.0,
  }) {
    return GoogleFonts.notoSans(
      fontSize: getAdjustedFontSize(fontSize, minSize: minSize),
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }
  
  /// Google Fonts Catamaran（調整済み）
  static TextStyle catamaran({
    required double fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    double minSize = 10.0,
  }) {
    return GoogleFonts.catamaran(
      fontSize: getAdjustedFontSize(fontSize, minSize: minSize),
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }
  
  /// Google Fonts Caveat（調整済み）
  static TextStyle caveat({
    required double fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    double minSize = 10.0,
  }) {
    return GoogleFonts.caveat(
      fontSize: getAdjustedFontSize(fontSize, minSize: minSize),
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }
  
  /// 標準TextStyle（調整済み）
  static TextStyle standard({
    required double fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    double minSize = 10.0,
  }) {
    return TextStyle(
      fontSize: getAdjustedFontSize(fontSize, minSize: minSize),
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }
  
  /// 調整値を変更するメソッド（デバッグ用）
  static double _customReduction = _fontSizeReduction;
  
  static void setCustomReduction(double reduction) {
    _customReduction = reduction;
  }
  
  /// カスタム調整値でのフォントサイズ取得
  static double getCustomAdjustedFontSize(double originalSize, {double minSize = 10.0}) {
    final adjustedSize = originalSize - _customReduction;
    return adjustedSize < minSize ? minSize : adjustedSize;
  }
  
  /// デバッグ情報表示
  static void printFontAdjustment(double originalSize) {
    final adjustedSize = getAdjustedFontSize(originalSize);
    print('Font Size Adjustment: $originalSize → $adjustedSize (reduction: $_fontSizeReduction)');
  }
}

/// FontSizeUtilsの短縮版
class F {
  /// 調整されたフォントサイズ
  static double size(double originalSize, {double minSize = 10.0}) =>
      FontSizeUtils.getAdjustedFontSize(originalSize, minSize: minSize);
  
  /// Noto Sans（短縮版）
  static TextStyle noto({
    required double fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    double minSize = 10.0,
  }) => FontSizeUtils.notoSans(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
    minSize: minSize,
  );
  
  /// Catamaran（短縮版）
  static TextStyle cata({
    required double fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    double minSize = 10.0,
  }) => FontSizeUtils.catamaran(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
    minSize: minSize,
  );
  
  /// Caveat（短縮版）
  static TextStyle caveat({
    required double fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    double minSize = 10.0,
  }) => FontSizeUtils.caveat(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
    minSize: minSize,
  );
}