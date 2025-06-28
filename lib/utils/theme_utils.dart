import 'package:flutter/material.dart';

// テーマ用データクラス
class AppThemePalette {
  final Color backgroundColor;
  final Color barColor;
  final Color callIconColor;

  const AppThemePalette({
    required this.backgroundColor,
    required this.barColor,
    required this.callIconColor,
  });
}

// 基本パレット定義（透明度適用前）
final List<AppThemePalette> _baseAppThemes = [
  // 1. デフォルト（紫）
  const AppThemePalette(
    backgroundColor: Color(0xFF5A64ED),
    barColor: Color(0xFF979CDE),
    callIconColor: Color(0xFF4CAF50),
  ),
  // 2. E6D283, EAC77A, F59A3E
  const AppThemePalette(
    backgroundColor: Color(0xFFE6D283),
    barColor: Color(0xFFEAC77A),
    callIconColor: Color(0xFFF59A3E),
  ),
  // 3. A482E5, D7B3E8, D487E6
  const AppThemePalette(
    backgroundColor: Color(0xFFA482E5),
    barColor: Color(0xFFD7B3E8),
    callIconColor: Color(0xFFD487E6),
  ),
  // 4. 83C8E6, B8D8E6, 618DAA
  const AppThemePalette(
    backgroundColor: Color(0xFF83C8E6),
    barColor: Color(0xFFB8D8E6),
    callIconColor: Color(0xFF618DAA),
  ),
  // 5. F0941F, EF6024, 548AB6
  const AppThemePalette(
    backgroundColor: Color(0xFFF0941F),
    barColor: Color(0xFFEF6024),
    callIconColor: Color(0xFF548AB6),
  ),
];

// 紫系色の定義（透明化対象）
const Set<int> _purpleColors = {
  0xFF5A64ED, // デフォルト背景色
  0xFF979CDE, // デフォルトバー色
};

// 色が紫系かどうかを判定
bool _isPurpleColor(Color color) {
  // Using value property for compatibility
  // ignore: deprecated_member_use
  return _purpleColors.contains(color.value);
}

// 動的テーマ取得関数
AppThemePalette getAppTheme(int themeIndex) {
  // インデックスが範囲外の場合はデフォルト
  if (themeIndex < 0 || themeIndex >= _baseAppThemes.length) {
    themeIndex = 0;
  }
  
  final baseTheme = _baseAppThemes[themeIndex];
  
  // テーマインデックスが0の場合は通常の色を返す
  if (themeIndex == 0) {
    return baseTheme;
  }
  
  // テーマインデックスが0以外の場合、デフォルトの紫を透明にする
  return AppThemePalette(
    backgroundColor: _isPurpleColor(baseTheme.backgroundColor) 
        ? Colors.transparent 
        : baseTheme.backgroundColor,
    barColor: _isPurpleColor(baseTheme.barColor) 
        ? Colors.transparent 
        : baseTheme.barColor,
    callIconColor: baseTheme.callIconColor, // 通話アイコンはそのまま
  );
}

// テーマ選択用の基本パレット（透明化前の元の色）
final List<AppThemePalette> appThemesForSelection = _baseAppThemes;

// テーマ数を取得
int get themeCount => _baseAppThemes.length;

// 後方互換性のための静的リスト（非推奨）
@Deprecated('Use getAppTheme(int themeIndex) instead')
final List<AppThemePalette> appThemes = _baseAppThemes;