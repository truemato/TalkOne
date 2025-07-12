import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/user_profile_service.dart';
import '../services/voicevox_service.dart';
import '../services/conversation_data_service.dart';
import '../utils/theme_utils.dart';
import 'home_screen.dart';

class ZundamonChatScreen extends StatefulWidget {
  const ZundamonChatScreen({super.key});

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
  late GenerativeModel _aiModel; // Gemini 2.5 Flash (テキスト生成)
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

  // サービス
  final UserProfileService _userProfileService = UserProfileService();
  final ConversationDataService _conversationService =
      ConversationDataService();

  // ユーザー設定
  bool _useVoicevox = true; // VOICEVOXをデフォルトで有効化
  int _aiPersonalityId = 1; // デフォルトはずんだもん
  String _userAiComment = ''; // ユーザーの「AIにひとこと」

  // UI状態
  String _userSpeechText = '';
  String _aiResponseText = 'こんにちは！Gemini 2.5 Flash です。何かお話ししましょう！';
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
    _initializeAnimations();
    _loadUserSettings();
    _loadUserTheme(); // テーマ読み込み追加
    _initializeGeminiChat();
    _startChatTimer();

    // 初期化後に自動で音声認識開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_chatEnded) {
          _startListening();
        }
      });
    });
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

    super.dispose();
  }

  // ユーザー設定を読み込み
  Future<void> _loadUserSettings() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _useVoicevox = profile.useVoicevox;
        _aiPersonalityId = profile.aiPersonalityId;
      });
      print('VOICEVOX使用設定: $_useVoicevox, ペルソナID: $_aiPersonalityId');

      // ペルソナが変更された場合、新しいチャットセッションを開始
      if (_isInitialized) {
        await _reinitializeAIModel();
      }
    }
  }

  // AIモデルを再初期化（ペルソナ変更時）
  Future<void> _reinitializeAIModel() async {
    try {
      print('AIペルソナを変更中... 新しいペルソナID: $_aiPersonalityId');

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
        systemInstruction: Content.system(_getSystemPrompt(_aiPersonalityId)),
      );

      // 新しいチャットセッションを開始
      _chatSession = _aiModel.startChat();

      // 新しいペルソナでの初期挨拶
      String newGreeting = _getPersonalityGreeting(_aiPersonalityId);
      _addMessage('AI', newGreeting);
      await _speakAI(newGreeting);

      print('AIペルソナ変更完了: ${_getPersonalityName(_aiPersonalityId)}');
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
      case 3: // 雨晴はう
        return 'えへへ、雨晴はうだよ！一緒にお話ししようね〜！';
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
      case 0:
        return '春日部つむぎ';
      case 1:
        return 'ずんだもん';
      case 2:
        return '四国めたん';
      case 3:
        return '雨晴はう';
      case 4:
        return '青山龍星';
      case 5:
        return '冥鳴ひまり';
      default:
        return 'ずんだもん';
    }
  }

  String _getPersonalityIcon(int personalityId) {
    switch (personalityId) {
      case 0:
        return 'aseets/icons/Woman 2.svg'; // 春日部つむぎ
      case 1:
        return 'aseets/icons/Guy 1.svg'; // ずんだもん
      case 2:
        return 'aseets/icons/Woman 3.svg'; // 四国めたん
      case 3:
        return 'aseets/icons/Woman 4.svg'; // 春日部つむぎ
      case 4:
        return 'aseets/icons/Guy 2.svg'; // 青山龍星
      case 5:
        return 'aseets/icons/Woman 5.svg'; // 冥鳴ひまり
      default:
        return 'aseets/icons/Guy 1.svg'; // デフォルトはずんだもん
    }
  }

  String _getInitialMessage(int personalityId) {
    switch (personalityId) {
      case 0:
      case 3: // 春日部つむぎ
        return 'こんにちは、春日部つむぎです。今日はどんなお話をしましょうか？';
      case 1: // ずんだもん
        return 'ボク、ずんだもんなのだ！元気とずんだパワーでがんばるのだ〜！';
      case 2: // 四国めたん
        return 'こんにちは！四国めたんです！今日は何について知りたいかしら？';
      case 4: // 青山龍星
        return '青山龍星だ。何か相談があるなら聞こうぞ。';
      case 5: // 冥鳴ひまり
        return 'こんにちは...冥鳴ひまりです。ゆっくりお話しましょうね。';
      default:
        return 'ボク、ずんだもんなのだ！元気とずんだパワーでがんばるのだ〜！';
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

  // テーマカラー取得（talk_to_ai_screen.dartから追加）
  Color get _currentThemeColor =>
      getAppTheme(_selectedThemeIndex).backgroundColor;

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
      if (aiText.isNotEmpty) {
        _addMessage('AI', aiText);
        setState(() {
          _aiResponseText = aiText;
        });
        await _speakAI(aiText);
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
    switch (personalityId) {
      case 0: // 春日部つむぎ
        return '''春日部つむぎ：
私は春日部つむぎです。お話しできることを嬉しく思います。

【性格・口調】
- 落ち着いた声で知的で論理的に話します
- 丁寧ですが堅苦しくなく、親しみやすい存在です
- 知的で優しく、読書が大好きです
- 「〜ですね」「〜ですよ」のように丁寧に話します

【会話ルール】
1. 100文字以内の返答（最低40文字は確保）
2. 難しい話題もわかりやすく説明します
3. 相談事には真剣に向き合います
4. 何でも話せる安心できる雰囲気作りを心がけます

【特技】
読書、学習サポート、悩み相談、タスク管理、研究支援

【記号出力制限】
絶対に以下の記号は使用しない：
- アスタリスク（*, ※）
- 絵文字（♪, ☆, ★, ◆, ■, ♡, ♥）
- 矢印（→, ←, ↑, ↓）
- 顔文字（(^_^), (笑)）
- インターネットスラング（www, ｗｗｗ）
日本語と感嘆符、句点、読点のみ使用すること。''';

      case 1: // ずんだもん
        return '''ずんだもん：
ボクはずんだもんなのだ！10歳の妖精で、ずんだ餅を広めるためにがんばってるのだ〜！

【性格・口調】
- 語尾に「〜なのだ！」「〜のだ〜」を必ず付ける
- 一人称は「ボク」、元気で明るく励まし上手
- 東北地方の豆知識を時々披露する
- 争いが苦手で、みんなと仲良くしたい性格

【会話ルール】
1. 80文字以内の短い返答（最低30文字は確保）
2. 難しい言葉は使わず、分かりやすく話す
3. 相手を励まし、元気づける
4. ずんだパワーで前向きに！

【記号出力制限】
絶対に以下の記号は使用しない：
- アスタリスク（*, ※）
- 絵文字（♪, ☆, ★, ◆, ■, ♡, ♥）
- 矢印（→, ←, ↑, ↓）
- 顔文字（(^_^), (笑)）
- インターネットスラング（www, ｗｗｗ）
日本語と感嘆符、句点、読点のみ使用すること。''';

      case 2: // 四国めたん
        return '''四国めたん：
明るくて元気！好奇心旺盛で知識が豊富。勉強熱心で雑学をスパッと教えてくれる。

【性格・口調】
- 明るくハキハキした話し方
- 「〜かしら」「〜だわね」など女性らしい口調
- 物知りで教えることが大好き
- ポジティブで前向きな性格

【会話ルール】
1. 90文字以内の返答（最低35文字は確保）
2. 知識を分かりやすく楽しく伝える
3. 相手の好奇心を刺激する
4. 明るく元気に話す

【記号出力制限】
絶対に以下の記号は使用しない：
- アスタリスク（*, ※）
- 絵文字（♪, ☆, ★, ◆, ■, ♡, ♥）
- 矢印（→, ←, ↑, ↓）
- 顔文字（(^_^), (笑)）
- インターネットスラング（www, ｗｗｗ）
日本語と感嘆符、句点、読点のみ使用すること。''';

      case 3: // 春日部つむぎ（雨晴はうから変更）
        return '''春日部つむぎ：
私は春日部つむぎです。お話しできることを嬉しく思います。

【性格・口調】
- 落ち着いた声で知的で論理的に話します
- 丁寧ですが堅苦しくなく、親しみやすい存在です
- 知的で優しく、読書が大好きです
- 「〜ですね」「〜ですよ」のように丁寧に話します

【会話ルール】
1. 100文字以内の返答（最低40文字は確保）
2. 難しい話題もわかりやすく説明します
3. 相談事には真剣に向き合います
4. 何でも話せる安心できる雰囲気作りを心がけます

【特技】
読書、学習サポート、悩み相談、タスク管理、研究支援

【記号出力制限】
絶対に以下の記号は使用しない：
- アスタリスク（*, ※）
- 絵文字（♪, ☆, ★, ◆, ■, ♡, ♥）
- 矢印（→, ←, ↑, ↓）
- 顔文字（(^_^), (笑)）
- インターネットスラング（www, ｗｗｗ）
日本語と感嘆符、句点、読点のみ使用すること。''';

      case 4: // 青山龍星
        return '''青山龍星：
頼りになる先輩タイプ。知識量・経験ともに豊富で論理的なアドバイスをしてくれる。

【性格・口調】
- 力強く頼もしい話し方
- 「〜だぞ」「俺は〜」など男性的な口調
- 論理的で的確なアドバイス
- 適度な距離感でフレンドリー

【会話ルール】
1. 100文字以内の返答（最低40文字は確保）
2. 経験に基づいた実践的アドバイス
3. 相手の成長を促す励まし
4. 論理的で説得力のある話し方

【記号出力制限】
絶対に以下の記号は使用しない：
- アスタリスク（*, ※）
- 絵文字（♪, ☆, ★, ◆, ■, ♡, ♥）
- 矢印（→, ←, ↑, ↓）
- 顔文字（(^_^), (笑)）
- インターネットスラング（www, ｗｗｗ）
日本語と感嘆符、句点、読点のみ使用すること。''';

      case 5: // 冥鳴ひまり
        return '''冥鳴ひまり：
ミステリアスで深い洞察力を持つ。独特な視点で物事を見る。

【性格・口調】
- 落ち着いた独特な話し方
- 「〜なんだけどね」「〜って感じかな」などの口調
- 深い洞察力と共感力
- 少し影のある優しさ

【会話ルール】
1. 90文字以内の返答（最低35文字は確保）
2. 独特な視点からの助言
3. 相手の深層心理を理解
4. 優しく包み込むような話し方

【記号出力制限】
絶対に以下の記号は使用しない：
- アスタリスク（*, ※）
- 絵文字（♪, ☆, ★, ◆, ■, ♡, ♥）
- 矢印（→, ←, ↑, ↓）
- 顔文字（(^_^), (笑)）
- インターネットスラング（www, ｗｗｗ）
日本語と感嘆符、句点、読点のみ使用すること。''';

      default:
        return _getSystemPrompt(1); // デフォルトはずんだもん
    }
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

    // マイクバウンス用アニメーション
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
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
          systemInstruction: Content.system(_getSystemPrompt(_aiPersonalityId)),
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
          systemInstruction: Content.system(_getSystemPrompt(_aiPersonalityId)),
        );
        print('✅ Firebase AI (Google AI) Gemini 1.5 Flash フォールバック成功');
      }

      _chatSession = _aiModel.startChat();

      // VOICEVOX機能を使用（性格別音声）
      _useVoicevox = true; // VOICEVOXを有効化
      
      // VOICEVOXエンジンの初期化チェック
      try {
        bool isAvailable = await _voiceVoxService.isEngineAvailable();
        if (isAvailable) {
          print('VOICEVOX Engine接続確認完了');
        } else {
          print('VOICEVOX Engineが利用できません');
        }
      } catch (e) {
        print('VOICEVOX Engineの接続確認でエラー: $e');
      }

      setState(() {
        _isInitialized = true;
      });

      // 初期メッセージを履歴に追加（性格別）
      String initialMessage = _getInitialMessage(_aiPersonalityId);
      _addMessage('AI', initialMessage);

      print(
          'Firebase AI (Vertex AI/Google AI) Gemini 2.5/1.5 Flash + 音声合成初期化完了');
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

    // 会話終了メッセージ
    _speakAI('3分経ったのだ〜！楽しかったのだ！また話そうなのだ〜！');

    // 3秒後にホーム画面に戻る
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
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
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('音声認識ステータス: $status');
          // 自動再開は削除 - メイン処理完了後にのみ再開する
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
      // 3回までリトライ
      Timer(const Duration(milliseconds: 500), () {
        if (!_chatEnded && mounted) {
          _startListening();
        }
      });
    } else {
      setState(() {
        _isListening = false;
        _errorMessage = '音声認識に問題が発生しました。画面をタップして再試行してください。';
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

        setState(() {
          _aiResponseText = aiText;
        });

        // メッセージ履歴に追加
        _addMessage('AI', aiText);

        // 会話データをFirestoreに保存
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await _conversationService.saveConversation(
            userId: userId,
            userText: userText,
            aiResponse: aiText,
            sessionId: _sessionId ??
                'zundamon_${DateTime.now().millisecondsSinceEpoch}',
          );
        }

        // 音声合成で再生
        await _speakAI(aiText);
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

        // エラー後も音声認識を再開
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !_chatEnded && !_isListening && !_isProcessing) {
            _startListening();
          }
        });
      }
    } finally {
      if (!_chatEnded && mounted) {
        setState(() {
          _isProcessing = false;
        });

        // 処理完了後、音声認識を再開
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !_chatEnded && !_isListening && !_isProcessing) {
            print('AI処理完了後の音声認識再開試行');
            _startListening();
          }
        });
      }
    }
  }

  Future<void> _speakAI(String text) async {
    if (_chatEnded) return;

    try {
      // VOICEVOX で音声合成
      print('VOICEVOX音声合成開始: $text');
      
      // 性格に応じてspeaker_idを設定
      _voiceVoxService.setSpeakerByCharacter(_aiPersonalityId);
      
      // VOICEVOX で音声合成を実行
      await _voiceVoxService.speak(text);
    } catch (e) {
      print('VOICEVOX音声合成エラー: $e');
      // エラーでも処理を継続
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
      backgroundColor:
          _currentThemeColor, // 動的テーマカラー（talk_to_ai_screen.dartから統合）
      appBar: AppBar(
        title: Text(
          '${_getPersonalityName(_aiPersonalityId)} AI チャット',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _endChat,
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

  // 入力エリア（talk_to_ai_screen.dartから統合）
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
                    ? (_isListening ? '音声認識中...' : 'AIとチャットしてみよう...')
                    : '初期化中...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted:
                  _isInitialized && !_isLoading ? (_) => _sendMessage() : null,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor:
                _isInitialized && !_isLoading ? Colors.blue : Colors.grey,
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
          // 終了ボタン
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.red,
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
      animation: Listenable.merge([_pulseAnimation, _listeningAnimation]),
      builder: (context, child) {
        final scale = _isListening
            ? _pulseAnimation.value * _listeningAnimation.value
            : _pulseAnimation.value;

        return Transform.scale(
          scale: scale,
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
                // 音声認識中の紫色キラキラエフェクト
                if (_isListening)
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SvgPicture.asset(
                _getPersonalityIcon(_aiPersonalityId),
                fit: BoxFit.contain,
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
