import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// 多言語対応サービス
/// 
/// アプリ全体の言語設定を管理し、翻訳機能を提供します。
class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  String _currentLanguage = 'ja'; // デフォルトは日本語
  
  String get currentLanguage => _currentLanguage;
  bool get isJapanese => _currentLanguage == 'ja';
  bool get isEnglish => _currentLanguage == 'en';

  /// 言語を設定
  Future<void> setLanguage(String languageCode) async {
    if (languageCode != _currentLanguage) {
      _currentLanguage = languageCode;
      await _saveLanguagePreference();
      notifyListeners();
    }
  }

  /// 保存された言語設定を読み込み
  Future<void> loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'ja';
    notifyListeners();
  }

  /// 言語設定を保存
  Future<void> _saveLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _currentLanguage);
  }

  /// 翻訳を取得
  String translate(String key) {
    return _translations[_currentLanguage]?[key] ?? key;
  }

  /// 翻訳データ
  static const Map<String, Map<String, String>> _translations = {
    'ja': {
      // アプリ共通
      'app_name': 'TalkOne',
      'ok': 'OK',
      'cancel': 'キャンセル',
      'save': '保存',
      'delete': '削除',
      'edit': '編集',
      'back': '戻る',
      'next': '次へ',
      'skip': 'スキップ',
      'loading': '読み込み中...',
      'error': 'エラー',
      'success': '成功',
      'failed': '失敗',
      
      // ホーム画面
      'home_title': 'Talk One',
      'home_greeting_1': 'こんにちは〜\n今日もがんばってるね！',
      'home_greeting_2': 'おつかれさま\nひと息つこ〜',
      'home_greeting_3': '今どんなアイディアが\n浮かんでる?',
      'home_start_voice_call': '音声通話を始める',
      'home_start_video_call': 'ビデオ通話を始める',
      'home_rate_label': 'RATE',
      'home_ai_rescue_550': '緊急AI救済モード（レート580まで）',
      'home_ai_rescue_700': 'AI救済モード（レート730まで）',
      'home_ai_rescue_850': 'AI練習モード（レート880まで）',
      
      // マッチング画面
      'matching_title': 'Talk One',
      'matching_rate_label': 'RATE',
      'matching_online_users': 'オンラインユーザー',
      'matching_in_progress': 'マッチング中',
      'matching_cancel': 'キャンセル',
      'matching_ai_conversation': 'AI との会話',
      'matching_ai_notification_550': 'AI（ずんだもん）とマッチング中 - レート580を超えると次の段階に進みます',
      'matching_ai_notification_700': 'AI（ずんだもん）とマッチング中 - レート730を超えると次の段階に進みます',
      'matching_ai_notification_850': 'AI（ずんだもん）とマッチング中 - レート880を超えると人間との通話に戻ります',
      
      // 通話画面
      'call_timer_label': '',
      'call_end_button': '通話終了',
      'call_topic_prefix': '話題：',
      
      // 評価画面
      'evaluation_title': '相手を評価してください',
      'evaluation_description': '今回の会話はいかがでしたか？',
      'evaluation_star_1': '★',
      'evaluation_star_2': '★★',
      'evaluation_star_3': '★★★',
      'evaluation_star_4': '★★★★',
      'evaluation_star_5': '★★★★★',
      'evaluation_submit': '評価を送信',
      
      // 再マッチ画面
      'rematch_title': '通話完了',
      'rematch_button': 'もう一度話す',
      'rematch_home_button': 'ホームに戻る',
      
      // 設定画面
      'settings_title': '設定',
      'settings_language': '言語',
      'settings_language_japanese': '日本語',
      'settings_language_english': 'English',
      'settings_theme': 'テーマ',
      'settings_profile': 'プロフィール',
      'settings_credits': 'クレジット',
      
      // プロフィール画面
      'profile_title': 'プロフィール',
      'profile_nickname': 'ニックネーム',
      'profile_gender': '性別',
      'profile_birthday': '誕生日(他の人には公開されません)',
      'profile_ai_memory': 'AIに知ってほしいこと',
      'profile_comment': 'みんなに一言',
      'profile_gender_male': '男性',
      'profile_gender_female': '女性',
      'profile_gender_other': 'その他',
      'profile_gender_not_specified': '回答しない',
      'profile_save_success': '保存しました',
      'profile_save_failed': '保存に失敗しました。しばらく経ってから再度お試しください。',
      
      // 履歴画面
      'history_title': '通話履歴',
      'history_empty': '通話履歴がありません',
      'history_with_ai': 'AI',
      'history_today': '今日',
      'history_yesterday': '昨日',
      'history_days_ago': '日前',
      'history_call_duration': '通話時間',
      'history_your_rating': 'あなたの評価',
      'history_partner_rating': '相手の評価',
      
      // AI チャット画面
      'ai_chat_title': 'AI チャット',
      'ai_chat_input_hint': 'AIとチャットしてみよう...',
      'ai_chat_listening': '音声認識中...',
      'ai_chat_initializing': '初期化中...',
      'ai_chat_empty_message': '会話を始めましょう！',
      'ai_chat_empty_description': 'メッセージ入力または音声で話しかけてください',
      'ai_chat_connection_status_ok': 'Firebase AI Gemini 2.5 Flash (Vertex AI) 接続済み',
      'ai_chat_connection_status_error': 'Firebase AI 接続エラー - 設定確認',
      
      // エラーメッセージ
      'error_network': 'ネットワークエラーが発生しました',
      'error_permission': '権限が必要です',
      'error_unknown': '不明なエラーが発生しました',
      
      // 通報関連
      'report_title': '通報',
      'report_reason': '通報理由',
      'report_details': '詳細',
      'report_submit': '通報する',
      'report_success': '通報を受け付けました',
      
      // AI プリコール画面
      'ai_precall_title': 'AI練習モード',
      'ai_precall_countdown': '音声チャット開始まで...',
      'ai_precall_skip': 'スキップ',
      
      // 追加翻訳
      'block_user': 'このユーザーをブロック',
      'partner_profile': '相手のプロフィール',
      'call_history': '通話履歴',
      'my_rating': '私の評価',
      'date': '日付',
      'delete_account': 'アカウント削除',
      'notifications': '通知',
      'error_occurred': 'エラーが発生しました',
      'waiting_users': 'マッチング待ちのユーザー',
      'matching_cancelled': 'マッチングがキャンセルされました',
      'conversation_screen': '会話画面',
      'call_ended': '通話終了',
      
      // プリコール画面
      'approve': '承認',
      'reject': '拒否',
      
      // パートナープロフィール画面
      'report_user': 'ユーザーを通報',
      'block_confirm_title': 'ユーザーをブロック',
      'block_confirm_message': 'このユーザーをブロックしますか？今後マッチングされなくなります。',
      'block_success': 'ユーザーをブロックしました',
      'block_failed': 'ブロックに失敗しました',
      
      // アカウント削除
      'delete_account_title': 'アカウント削除',
      'delete_account_message': '本当にアカウントを削除しますか？この操作は取り消せません。',
      'delete_account_confirm': '削除する',
      
      // 通知メッセージ
      'notification_empty': '通知はありません',
      'notification_new_match': '新しいマッチが見つかりました',
      'notification_call_request': '通話リクエストがあります',
      
      // エラーメッセージ
      'error_loading_profile': 'プロフィールの読み込みに失敗しました',
      'error_matching': 'マッチングエラーが発生しました',
      'error_call_failed': '通話接続に失敗しました',
    },
    
    'en': {
      // App Common
      'app_name': 'TalkOne',
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'back': 'Back',
      'next': 'Next',
      'skip': 'Skip',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'failed': 'Failed',
      
      // Home Screen
      'home_title': 'Talk One',
      'home_greeting_1': 'Hello!\nKeep up the good work today!',
      'home_greeting_2': 'Good job!\nTake a break',
      'home_greeting_3': 'What ideas are you\nthinking about?',
      'home_start_voice_call': 'Start Voice Call',
      'home_start_video_call': 'Start Video Call',
      'home_rate_label': 'RATE',
      'home_ai_rescue_550': 'Emergency AI Rescue Mode (Until Rate 580)',
      'home_ai_rescue_700': 'AI Rescue Mode (Until Rate 730)',
      'home_ai_rescue_850': 'AI Practice Mode (Until Rate 880)',
      
      // Matching Screen
      'matching_title': 'Talk One',
      'matching_rate_label': 'RATE',
      'matching_online_users': 'Online Users',
      'matching_in_progress': 'Matching...',
      'matching_cancel': 'Cancel',
      'matching_ai_conversation': 'AI Conversation',
      'matching_ai_notification_550': 'Matching with AI (Zundamon) - Advance to next stage when rate exceeds 580',
      'matching_ai_notification_700': 'Matching with AI (Zundamon) - Advance to next stage when rate exceeds 730',
      'matching_ai_notification_850': 'Matching with AI (Zundamon) - Return to human calls when rate exceeds 880',
      
      // Call Screen
      'call_timer_label': '',
      'call_end_button': 'End Call',
      'call_topic_prefix': 'Topic: ',
      
      // Evaluation Screen
      'evaluation_title': 'Rate Your Partner',
      'evaluation_description': 'How was this conversation?',
      'evaluation_star_1': '★',
      'evaluation_star_2': '★★',
      'evaluation_star_3': '★★★',
      'evaluation_star_4': '★★★★',
      'evaluation_star_5': '★★★★★',
      'evaluation_submit': 'Submit Rating',
      
      // Rematch Screen
      'rematch_title': 'Call Completed',
      'rematch_button': 'Talk Again',
      'rematch_home_button': 'Back to Home',
      
      // Settings Screen
      'settings_title': 'Settings',
      'settings_language': 'Language',
      'settings_language_japanese': '日本語',
      'settings_language_english': 'English',
      'settings_theme': 'Theme',
      'settings_profile': 'Profile',
      'settings_credits': 'Credits',
      
      // Profile Screen
      'profile_title': 'Profile',
      'profile_nickname': 'Nickname',
      'profile_gender': 'Gender',
      'profile_birthday': 'Birthday (Private)',
      'profile_ai_memory': 'What AI should know about you',
      'profile_comment': 'Message to everyone',
      'profile_gender_male': 'Male',
      'profile_gender_female': 'Female',
      'profile_gender_other': 'Other',
      'profile_gender_not_specified': 'Prefer not to say',
      'profile_save_success': 'Saved successfully',
      'profile_save_failed': 'Failed to save. Please try again later.',
      
      // History Screen
      'history_title': 'Call History',
      'history_empty': 'No call history',
      'history_with_ai': 'AI',
      'history_today': 'Today',
      'history_yesterday': 'Yesterday',
      'history_days_ago': ' days ago',
      'history_call_duration': 'Duration',
      'history_your_rating': 'Your Rating',
      'history_partner_rating': 'Partner\'s Rating',
      
      // AI Chat Screen
      'ai_chat_title': 'AI Chat',
      'ai_chat_input_hint': 'Chat with AI...',
      'ai_chat_listening': 'Listening...',
      'ai_chat_initializing': 'Initializing...',
      'ai_chat_empty_message': 'Let\'s start chatting!',
      'ai_chat_empty_description': 'Type a message or speak to chat',
      'ai_chat_connection_status_ok': 'Firebase AI Gemini 2.5 Flash (Vertex AI) Connected',
      'ai_chat_connection_status_error': 'Firebase AI Connection Error - Check Settings',
      
      // Error Messages
      'error_network': 'Network error occurred',
      'error_permission': 'Permission required',
      'error_unknown': 'Unknown error occurred',
      
      // Report Related
      'report_title': 'Report',
      'report_reason': 'Reason',
      'report_details': 'Details',
      'report_submit': 'Submit Report',
      'report_success': 'Report submitted successfully',
      
      // AI Pre-call Screen
      'ai_precall_title': 'AI Practice Mode',
      'ai_precall_countdown': 'Voice chat starting in...',
      'ai_precall_skip': 'Skip',
      
      // Additional translations requested
      'block_user': 'Block this user',
      'partner_profile': 'Partner\'s Profile',
      'call_history': 'Call History',
      'my_rating': 'My Rating',
      'date': 'Date',
      'delete_account': 'Delete Account',
      'notifications': 'Notifications',
      'error_occurred': 'An error occurred',
      'waiting_users': 'Waiting for users',
      'matching_cancelled': 'Matching cancelled',
      'conversation_screen': 'Conversation Screen',
      'call_ended': 'Call Ended',
      
      // Pre-call screen
      'approve': 'Approve',
      'reject': 'Reject',
      
      // Partner profile screen
      'report_user': 'Report User',
      'block_confirm_title': 'Block User',
      'block_confirm_message': 'Are you sure you want to block this user? You will no longer be matched with them.',
      'block_success': 'User has been blocked',
      'block_failed': 'Failed to block user',
      
      // Account deletion
      'delete_account_title': 'Delete Account',
      'delete_account_message': 'Are you sure you want to delete your account? This action cannot be undone.',
      'delete_account_confirm': 'Delete',
      
      // Notification messages
      'notification_empty': 'No notifications',
      'notification_new_match': 'New match found',
      'notification_call_request': 'Incoming call request',
      
      // Error messages
      'error_loading_profile': 'Failed to load profile',
      'error_matching': 'Matching error occurred',
      'error_call_failed': 'Call connection failed',
    },
  };
}