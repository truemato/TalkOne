import 'package:flutter/services.dart';

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
  
  // 禁止ワードパターン（基本的な不適切な単語）
  static final RegExp _inappropriatePattern = RegExp(
    r'(死ね|殺す|バカ|アホ|クソ|fuck|shit|damn)',
    caseSensitive: false,
  );
  
  // SQLインジェクション対策パターン
  static final RegExp _sqlInjectionPattern = RegExp(
    r"(';|--;|\/\*|\*\/|xp_|sp_|<script|<\/script|javascript:|onerror=|onload=)",
    caseSensitive: false,
  );
  
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
    
    if (_inappropriatePattern.hasMatch(value)) {
      return ValidationResult(false, '不適切な言葉が含まれています');
    }
    
    if (_sqlInjectionPattern.hasMatch(value)) {
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
    
    if (_inappropriatePattern.hasMatch(value)) {
      return ValidationResult(false, '不適切な言葉が含まれています');
    }
    
    if (_sqlInjectionPattern.hasMatch(value)) {
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
    
    if (_inappropriatePattern.hasMatch(value)) {
      return ValidationResult(false, '不適切な言葉が含まれています');
    }
    
    if (_sqlInjectionPattern.hasMatch(value)) {
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
      // 特殊文字を除外するフィルター
      FilteringTextInputFormatter.allow(
        RegExp(r'[a-zA-Z0-9ぁ-んァ-ヶー一-龯々〆〤\s]'),
      ),
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