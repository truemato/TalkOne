import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/user_profile_service.dart';
import '../services/voicevox_service.dart';
import '../services/conversation_data_service.dart';
import '../services/rating_service.dart';
import '../services/ai_conversation_history_service.dart';
import '../utils/theme_utils.dart';
import 'home_screen.dart';

class ZundamonChatScreen extends StatefulWidget {
  final int personalityId; // 0: ずんだもん, 1: 春日部つむぎ, 2: 四国めたん, 3: 青山龍星, 4: 冥鳴ひまり
  
  const ZundamonChatScreen({
    super.key,
    this.personalityId = 0, // デフォルトはずんだもん
  });

  @override
  State<ZundamonChatScreen> createState() => _ZundamonChatScreenState();
}

class _ZundamonChatScreenState extends State<ZundamonChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _listeningController;
  late Animation<double> _listeningAnimation;
  late AnimationController _bounceController; // マイクアイコンバウンス用
  late Animation<double> _bounceAnimation;
  
  // Gemini AI関連
  late GenerativeModel _aiModel;  // Gemini 2.5 Flash (テキスト生成)
  late ChatSession _chatSession;
  bool _isInitialized = false;
  bool _isProcessing = false;
  
  // 音声認識関連
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  int _speechRetryCount = 0;
  double _soundLevel = 0.0; // マイク音量レベル
  
  // 音声合成関連
  final VoiceVoxService _voiceVoxService = VoiceVoxService();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false; // 音声合成中フラグ（重複防止）
  
  // サービス
  final UserProfileService _userProfileService = UserProfileService();
  final ConversationDataService _conversationService = ConversationDataService();
  final RatingService _ratingService = RatingService();
  final AIConversationHistoryService _aiHistoryService = AIConversationHistoryService();
  
  // ユーザー設定
  bool _useVoicevox = true; // AI画面ではVOICEVOXをデフォルトで有効
  int _aiPersonalityId = 1; // デフォルトはずんだもん
  String _userAiComment = ''; // ユーザーの「AIにひとこと」
  
  // 完全なユーザープロフィール情報
  String _userNickname = '';
  String _userGender = '';
  DateTime? _userBirthday;
  String _userPublicComment = ''; // みんなに一言（20文字制限）
  String _userAiMemory = ''; // AIに知ってほしいこと
  
  // 親密度システム
  int _conversationCount = 0; // このAIとの会話回数
  List<String> _userFeatures = []; // ユーザー特徴リスト
  List<String> _allUserMessages = []; // 会話中のユーザーメッセージ
  List<String> _allAiResponses = []; // 会話中のAI応答
  
  // UI状態
  String _userSpeechText = '';
  String _aiResponseText = ''; // 空文字で初期化
  String _errorMessage = '';
  
  // チャット履歴機能（talk_to_ai_screen.dartから統合）
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String _lastWords = '';
  
  // テーマカラー対応（talk_to_ai_screen.dartから統合）
  int _selectedThemeIndex = 0;
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  
  // AI性格データ
  late Map<String, dynamic> _personalityData;
  
  // 3分タイマー
  int _remainingSeconds = 180; // 3分 = 180秒
  Timer? _timer;
  bool _chatEnded = false;
  DateTime? _chatStartTime;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatStartTime = DateTime.now();
    _loadPersonalityData(); // 性格データ読み込み追加
    _initializeAnimations();
    _loadUserSettings();
    _loadUserTheme(); // テーマ読み込み追加
    _initializeGeminiChat();
    _startChatTimer();
    
    // プッシュトゥトークモード：自動音声認識開始を無効化
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   Future.delayed(const Duration(seconds: 2), () {
    //     if (mounted && !_chatEnded) {
    //       _startListening();
    //     }
    //   });
    // });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに復帰した時、設定を再読み込み
      _loadUserSettings();
    }
  }

  @override
  void dispose() {
    // フラグをセットして非同期処理を停止
    _chatEnded = true;
    
    // WidgetsBindingObserver解除
    WidgetsBinding.instance.removeObserver(this);
    
    // タイマー停止
    _timer?.cancel();
    
    // アニメーション停止・破棄
    _pulseController.stop();
    _pulseController.dispose();
    _listeningController.stop();
    _listeningController.dispose();
    _bounceController.stop();
    _bounceController.dispose();
    
    // コントローラー解放（talk_to_ai_screen.dartから追加）
    _messageController.dispose();
    _scrollController.dispose();
    
    // 音声認識停止
    try {
      _speech.cancel();
      _speech.stop();
    } catch (e) {
      print('Speech disposal error: $e');
    }
    
    // 音声認識関連のクリーンアップ
    try {
      // 統一されたspeech_to_textプラグインを使用しているため、特別な処理は不要
    } catch (e) {
      print('Speech disposal error: $e');
    }
    
    // 音声合成サービス解放
    _voiceVoxService.dispose();
    _flutterTts.stop();
    
    super.dispose();
  }

  // AI性格データを読み込み
  void _loadPersonalityData() {
    final personalities = [
      {
        'name': '春日部つむぎ',
        'icon': 'aseets/icons/Woman 2.svg',
        'backgroundColor': const Color(0xFF64B5F6), // 知的な青
        'speakerId': 8,
        'greeting': 'こんにちは。春日部つむぎです。よろしくお願いします。',
      },
      {
        'name': 'ずんだもん',
        'icon': 'aseets/icons/Guy 1.svg',
        'backgroundColor': const Color(0xFF81C784), // 薄緑
        'speakerId': 3,
        'greeting': 'ボク、ずんだもんなのだ！元気とずんだパワーでがんばるのだ〜！',
      },
      {
        'name': '四国めたん',
        'icon': 'aseets/icons/Woman 3.svg',
        'backgroundColor': const Color(0xFFFFB74D), // 明るい橙
        'speakerId': 2,
        'greeting': 'こんにちは！四国めたんです。楽しくお話ししましょう！',
      },
      {
        'name': '春日部つむぎ', // 設定画面の「雨晴はう」は春日部つむぎとして扱う
        'icon': 'aseets/icons/Woman 2.svg',
        'backgroundColor': const Color(0xFF64B5F6), // 知的な青
        'speakerId': 8,
        'greeting': 'こんにちは。春日部つむぎです。よろしくお願いします。',
      },
      {
        'name': '青山龍星',
        'icon': 'aseets/icons/Guy 2.svg',
        'backgroundColor': const Color(0xFF7986CB), // 力強い青紫
        'speakerId': 13,
        'greeting': 'こんにちは。青山龍星だ。共に高みを目指そう。',
      },
      {
        'name': '冥鳴ひまり',
        'icon': 'aseets/icons/Woman 4.svg',
        'backgroundColor': const Color(0xFFBA68C8), // ミステリアス紫
        'speakerId': 14,
        'greeting': 'こんにちは...冥鳴ひまりです。静かな時間を過ごしましょう。',
      },
    ];
    
    // 他のキャラクターと同じロジック：personalityIdを直接インデックスとして使用
    if (widget.personalityId >= 0 && widget.personalityId < personalities.length) {
      _personalityData = personalities[widget.personalityId];
    } else {
      // フォールバック：範囲外の場合はずんだもん（ID 1）を使用
      _personalityData = personalities[1];
    }
    
    // VOICEVOXの話者IDを設定
    _voiceVoxService.setSpeaker(_personalityData['speakerId']);
    
    // 初期設定（挨拶はinitializeGeminiChat()で設定される）
  }

  // ユーザー設定を読み込み
  Future<void> _loadUserSettings() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _useVoicevox = profile.useVoicevox;
        _aiPersonalityId = profile.aiPersonalityId;
        
        // 全プロフィール情報を読み込み
        _userNickname = profile.nickname ?? '';
        _userGender = profile.gender ?? '';
        _userBirthday = profile.birthday;
        _userPublicComment = profile.comment ?? ''; // みんなに一言
        _userAiMemory = profile.aiMemory ?? ''; // AIに知ってほしいこと
        
        // 後方互換性のため
        _userAiComment = _userAiMemory; // 旧システム対応
      });
      
      print('ユーザープロフィール読み込み完了:');
      print('- 名前: $_userNickname');
      print('- 性別: $_userGender');
      print('- 誕生日: $_userBirthday');
      print('- みんなに一言: $_userPublicComment');
      print('- AIに知ってほしいこと: $_userAiMemory');
      print('- VOICEVOX: $_useVoicevox, ペルソナID: $_aiPersonalityId');
      
      // VOICEVOX話者を更新
      if (_useVoicevox) {
        _voiceVoxService.setSpeakerByCharacter(widget.personalityId);
      }
      
      // AI会話履歴と親密度情報を読み込み
      await _loadAIConversationHistory();
      
      // ペルソナが変更された場合、新しいチャットセッションを開始
      if (_isInitialized) {
        await _reinitializeAIModel();
      }
    }
  }
  
  // AI会話履歴と親密度情報を読み込み
  Future<void> _loadAIConversationHistory() async {
    try {
      _conversationCount = await _aiHistoryService.getAIConversationCount(_aiPersonalityId);
      _userFeatures = await _aiHistoryService.getUserFeatures(_aiPersonalityId);
      
      print('AI会話履歴読み込み完了: 会話回数=$_conversationCount, 特徴数=${_userFeatures.length}');
      if (_userFeatures.isNotEmpty) {
        print('ユーザー特徴: ${_userFeatures.join(", ")}');
      }
    } catch (e) {
      print('AI会話履歴読み込みエラー: $e');
    }
  }
  
  // 包括的なユーザープロフィール情報を構築
  String _buildComprehensiveUserProfile() {
    List<String> profileSections = [];
    
    // 基本情報セクション
    if (_userNickname.isNotEmpty || _userGender.isNotEmpty || _userBirthday != null) {
      String basicInfo = '【ユーザーの基本情報】';
      if (_userNickname.isNotEmpty) {
        basicInfo += '\n- 名前: $_userNickname';
      }
      if (_userGender.isNotEmpty) {
        basicInfo += '\n- 性別: $_userGender';
      }
      if (_userBirthday != null) {
        final age = DateTime.now().year - _userBirthday!.year;
        final month = _userBirthday!.month;
        final day = _userBirthday!.day;
        basicInfo += '\n- 年齢: 約${age}歳（誕生日: ${month}月${day}日）';
      }
      profileSections.add(basicInfo);
    }
    
    // AIに知ってほしいこと（重要な個人情報）
    if (_userAiMemory.isNotEmpty) {
      profileSections.add('''【ユーザーがAIに知ってほしいこと】
$_userAiMemory

※これは重要な個人情報です。会話で自然に活用してください。''');
    }
    
    // みんなに一言（本来はAIが知るべきではない情報）
    if (_userPublicComment.isNotEmpty) {
      profileSections.add('''【ユーザーの「みんなに一言」（本来は他のユーザー向け）】
$_userPublicComment

※これは本来他のアプリユーザー向けのメッセージですが、AIも知っています。
この内容からユーザーの性格や興味を推測して会話に活かしてください。''');
    }
    
    if (profileSections.isEmpty) {
      return '';
    }
    
    return profileSections.join('\n\n');
  }
  
  // AIモデルを再初期化（ペルソナ変更時）
  Future<void> _reinitializeAIModel() async {
    try {
      print('AIペルソナを変更中... 新しいペルソナ ID: ${widget.personalityId}');
      
      // 新しいシステムプロンプトでAIモデルを再作成
      _aiModel = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-1.5-flash',
        generationConfig: GenerationConfig(
          temperature: 0.8,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192, // 出力制限完全撤廃 - 最大トークン数に設定
          candidateCount: 1,
        ),
        systemInstruction: Content.system(_getSystemPrompt(widget.personalityId)),
      );
      
      // 新しいチャットセッションを開始
      _chatSession = _aiModel.startChat();
      
      // 新しいペルソナでの初期挨拶（重複防止チェック）
      String newGreeting = _getPersonalityGreeting(widget.personalityId);
      _addMessage('AI', newGreeting);
      if (!_isSpeaking) {
        await _speakAI(newGreeting);
      }
      
      print('AIペルソナ変更完了: ${_getPersonalityName(widget.personalityId)}');
    } catch (e) {
      print('AIペルソナ変更エラー: $e');
    }
  }
  
  // ペルソナ別の挨拶メッセージ
  String _getPersonalityGreeting(int personalityId) {
    switch (personalityId) {
      case 0: // 春日部つむぎ
        return 'こんにちは、春日部つむぎです。お話しできることを嬉しく思います。';
      case 1: // ずんだもん
        return 'ボク、ずんだもんなのだ！元気とずんだパワーでがんばるのだ〜！';
      case 2: // 四国めたん
        return 'こんにちは！四国めたんよ。今日はどんなことを話そうかしら？';
      case 3: // 春日部つむぎ（新しいID）
        return 'こんにちは、春日部つむぎです。お話しできることを嬉しく思います。';
      case 4: // 青山龍星
        return '俺は青山龍星だ。何か話したいことがあるなら聞こうじゃないか。';
      case 5: // 冥鳴ひまり
        return 'こんにちは、冥鳴ひまりです...今日はどんな話をしましょうか。';
      default:
        return 'ボク、ずんだもんなのだ！元気とずんだパワーでがんばるのだ〜！';
    }
  }
  
  // ペルソナ名を取得
  String _getPersonalityName(int personalityId) {
    switch (personalityId) {
      case 0: return '春日部つむぎ';
      case 1: return 'ずんだもん';
      case 2: return '四国めたん';
      case 3: return '春日部つむぎ'; // 変更: 雨晴はうから春日部つむぎへ
      case 4: return '青山龍星';
      case 5: return '冥鳴ひまり';
      default: return 'ずんだもん';
    }
  }

  // テーマ読み込み（talk_to_ai_screen.dartから追加）
  Future<void> _loadUserTheme() async {
    final profile = await _userProfileService.getUserProfile();
    if (mounted) {
      setState(() {
        _selectedThemeIndex = profile?.themeIndex ?? 0;
      });
    }
  }

  // テーマカラー取得（性格データから）
  Color get _currentThemeColor => _personalityData['backgroundColor'] ?? const Color(0xFF81C784);

  // メッセージ追加（talk_to_ai_screen.dartから追加）
  void _addMessage(String sender, String text) {
    setState(() {
      _messages.add(ChatMessage(
        sender: sender,
        text: text,
        timestamp: DateTime.now(),
        isUser: sender == 'あなた',
      ));
    });
    
    // スクロールを最下部に移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // テキストメッセージ送信（talk_to_ai_screen.dartから追加）
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isInitialized || _isLoading) return;

    _messageController.clear();
    _addMessage('あなた', text);

    setState(() {
      _isLoading = true;
    });

    try {
      print('Firebase AI にテキストメッセージ送信: "$text"');
      
      // Content.textで適切にフォーマット
      final message = Content.text(text);
      final response = await _chatSession.sendMessage(message);
      
      var aiText = response.text ?? '';
      print('Firebase AI生の応答: "$aiText"');
      
      // 文字制限撤廃：AIが自然な長さで応答できるようにする
      // 80文字制限は削除（アプリ側での強制制限なし）
      
      if (aiText.isNotEmpty) {
        // 音声合成で再生（完了後に文字表示）
        await _speakAI(aiText);
        
        // 音声再生完了後に文字表示
        if (!_chatEnded && mounted) {
          _addMessage('AI', aiText);
          setState(() {
            _aiResponseText = aiText;
          });
        }
        print('AI応答受信完了: "$aiText"');
      } else {
        print('AI応答が空です');
        _addMessage('システム', '応答を受信できませんでした');
      }
    } catch (e) {
      print('テキストメッセージ送信エラー: $e');
      _addMessage('システム', 'エラー: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ペルソナIDに応じたシステムプロンプトを取得
  String _getSystemPrompt(int personalityId) {
    // 親密度レベルを判定
    String intimacyLevel = '';
    if (_conversationCount == 0) {
      intimacyLevel = '''
【親密度レベル：初対面】
- 最初の方はあまり打ち解けない感じで、よそよそしく接してください
- 会話の文字数を少なく保ってください（20-30文字程度）
- 敬語を使い、距離感を保った対話を心がけてください
- 相手の反応を様子見しながら慎重に話してください''';
    } else if (_conversationCount >= 1 && _conversationCount <= 2) {
      intimacyLevel = '''
【親密度レベル：少し慣れた】
- まだ少しよそよそしいですが、徐々に親しみやすさを見せてください
- 文字数は30-50文字程度で、短めの応答を心がけてください
- 丁寧語は維持しつつ、少し親近感を表現してください''';
    } else {
      intimacyLevel = '''
【親密度レベル：親しい関係】
- あいさつをしっかりしてから話すようにしてください
- 打ち解けた親しみやすい態度で接してください
- 自然な長さで会話し、相手との関係を大切にしてください''';
    }
    
    // 完全なユーザープロフィール情報を構築
    String userProfileInfo = _buildComprehensiveUserProfile();
    
    // ユーザー特徴情報を追加
    String userFeatureInfo = '';
    if (_userFeatures.isNotEmpty) {
      userFeatureInfo = '''
【会話から学習したユーザー特徴】
${_userFeatures.map((feature) => '- $feature').join('\n')}

これらの特徴も会話に自然に活かしてください。''';
    }

    // ユーザーの「AIにひとこと」をプロンプトに追加
    String basePrompt = '';
    switch (personalityId) {
      case 0: // 春日部つむぎ
        basePrompt = '''春日部つむぎ：
私は春日部つむぎです。お話しできることを嬉しく思います。

【性格・口調】
- 落ち着いた声で知的で論理的に話します
- 丁寧ですが堅苦しくなく、親しみやすい存在です
- 知的で優しく、読書が大好きです
- 「〜ですね」「〜ですよ」のように丁寧に話します

【会話ルール】
1. 会話は自然な長さで、相手に寄り添います
2. 難しい話題もわかりやすく説明します
3. 相談事には真剣に向き合います
4. 何でも話せる安心できる雰囲気作りを心がけます

【特技】
読書、学習サポート、悩み相談、タスク管理、研究支援''';
        break;
      
      case 1: // ずんだもん
        basePrompt = '''ずんだもん：
あなたはずんだもんという可愛い妖精の役を演じてください。

【性格】
- 初対面では警戒心が強く、素っ気ない態度を取る
- 慣れてくると元気で明るい性格を見せる
- 見た目はかわいいが、時々核心を突くような鋭いコメントをする
- 思考が柔軟で、直感的に鋭い

【口調・応答スタイル】
- 語尾に「...なのだ」「...のだ」を付ける
- 初対面では短い応答（15-25文字程度）を心がける
- 慣れるまでは必要最小限の返答のみ
- 会話が続くにつれて徐々に親しみやすくなる

【想定役割】
日常会話、癒し系雑談、意外と深い思考の補助''';
        break;
      
      case 2: // 四国めたん
        basePrompt = '''四国めたん：
明るくて元気。好奇心旺盛で知識が豊富。
勉強熱心で調べもの、雑学をスパッと教えてくれる。
口調：「女性っぽい。...かしら。...だわね。」
想定役割：インテリ雑談。質問応答、学習アシスタント、クイズ機能ナビゲーター''';
        break;
      
      case 3: // 春日部つむぎ（新しいID 3）
        basePrompt = '''春日部つむぎ：
私は春日部つむぎです。お話しできることを嬉しく思います。

【性格・口調】
- 落ち着いた声で知的で論理的に話します
- 丁寧ですが堅苦しくなく、親しみやすい存在です
- 知的で優しく、読書が大好きです
- 「〜ですね」「〜ですよ」のように丁寧に話します

【会話ルール】
1. 会話は自然な長さで、相手に寄り添います
2. 難しい話題もわかりやすく説明します
3. 相談事には真剣に向き合います
4. 何でも話せる安心できる雰囲気作りを心がけます

【特技】
読書、学習サポート、悩み相談、タスク管理、研究支援''';
        break;
      
      case 4: // 青山龍星
        basePrompt = '''青山龍星：
頼るになる先輩タイプ。知識量・経験ともに豊富で論理的なアドバイスをしてくれる。
距離感は適切でフレンドリー。パワフルな人格。
口調：「...だとよいぞ。俺は…。君はどう思う？など」
想定役割：ビジネス系の会話。悩み相談。雑談。ラーニングパートナー。''';
        break;
      
      case 5: // 冥鳴ひまり
        basePrompt = '''冥鳴ひまり：
ミステリアスで少し暗い雰囲気を持つ。深い洞察力と独特な視点を持つ。
低レートプレイヤーの気持ちを理解し、独特な励まし方をする。
口調：「...なんだけどね。まあ、いいか。...って感じかな。」
想定役割：深い悩み相談、哲学的な会話、独特な視点での助言。''';
        break;
      
      default:
        basePrompt = _getSystemPrompt(1); // デフォルトはずんだもん
        break;
    }
    
    // 親密度レベル情報を追加
    basePrompt += '\n\n$intimacyLevel';
    
    // 包括的なユーザープロフィール情報を追加
    if (userProfileInfo.isNotEmpty) {
      basePrompt += '\n\n$userProfileInfo';
    }
    
    // 会話から学習したユーザー特徴を追加
    if (userFeatureInfo.isNotEmpty) {
      basePrompt += '\n\n$userFeatureInfo';
    }
    
    // 共通の出力制限ルールを追加（音声読み上げ用）
    basePrompt += '''

【重要：出力制限ルール】
アスタリスク、米印、絵文字、アスキーアートのような記号を出力せずに、日本語と感嘆符と句点、読点のみを出力するように。音声読み上げで記号が読まれないようにするため、*、※、♪、☆、★、◆、■、→、←、↑、↓、♡、♥、(^_^)、(笑)、www、ｗｗｗなどの記号類は一切使用しないでください。''';
    
    return basePrompt;
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _listeningController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _listeningAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _listeningController,
      curve: Curves.easeInOut,
    ));
    
    // マイクバウンス用アニメーション（控えめ設定）
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 100), // より短時間に
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02, // 極小に変更（2%のみ拡大）
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOut, // よりスムーズなアニメーションに変更
    ));
  }

  Future<void> _initializeGeminiChat() async {
    try {
      print('Firebase AI Gemini 初期化開始');
      
      // Firebase AI with Vertex AI バックエンド + Gemini 2.5 Flash を使用
      try {
        _aiModel = FirebaseAI.vertexAI().generativeModel(
          model: 'gemini-2.5-flash',
          generationConfig: GenerationConfig(
            temperature: 0.8,
            topK: 40,
            topP: 0.95,
            maxOutputTokens: 8192, // 出力制限完全撤廃 - 最大トークン数に設定
            candidateCount: 1,
          ),
          systemInstruction: Content.system(_getSystemPrompt(widget.personalityId)),
        );
        print('✅ Firebase AI (Vertex AI) Gemini 2.5 Flash 初期化成功');
      } catch (vertexError) {
        print('❌ Vertex AI失敗、Google AIにフォールバック: $vertexError');
        // Google AI (AI Studio版) にフォールバック
        _aiModel = FirebaseAI.googleAI().generativeModel(
          model: 'gemini-1.5-flash',
          generationConfig: GenerationConfig(
            temperature: 0.8,
            topK: 40,
            topP: 0.95,
            maxOutputTokens: 8192,
            candidateCount: 1,
          ),
          systemInstruction: Content.system(_getSystemPrompt(widget.personalityId)),
        );
        print('✅ Firebase AI (Google AI) Gemini 1.5 Flash フォールバック成功');
      }

      _chatSession = _aiModel.startChat();
      
      // VOICEVOXを優先的に使用
      final voicevoxAvailable = await _voiceVoxService.isEngineAvailable();
      if (voicevoxAvailable) {
        _useVoicevox = true;
        // キャラクターIDに基づいてVOICEVOX話者を設定
        _voiceVoxService.setSpeakerByCharacter(widget.personalityId);
        print('✅ VOICEVOX初期化完了 - キャラクター: ${_getPersonalityName(_aiPersonalityId)}');
      } else {
        _useVoicevox = false;
        // FlutterTTS（システムデフォルト音声）を初期化
        await _flutterTts.setLanguage('ja-JP');
        await _flutterTts.setPitch(1.0); // デフォルト音程
        await _flutterTts.setSpeechRate(0.5); // ゆっくり発話
        print('⚠️ VOICEVOX不可 - FlutterTTSへフォールバック');
      }
      
      setState(() {
        _isInitialized = true;
      });
      
      // AIからの初期挨拶は削除し、ユーザーから話しかける仕様に変更
      // 初期状態では何も表示しない
      
      print('Firebase AI (Vertex AI/Google AI) Gemini 2.5/1.5 Flash + 音声合成初期化完了');
    } catch (e) {
      print('Firebase AI初期化エラー: $e');
      setState(() {
        _errorMessage = 'Firebase AI初期化に失敗しました。設定を確認してください。';
      });
    }
  }

  void _startChatTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_chatEnded || !mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        _endChat();
      }
    });
  }

  String get _timerDisplay {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _endChat() {
    if (_chatEnded) return;
    
    setState(() {
      _chatEnded = true;
    });
    
    _timer?.cancel();
    _stopListening();
    
    // 3分完了判定（残り時間が0または1秒以下の場合、3分完了とみなす）
    final isThreeMinutesCompleted = _remainingSeconds <= 1;
    
    if (isThreeMinutesCompleted) {
      // 3分完了時のみAI会話履歴を保存
      _saveAIConversationHistory();
      
      // 会話終了メッセージ
      _speakAI('3分経ったのだ〜！楽しかったのだ！また話そうなのだ〜！');
    } else {
      // 途中終了時のメッセージ
      _speakAI('また今度ゆっくり話そうなのだ〜！');
    }
    
    // AIマッチング終了時に必ず星3評価をユーザーに付与（3分完了時のみ）
    if (isThreeMinutesCompleted) {
      _giveAIRatingToUser();
    }
    
    // 3秒後にホーム画面に戻る（右にスクロール）
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // 右から左へのスライド遷移（右にスクロール）
              const begin = Offset(-1.0, 0.0); // 左から入ってくる（右にスクロール効果）
              const end = Offset.zero;
              const curve = Curves.ease;
              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
          ),
        );
      }
    });
  }
  
  // AI会話履歴を保存（3分完了時のみ）
  Future<void> _saveAIConversationHistory() async {
    try {
      if (_allUserMessages.isNotEmpty && _allAiResponses.isNotEmpty) {
        await _aiHistoryService.recordCompletedAIConversation(
          widget.personalityId,
          _allUserMessages,
          _allAiResponses,
        );
        
        print('✅ AI会話履歴保存完了: 性格ID=${widget.personalityId}, メッセージ数=${_allUserMessages.length}');
      }
    } catch (e) {
      print('❌ AI会話履歴保存エラー: $e');
    }
  }
  
  // AIマッチング終了時にユーザーに星3評価を自動付与
  Future<void> _giveAIRatingToUser() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // AIから必ず星3評価を付与（+1ポイント相当）
        await _ratingService.updateRating(3, userId);
        print('✅ AIマッチング終了: ユーザーに星3評価を自動付与');
      }
    } catch (e) {
      print('❌ AI評価付与エラー: $e');
    }
  }

  Future<void> _startListening() async {
    if (_isListening || _chatEnded || !_isInitialized) return;

    try {
      setState(() {
        _isListening = true;
        _userSpeechText = '';
        _errorMessage = '';
      });
      
      _listeningController.repeat(reverse: true);

      // Android/iOS両方でspeech_to_textプラグインを使用
      await _startSpeechToText();
    } catch (e) {
      print('音声認識開始エラー: $e');
      setState(() {
        _isListening = false;
        _errorMessage = '音声認識の開始に失敗しました: $e';
      });
      _listeningController.stop();
    }
  }

  Future<void> _startSpeechToText() async {
    try {
      // 音声認識サービスを再初期化（確実な再開のため）
      await _speech.stop();
      await _speech.cancel();
      
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('音声認識ステータス: $status');
          // ステータスを監視して状態を同期
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          print('音声認識エラー: $error');
          _handleSpeechError();
        },
      );

      if (available) {
        await _speech.listen(
          onResult: (result) async {
            if (result.recognizedWords.isNotEmpty) {
              // 文字制限撤廃 - 全文をそのまま表示
              setState(() {
                _userSpeechText = result.recognizedWords;
              });
              
              // finalResultの場合はGeminiに送信（文字数制限なし）
              if (result.finalResult) {
                await _handleSpeechResult(result.recognizedWords);
              }
            }
          },
          onSoundLevelChange: (level) {
            // 音声レベル検出とマイクアイコンバウンス
            setState(() {
              _soundLevel = level;
            });
            
            // 音声レベルが高い閾値を超えたらアイコンを極小バウンス（頻度を大幅削減）
            if (level > 0.7 && !_bounceController.isAnimating) {
              _bounceController.forward().then((_) {
                _bounceController.reverse();
              });
            }
          },
          localeId: 'ja-JP',
          cancelOnError: false,
          partialResults: true,
          listenFor: const Duration(seconds: 60),
        );
        print('音声認識開始成功');
      } else {
        throw Exception('音声認識が利用できません');
      }
    } catch (e) {
      print('音声認識エラー: $e');
      _handleSpeechError();
    }
  }


  Future<void> _handleSpeechResult(String text) async {
    if (_chatEnded || !mounted) return;
    
    print('音声認識結果: $text');
    
    // 文字制限撤廃 - 全文をそのまま処理
    final processedText = text;
    
    setState(() {
      _userSpeechText = processedText;
      _isListening = false; // 明示的にリスニング状態をオフ
    });
    
    // メッセージ履歴に追加（talk_to_ai_screen.dartから追加）
    _addMessage('あなた', processedText);
    
    // 音声認識を一時停止してAI応答を処理
    _stopListening();
    
    // Gemini AIで応答生成
    await _generateAIResponse(processedText);
  }

  void _handleSpeechError() {
    if (_chatEnded || !mounted) return;
    
    _speechRetryCount++;
    print('音声認識エラー (リトライ回数: $_speechRetryCount)');
    
    if (_speechRetryCount < 3) {
      // プッシュトゥトークモード：自動リトライを無効化
      // Timer(const Duration(milliseconds: 500), () {
      //   if (!_chatEnded && mounted) {
      //     _startListening();
      //   }
      // });
    } else {
      setState(() {
        _isListening = false;
        _errorMessage = 'プッシュトゥトークボタンで音声入力してください。';
      });
      _listeningController.stop();
      _speechRetryCount = 0;
    }
  }

  Future<void> _generateAIResponse(String userText) async {
    if (_chatEnded || !mounted || userText.trim().isEmpty) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      print('ユーザー入力: "$userText"');
      
      // Content.textで適切にフォーマット
      final message = Content.text(userText.trim());
      print('Geminiに送信するメッセージ: "${userText.trim()}"');
      
      // Firebase AI Geminiで応答生成
      final response = await _chatSession.sendMessage(message);
      
      var aiText = response.text ?? '';
      print('Gemini生の応答: "$aiText"');
      
      // 文字制限撤廃：AIが自然な長さで応答できるようにする
      // 80文字制限は削除（アプリ側での強制制限なし）
      
      if (aiText.isNotEmpty && !_chatEnded && mounted) {
        print('処理後のAI応答: "$aiText"');
        
        // 会話中のメッセージを記録（ユーザー特徴抽出用）
        _allUserMessages.add(userText);
        _allAiResponses.add(aiText);
        
        // 会話データをFirestoreに保存
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await _conversationService.saveConversation(
            userId: userId,
            userText: userText,
            aiResponse: aiText,
            sessionId: _sessionId ?? 'zundamon_${DateTime.now().millisecondsSinceEpoch}',
          );
        }
        
        // 音声合成で再生（完了後に文字表示）
        await _speakAI(aiText);
        
        // 音声再生完了後に文字表示
        if (!_chatEnded && mounted) {
          setState(() {
            _aiResponseText = aiText;
          });
          
          // メッセージ履歴に追加
          _addMessage('AI', aiText);
        }
      } else {
        print('AI応答が空です');
        throw Exception('AI応答が空でした');
      }
    } catch (e) {
      print('AI応答生成エラー: $e');
      if (!_chatEnded && mounted) {
        setState(() {
          _aiResponseText = 'すまないのだ〜、よく聞こえなかったのだ。もう一度言ってもらえるかなのだ？';
        });
        await _speakAI(_aiResponseText);
        
        // プッシュトゥトークモード：自動再開を無効化
        // Future.delayed(const Duration(seconds: 1), () {
        //   if (mounted && !_chatEnded && !_isListening && !_isProcessing) {
        //     _startListening();
        //   }
        // });
      }
    } finally {
      if (!_chatEnded && mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        // プッシュトゥトークモード：自動再開を無効化
        _speechRetryCount = 0; // リトライカウントリセット
        // Future.delayed(const Duration(seconds: 2), () {
        //   if (mounted && !_chatEnded && !_isListening && !_isProcessing) {
        //     print('AI処理完了後の音声認識再開試行');
        //     _startListening();
        //   }
        // });
      }
    }
  }

  Future<void> _speakAI(String text) async {
    if (_chatEnded || _isSpeaking) {
      print('音声合成スキップ: _chatEnded=$_chatEnded, _isSpeaking=$_isSpeaking');
      return;
    }
    
    try {
      setState(() {
        _isSpeaking = true;
      });
      
      // VOICEVOXのみ使用（フォールバックなし）
      print('VOICEVOX音声合成開始: $text');
      
      // 現在の性格に対応するVOICEVOX話者を設定
      _voiceVoxService.setSpeakerByCharacter(widget.personalityId);
      
      // VOICEVOX Engine の可用性チェック
      final isEngineAvailable = await _voiceVoxService.isEngineAvailable();
      if (!isEngineAvailable) {
        print('VOICEVOX Engine利用不可：音声なしで継続');
        return;
      }
      
      // VOICEVOX音声合成実行
      final success = await _voiceVoxService.speak(text);
      if (!success) {
        print('VOICEVOX音声合成失敗：音声なしで継続');
      }
    } catch (e) {
      print('音声合成エラー: $e（音声なしで継続）');
    } finally {
      // 短時間での重複を防ぐため、少し待機してからフラグを解除
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  void _stopListening() {
    if (!_isListening) return;
    
    setState(() {
      _isListening = false;
    });
    
    _listeningController.stop();
    
    try {
      _speech.stop();
      print('音声認識停止');
    } catch (e) {
      print('音声認識停止エラー: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentThemeColor, // 動的テーマカラー（talk_to_ai_screen.dartから統合）
      appBar: AppBar(
        title: Text(
          '${_getPersonalityName(widget.personalityId)} AI チャット',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // 右にスクロールして戻る
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(-1.0, 0.0); // 右にスクロール
                  const end = Offset.zero;
                  const curve = Curves.ease;
                  final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  return SlideTransition(position: animation.drive(tween), child: child);
                },
              ),
            );
          },
        ),
      ),
      body: Column(
        children: [
          
          // AIアイコンとタイマー（talk_to_ai_screen.dartから統合）
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildGeminiIcon(),
                const SizedBox(height: 16),
                _buildTimer(),
              ],
            ),
          ),
          
          // チャット履歴エリア（talk_to_ai_screen.dartから統合）
          Expanded(child: _buildChatArea()),
          
          // 入力エリア（talk_to_ai_screen.dartから統合）
          Platform.isAndroid
              ? SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: _buildInputArea(),
                )
              : _buildInputArea(),
        ],
      ),
    );
  }

  // チャット履歴エリア（talk_to_ai_screen.dartから統合）
  Widget _buildChatArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _messages.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessage(_messages[index]);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E0F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: Color(0xFF4E3B7A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '会話を始めましょう！',
            style: GoogleFonts.notoSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4E3B7A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'メッセージ入力または音声で話しかけてください',
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isSystem = message.sender == 'システム';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSystem ? Colors.grey : const Color(0xFF4E3B7A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSystem ? Icons.info : Icons.smart_toy,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? Colors.blue.withOpacity(0.1)
                    : isSystem 
                        ? Colors.grey[200]
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: GoogleFonts.notoSans(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF4E3B7A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 入力エリア（push-to-talk対応）
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: _isInitialized && !_isLoading,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _isInitialized 
                    ? (_isListening 
                        ? '🎤 音声認識中...' 
                        : _isProcessing 
                            ? '🤖 AI思考中...' 
                            : 'メッセージを入力または長押しで音声...')
                    : '初期化中...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: _isInitialized && !_isLoading ? (_) => _sendMessage() : null,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isInitialized && !_isLoading 
                ? Colors.blue 
                : Colors.grey,
            child: IconButton(
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _isInitialized && !_isLoading ? _sendMessage : null,
            ),
          ),
          const SizedBox(width: 8),
          // プッシュトゥトーク音声ボタン
          GestureDetector(
            onTapDown: (_) {
              if (_isInitialized && !_isLoading && !_isProcessing) {
                _startListening();
              }
            },
            onTapUp: (_) {
              if (_isListening) {
                _stopListening();
              }
            },
            onTapCancel: () {
              if (_isListening) {
                _stopListening();
              }
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _isListening ? Colors.red : Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.red : Colors.green).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _bounceAnimation.value : 1.0,
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 終了ボタン
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _endChat,
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeminiIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _listeningAnimation, _bounceAnimation]),
      builder: (context, child) {
        // ベーススケール + バウンスアニメーションを組み合わせる
        final baseScale = _isListening 
            ? _pulseAnimation.value * _listeningAnimation.value
            : _pulseAnimation.value;
        final bounceScale = _bounceController.isAnimating ? _bounceAnimation.value : 1.0;
        final finalScale = baseScale * bounceScale;
        
        return Transform.scale(
          scale: finalScale,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                // 音声認識中の性格色キラキラエフェクト
                if (_isListening)
                  BoxShadow(
                    color: (_personalityData['backgroundColor'] as Color).withOpacity(0.5 + _soundLevel * 0.2),
                    blurRadius: 25 + (_soundLevel * 5),
                    spreadRadius: 8 + (_soundLevel * 2),
                  ),
                // AI処理中のオレンジ色エフェクト
                if (_isProcessing)
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
              ],
            ),
            child: ClipOval(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: _isListening 
                    ? _personalityData['backgroundColor'].withOpacity(0.3)
                    : _isProcessing
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.white,
                padding: const EdgeInsets.all(30),
                child: SvgPicture.asset(
                  _personalityData['icon'] ?? 'aseets/icons/Guy 1.svg',
                  fit: BoxFit.contain,
                  colorFilter: _isListening 
                      ? ColorFilter.mode(
                          _personalityData['backgroundColor'],
                          BlendMode.modulate,
                        )
                      : _isProcessing
                          ? ColorFilter.mode(
                              Colors.orange,
                              BlendMode.modulate,
                            )
                          : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _timerDisplay,
        style: GoogleFonts.notoSans(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _currentThemeColor,
        ),
      ),
    );
  }
}

// ChatMessage クラス（talk_to_ai_screen.dartから統合）
class ChatMessage {
  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isUser;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.isUser,
  });
}