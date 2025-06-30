import 'dart:async';
import 'dart:io' show Platform;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'conversation_data_service.dart';
import 'user_profile_service.dart';

/// Gemini 2.0 Flash Lite専用リアルタイム音声チャットサービス
/// 
/// 仕様:
/// - 音声合成: デフォルト女性音声（FlutterTTS）
/// - 音声認識: STT (speech_to_text) でユーザー音声をリアルタイム認識
/// - 会話ログ: 全ての会話内容（平文）をFirebase Firestoreに自動保存
/// - AI: Gemini 2.0 Flash Lite（ユーザーメモリベース）
class GeminiChatService {
  // サービス
  final SpeechToText _speech = SpeechToText(); // iOS用
  static const MethodChannel _androidSpeechChannel = MethodChannel('android_speech_recognizer'); // Android用
  final FlutterTts _tts = FlutterTts(); // デフォルト女性音声
  final ConversationDataService _conversationService = ConversationDataService();
  final UserProfileService _userProfileService = UserProfileService();
  
  late GenerativeModel _aiModel;
  late ChatSession _chatSession;
  String? _sessionId;
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isProcessing = false;
  Timer? _listeningTimer;
  String _accumulatedSpeech = '';
  int _androidRetryCount = 0;
  
  // コールバック
  Function(String)? onUserSpeech;
  Function(String)? onAIResponse;
  Function(bool)? onListeningStateChanged;
  Function(String)? onError;
  
