import 'package:flutter/services.dart';
import 'profanity_filter_data.dart';

/// バリデーションユーティリティクラス
/// 各種入力フィールドのバリデーションと正規表現パターンを提供
class ValidationUtil {
  // 正規表現パターン定義
  static final RegExp _nicknamePattern = RegExp(
    r'^[a-zA-Z0-9ぁ-んァ-ヶー一-龯々〆〤\s]{1,20}$',
    unicode: true,
  );
  
  static final RegExp _commentPattern = RegExp(
    r'''^[^<>&"'`]{0,20}$''',
    unicode: true,
  );
  
  static final RegExp _aiMemoryPattern = RegExp(
    r'''^[^<>&"'`]{0,400}$''',
    unicode: true,
  );
  
  // 包括的な不適切語句チェック
  static bool _containsProfanity(String text) {
    final normalizedText = _normalizeLeetSpeak(text.toLowerCase());
    
    // URL・リンクチェック
    for (final pattern in ProfanityFilterData.urlPatterns) {
      if (pattern.hasMatch(normalizedText)) return true;
    }
    
    // 英語不適切語句チェック
    for (final word in ProfanityFilterData.englishProfanity) {
      if (normalizedText.contains(word.toLowerCase())) return true;
    }
    
    // 日本語不適切語句チェック
    for (final word in ProfanityFilterData.japaneseProfanity) {
      if (normalizedText.contains(word)) return true;
    }
    
    // 特殊パターンチェック
    for (final pattern in ProfanityFilterData.obfuscationPatterns) {
      if (pattern.hasMatch(normalizedText)) return true;
    }
    
    // 危険なパターンチェック
    for (final pattern in ProfanityFilterData.dangerousPatterns) {
      if (pattern.hasMatch(text)) return true; // 大小文字保持
    }
    
    return false;
  }
  
  // リートスピーク正規化
  static String _normalizeLeetSpeak(String text) {
    String normalized = text;
    ProfanityFilterData.leetReplacements.forEach((key, value) {
      normalized = normalized.replaceAll(key, value);
    });
    return normalized;
  }
  
  // SQLインジェクション対策チェック
  static bool _containsSqlInjection(String text) {
    for (final pattern in ProfanityFilterData.sqlInjectionPatterns) {
      if (pattern.hasMatch(text)) return true;
    }
    return false;
  }
  
  // 空白のみのパターン
  static final RegExp _whitespaceOnlyPattern = RegExp(r'^\s*$');
  
  /// ニックネームのバリデーション
  static ValidationResult validateNickname(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationResult(false, 'ニックネームを入力してください');
    }
    
    if (_whitespaceOnlyPattern.hasMatch(value)) {
      return ValidationResult(false, 'ニックネームは空白のみにできません');
    }
    
    if (value.length > 20) {
      return ValidationResult(false, 'ニックネームは20文字以内で入力してください');
    }
    
    if (!_nicknamePattern.hasMatch(value)) {
      return ValidationResult(false, '使用できない文字が含まれています');
    }
    
    if (_containsProfanity(value)) {
      return ValidationResult(false, '不適切な内容が含まれています');
    }
    
    if (_containsSqlInjection(value)) {
      return ValidationResult(false, '使用できない文字列が含まれています');
    }
    
    return ValidationResult(true, null);
  }
  
  /// コメントのバリデーション
  static ValidationResult validateComment(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationResult(true, null); // コメントは任意
    }
    
    if (value.length > 20) {
      return ValidationResult(false, 'コメントは20文字以内で入力してください');
    }
    
    if (!_commentPattern.hasMatch(value)) {
      return ValidationResult(false, '使用できない文字が含まれています');
    }
    
    if (_containsProfanity(value)) {
      return ValidationResult(false, '不適切な内容が含まれています');
    }
    
    if (_containsSqlInjection(value)) {
      return ValidationResult(false, '使用できない文字列が含まれています');
    }
    
    return ValidationResult(true, null);
  }
  
  /// AIメモリのバリデーション
  static ValidationResult validateAiMemory(String? value) {
    if (value == null || value.isEmpty) {
      return ValidationResult(true, null); // AIメモリは任意
    }
    
    if (value.length > 400) {
      return ValidationResult(false, 'AIメモリは400文字以内で入力してください');
    }
    
    if (!_aiMemoryPattern.hasMatch(value)) {
      return ValidationResult(false, '使用できない文字が含まれています');
    }
    
    if (_containsProfanity(value)) {
      return ValidationResult(false, '不適切な内容が含まれています');
    }
    
    if (_containsSqlInjection(value)) {
      return ValidationResult(false, '使用できない文字列が含まれています');
    }
    
    return ValidationResult(true, null);
  }
  
  /// 入力値のサニタイズ（送信前の処理）
  static String sanitizeInput(String input) {
    // 前後の空白を削除
    String sanitized = input.trim();
    
    // 連続する空白を1つに変換
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    // HTMLエンティティのエスケープ
    sanitized = sanitized
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
    
    return sanitized;
  }
  
  /// 入力フィルター（リアルタイム入力制限）
  static List<TextInputFormatter> getNicknameFormatters() {
    return [
      LengthLimitingTextInputFormatter(20),
      // 特殊文字を除外するフィルター（日本語入力を阻害しないよう変更）
      FilteringTextInputFormatter.deny(RegExp(r'''[<>&"'`]''')),
    ];
  }
  
  static List<TextInputFormatter> getCommentFormatters() {
    return [
      LengthLimitingTextInputFormatter(20),
      // HTMLタグに使われる文字を除外
      FilteringTextInputFormatter.deny(RegExp(r'''[<>&"'`]''')),
    ];
  }
  
  static List<TextInputFormatter> getAiMemoryFormatters() {
    return [
      LengthLimitingTextInputFormatter(400),
      // HTMLタグに使われる文字を除外
      FilteringTextInputFormatter.deny(RegExp(r'''[<>&"'`]''')),
    ];
  }
}

/// バリデーション結果を表すクラス
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  
  ValidationResult(this.isValid, this.errorMessage);
}