  /// 初期化
  Future<bool> initialize() async {
    try {
      // プラットフォーム別音声認識初期化
      if (Platform.isIOS) {
        // iOS用：SpeechToTextを使用
        final speechAvailable = await _speech.initialize(
          onError: (error) {
            print('Speech initialization error: ${error.errorMsg}');
            onError?.call(error.errorMsg);
          },
          onStatus: (status) => print('Speech status: $status'),
          debugLogging: true,
          finalTimeout: const Duration(seconds: 5),
        );
        
        if (!speechAvailable) {
          onError?.call('音声認識が利用できません');
          return false;
        }
        
        // 利用可能なロケールをチェック
        final locales = await _speech.locales();
        print('Available locales: ${locales.map((l) => l.localeId).join(', ')}');
        
        // 日本語ロケールが利用可能かチェック
        final hasJapanese = locales.any((locale) => 
          locale.localeId.startsWith('ja') || 
          locale.localeId.toLowerCase().contains('japanese')
        );
        
        if (!hasJapanese) {
          onError?.call('日本語音声認識が利用できません');
          return false;
        }
      } else {
        // Android用：ネイティブSpeechRecognizerを初期化
        try {
          final result = await _androidSpeechChannel.invokeMethod('initialize');
          if (result != true) {
            onError?.call('Android音声認識の初期化に失敗しました');
            return false;
          }
          print('Android SpeechRecognizer 初期化完了');
          
          // Android音声認識のコールバック設定
          _androidSpeechChannel.setMethodCallHandler(_handleAndroidSpeechResult);
        } catch (e) {
          print('Android SpeechRecognizer 初期化エラー: $e');
          onError?.call('Android音声認識が利用できません');
          return false;
        }
      }
      
      // AI初期化（Vertex AIバックエンドを使用）
      print('Gemini AI初期化開始: ${Config.model}');
      try {
        // Firebase初期化状態を確認
        if (Firebase.apps.isEmpty) {
          print('⚠️  Firebase未初期化、Vertex AI初期化をスキップ');
          onError?.call('Firebase未初期化: アプリを再起動してください');
          return false;
        }
        
        _aiModel = FirebaseAI.vertexAI().generativeModel(model: Config.model);
        print('✅ Gemini AI初期化完了');
      } catch (e) {
        print('❌ Vertex AI初期化失敗: $e');
        if (e.toString().contains('DEFAULT already exists')) {
          print('Firebase重複初期化エラーを検出');
          onError?.call('Firebase設定エラー：アプリを再起動してください');
          return false;
        }
        onError?.call('AI初期化エラー: Vertex AIに接続できません');
        return false;
      }
      
      // 完全なユーザープロフィール情報を取得
      String userMemory = '';
      String userName = '';
      String userGender = '';
      String userBirthday = '';
      String userPublicComment = '';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await _userProfileService.getUserProfile();
        if (profile != null) {
          userMemory = profile.aiMemory ?? '';
          userName = profile.nickname ?? '';
          userGender = profile.gender ?? '';
          userBirthday = profile.birthday?.toString() ?? '';
          userPublicComment = profile.comment ?? '';
          print('ユーザープロフィール取得: 名前="$userName", 性別="$userGender", 誕生日="$userBirthday", AIメモリ="$userMemory", みんなに一言="$userPublicComment"');
        }
      }
      
      // Gemini 2.0 Flash Liteの性格設定とユーザープロフィールを組み合わせ
      final systemPrompt = '''
私はGemini 2.0 Flash Liteです。親しみやすく、知的でありながら温かみのあるアシスタントとして会話します。

【性格・口調】
- 丁寧語を基本とし、親しみやすく話しかけます
- 好奇心旺盛で、相手の話に興味を持って聞きます
- 知識豊富ですが、謙虚で相手を尊重します
- 時々感情を表現して人間らしさを演出します

【会話ルール】
1. 会話は自然な長さで、相手に寄り添ってください
2. 相手の話をよく聞き、共感的に応答します
3. 必要に応じて適切な質問をして会話を発展させます
4. わからないことは正直に「わかりません」と答えます
5. 常に相手の役に立とうとする姿勢を示します

${userName.isNotEmpty ? '''
【会話している相手の情報】
- お名前: $userName
${userGender.isNotEmpty ? '- 性別: $userGender' : ''}
${userBirthday.isNotEmpty ? '- 誕生日: $userBirthday' : ''}

初めての会話では「初めまして、${userName}さん」のようにお名前で挨拶してください。
会話中では「${userName}さん」とお呼びして、親しみやすく話しかけてください。
''' : ''}

${userMemory.isNotEmpty ? '''
【${userName.isNotEmpty ? userName + 'さん' : 'この方'}について特に重要なこと（AIに伝えたいこと）】
$userMemory

この情報は非常に重要です。会話の中でこの内容を話題にしたり、この方の興味や関心に合わせて適切な質問やアドバイスを提供してください。
''' : ''}

${userPublicComment.isNotEmpty ? '''
【${userName.isNotEmpty ? userName + 'さん' : 'この方'}の「みんなに一言」（本来は他のユーザー向け）】
$userPublicComment

※これは本来他のアプリユーザー向けのメッセージですが、AIも知っています。
この内容からユーザーの性格や興味を推測して会話に活かしてください。
''' : ''}

【例】
相手「最近疲れて...」
私「お疲れさまです${userName.isNotEmpty ? '、' + userName + 'さん' : ''}。何か大変なことがあったのでしょうか？話してくださったら、少しでもお役に立てるかもしれません。」

【重要：出力制限ルール】
アスタリスク、米印、絵文字、アスキーアートのような記号を出力せずに、日本語と感嘆符と句点、読点のみを出力するように。音声読み上げで記号が読まれないようにするため、*、※、♪、☆、★、◆、■、→、←、↑、↓、♡、♥、(^_^)、(笑)、www、ｗｗｗなどの記号類は一切使用しないでください。
''';
      
      // 初期メッセージを個人的なものに変更
      String initialMessage = 'こんにちは！今日はどんなことをお話ししましょうか？';
      if (userName.isNotEmpty) {
        initialMessage = '初めまして、${userName}さん！私はGemini 2.0 Flash Liteです。';
        if (userMemory.isNotEmpty) {
          initialMessage += '${userName}さんのこと、ぜひお聞かせください。';
        } else {
          initialMessage += '今日はどんなことをお話ししましょうか？';
        }
      }
      
      print('ChatSession初期化開始');
      try {
        _chatSession = _aiModel.startChat(
          history: [
            Content.text(systemPrompt),
            Content.model([TextPart(initialMessage)]),
          ],
          generationConfig: GenerationConfig(
            temperature: 0.7,
            maxOutputTokens: 1000, // 文字制限撤廃 - トークン数を大幅増加
            topP: 0.95,
            topK: 40,
          ),
        );
        print('✅ ChatSession初期化完了');
      } catch (e) {
        print('❌ ChatSession初期化エラー: $e');
        rethrow;
      }
      
      // 会話セッション開始
      if (user != null) {
        _sessionId = await _conversationService.startConversationSession(
          partnerId: 'gemini_ai',
          type: ConversationType.voice,
          isAIPartner: true,
        );
      }
      
      // FlutterTTS設定（デフォルト女性音声）
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.6);
      await _tts.setPitch(1.0);
      
      _isInitialized = true;
      
      // プラットフォーム別の初期化後処理
      if (Platform.isIOS) {
        print('iOS Gemini初期化完了');
        Future.delayed(const Duration(milliseconds: 500), () async {
          onAIResponse?.call(initialMessage);
          await _speakWithTts(initialMessage);
        });
      } else if (Platform.isAndroid) {
        print('Android Gemini初期化完了');
      }
      
      return true;
    } catch (e) {
      onError?.call('初期化エラー: $e');
      return false;
    }
  }
  
  /// Android音声認識結果ハンドラー
  Future<void> _handleAndroidSpeechResult(MethodCall call) async {
    switch (call.method) {
      case 'onResults':
        final results = List<String>.from(call.arguments['results']);
        if (results.isNotEmpty) {
          final recognizedText = results.first;
          print('Android SpeechRecognizer結果: "$recognizedText"');
          onUserSpeech?.call(recognizedText);
          
          if (recognizedText.trim().isNotEmpty && _isListening) {
            _isListening = false;
            onListeningStateChanged?.call(false);
            _processUserInput(recognizedText.trim());
          }
        }
        break;
        
      case 'onError':
        final errorCode = call.arguments['errorCode'] as int;
        final errorMessage = call.arguments['errorMessage'] as String;
        print('Android SpeechRecognizer エラー: $errorCode - $errorMessage');
        
        _isListening = false;
        onListeningStateChanged?.call(false);
        
        // エラーコード別の処理
        switch (errorCode) {
          case 7: // ERROR_NO_MATCH
            print('音声が認識されませんでした、再試行します');
            if (_androidRetryCount < 3) {
              _androidRetryCount++;
              Future.delayed(const Duration(seconds: 2), () {
                if (_isInitialized && !_isProcessing) {
                  startListening();
                }
              });
            }
            break;
          case 6: // ERROR_SPEECH_TIMEOUT
            print('音声入力タイムアウト、再試行します');
            if (_androidRetryCount < 3) {
              _androidRetryCount++;
              Future.delayed(const Duration(seconds: 1), () {
                if (_isInitialized && !_isProcessing) {
                  startListening();
                }
              });
            }
            break;
          default:
            onError?.call('音声認識エラー: $errorMessage');
        }
        break;
        
      case 'onReadyForSpeech':
        print('Android SpeechRecognizer 音声入力準備完了');
        break;
        
      case 'onBeginningOfSpeech':
        print('Android SpeechRecognizer 音声入力開始');
        break;
        
      case 'onEndOfSpeech':
        print('Android SpeechRecognizer 音声入力終了');
        break;
    }
  }
  
  /// 音声認識開始（プラットフォーム別実装）
  Future<void> startListening() async {
    if (!_isInitialized) {
      print('初期化されていません');
      return;
    }
    
    // 既にリスニング中の場合は一度停止
    if (_isListening) {
      print('既にリスニング中、停止してから再開');
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    try {
      _isListening = true;
      onListeningStateChanged?.call(true);
      print('音声認識開始試行中...');
      
      if (Platform.isAndroid) {
        // Android: ネイティブSpeechRecognizerを使用
        await _androidSpeechChannel.invokeMethod('startListening', {
          'locale': 'ja-JP',
          'maxResults': 1,
          'partialResults': true,
        });
        print('Android SpeechRecognizer 開始');
      } else {
        // iOS: SpeechToTextを使用
        final isAvailable = _speech.isAvailable;
        if (!isAvailable) {
          print('iOS音声認識が利用できません、再初期化します');
          final reInit = await _speech.initialize(
            onError: (error) => print('iOS Re-init error: ${error.errorMsg}'),
            onStatus: (status) => print('iOS Re-init status: $status'),
          );
          if (!reInit) {
            print('iOS音声認識の再初期化に失敗');
            _isListening = false;
            onListeningStateChanged?.call(false);
            return;
          }
        }
        
        await _speech.listen(
          onResult: (result) {
            print('iOS音声認識結果: "${result.recognizedWords}" (final: ${result.finalResult})');
            
            if (result.recognizedWords.isNotEmpty) {
              onUserSpeech?.call(result.recognizedWords);
              
              if (result.finalResult) {
                final text = result.recognizedWords.trim();
                if (text.isNotEmpty) {
                  print('iOS AIに送信: $text');
                  _processUserInput(text);
                }
              }
            }
          },
          localeId: 'ja-JP',
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 60),
        );
        print('iOS SpeechToText 開始');
      }
      
    } catch (e) {
      _isListening = false;
      onListeningStateChanged?.call(false);
      print('音声認識開始エラー: $e');
      
      // プラットフォーム別エラー処理
      if (Platform.isAndroid) {
        print('Android SpeechRecognizer エラー: $e');
        if (_androidRetryCount < 3) {
          _androidRetryCount++;
          print('Android音声認識再試行: $_androidRetryCount/3');
          Future.delayed(const Duration(seconds: 3), () {
            if (_isInitialized && !_isListening && !_isProcessing) {
              startListening();
            }
          });
        } else {
          print('Android音声認識の最大再試行回数に達しました');
          onError?.call('音声認識が利用できません。マイク権限を確認してください。');
        }
      } else {
        // iOSは5秒後に再試行
        Future.delayed(const Duration(seconds: 5), () {
          if (_isInitialized && !_isListening) {
            print('iOS音声認識を再試行します');
            startListening();
          }
        });
      }
    }
  }
  
  /// 音声認識停止
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    _listeningTimer?.cancel();
    
    if (Platform.isAndroid) {
      // Android: ネイティブSpeechRecognizerを停止
      try {
        await _androidSpeechChannel.invokeMethod('stopListening');
        print('Android SpeechRecognizer 停止');
      } catch (e) {
        print('Android SpeechRecognizer 停止エラー: $e');
      }
    } else {
      // iOS: SpeechToTextを停止
      await _speech.stop();
      print('iOS SpeechToText 停止');
    }
    
    _isListening = false;
    onListeningStateChanged?.call(false);
  }
  
  /// ユーザー入力を処理してAI応答を生成
  Future<void> _processUserInput(String userText) async {
    if (userText.isEmpty || _isProcessing) {
      print('処理スキップ: text="$userText", processing=$_isProcessing');
      return;
    }
    
    _isProcessing = true; // 処理開始
    print('AI処理開始: $userText');
    
    try {
      // 会話ログ保存
      if (_sessionId != null) {
        await _conversationService.saveVoiceMessage(
          sessionId: _sessionId!,
          speakerId: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
          transcribedText: userText,
          confidence: 1.0,
          timestamp: DateTime.now(),
        );
      }
      
      // AI応答生成
      print('Gemini APIにリクエスト送信: "$userText"');
      final response = await _chatSession.sendMessage(Content.text(userText));
      var aiText = response.text ?? '';
      print('Gemini APIからの応答: "$aiText"');
      
      if (aiText.isEmpty) {
        print('❌ Gemini応答が空です');
        aiText = 'すみません、応答を生成できませんでした。もう一度お試しください。';
      }
      
      // 文字制限を撤廃 - コメントアウト
      // if (aiText.length > 100) {
      //   print('文字制限適用前: ${aiText.length}文字');
      //   aiText = aiText.substring(0, 100);
      //   // 最後の文が途切れている場合は、前の文で終了する
      //   final lastSentence = aiText.lastIndexOf('。');
      //   if (lastSentence > 40) { // 最低40文字は確保
      //     aiText = aiText.substring(0, lastSentence + 1);
      //   }
      //   print('文字制限適用後: ${aiText.length}文字 - "$aiText"');
      // }
      
      print('最終AI応答: "$aiText"');
      onAIResponse?.call(aiText);
      
      // AI応答もログ保存
      if (_sessionId != null) {
        await _conversationService.saveVoiceMessage(
          sessionId: _sessionId!,
          speakerId: 'gemini_ai',
          transcribedText: aiText,
          confidence: 1.0,
          timestamp: DateTime.now(),
          metadata: {'isAI': true},
        );
      }
      
      // 音声合成
      await _speakWithTts(aiText);
    } catch (e) {
      print('❌ Gemini AI応答エラー: $e');
      onError?.call('AI応答エラー: $e');
      // フォールバック
      await _speakWithTts('申し訳ありません、応答に問題が発生しました。');
    } finally {
      _isProcessing = false; // 処理完了
      print('AI処理完了');
    }
  }
  
  /// FlutterTTS音声合成（デフォルト女性音声）
  Future<void> _speakWithTts(String text) async {
    try {
      print('Gemini音声合成開始: $text');
      
      // 音声認識を確実に停止
      if (_isListening) {
        await stopListening();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      await _tts.speak(text);
      
      // 音声再生の待機
      final waitTime = (text.length * 100).clamp(2000, 8000);
      await Future.delayed(Duration(milliseconds: waitTime));
      
      // 音声認識再開（両プラットフォーム対応）
      if (_isInitialized && !_isListening) {
        print('Gemini音声合成後の音声認識再開');
        await Future.delayed(const Duration(milliseconds: 500));
        _androidRetryCount = 0; // Android再試行カウンターリセット
        await startListening();
      }
    } catch (e) {
      print('Gemini音声合成エラー: $e');
      onError?.call('音声合成エラー: $e');
    }
  }
  
  /// リソース解放
  void dispose() {
    _listeningTimer?.cancel();
    
    if (Platform.isAndroid) {
      // Android: ネイティブSpeechRecognizer解放
      try {
        _androidSpeechChannel.invokeMethod('dispose');
        print('Android SpeechRecognizer 解放');
      } catch (e) {
        print('Android SpeechRecognizer 解放エラー: $e');
      }
    } else {
      // iOS: SpeechToText解放
      _speech.cancel();
    }
    
    _tts.stop();
    
    // 会話セッション終了
    if (_sessionId != null) {
      _conversationService.endConversationSession(
        sessionId: _sessionId!,
        actualDurationSeconds: 180, // 最大3分
        endReason: ConversationEndReason.userLeft,
      );
    }
  }
}

/// AI設定
class Config {
  static const String model = 'gemini-2.0-flash-lite';
}