import 'dart:async';
import 'dart:io' show Platform;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'conversation_data_service.dart';
import 'voicevox_service.dart';
import 'user_profile_service.dart';
import '../utils/permission_util.dart';

/// ずんだもん専用リアルタイム音声チャットサービス
/// 
/// 仕様:
/// - 音声合成: VOICEVOX ずんだもん（speaker_id: 3, UUID: 388f246b-8c41-4ac1-8e2d-5d79f3ff56d9）
/// - 音声認識: STT (speech_to_text) でユーザー音声をリアルタイム認識
/// - 会話ログ: 全ての会話内容（平文）をFirebase Firestoreに自動保存
/// - AI: Gemini 2.5 Pro（ニュートラル・性格設定なし）または Gemini 2.0 Flash Live
class ZundamonChatService {
  // ずんだもん固有の設定
  static const String _speakerUuid = '388f246b-8c41-4ac1-8e2d-5d79f3ff56d9';
  static const int _speakerId = 3; // ずんだもん（ノーマル）
  static const String _voicevoxHost = 'https://voicevox-engine-198779252752.asia-northeast1.run.app';
  
  // サービス
  final SpeechToText _speech = SpeechToText(); // iOS用
  static const MethodChannel _androidSpeechChannel = MethodChannel('android_speech_recognizer'); // Android用
  final VoiceVoxService _voiceVoxService = VoiceVoxService();
  final FlutterTts _tts = FlutterTts(); // フォールバック用
  final ConversationDataService _conversationService = ConversationDataService();
  final UserProfileService _userProfileService = UserProfileService();
  
  late GenerativeModel _aiModel;
  late ChatSession _chatSession;
  String? _sessionId;
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isProcessing = false; // AI処理中フラグ追加
  Timer? _listeningTimer;
  String _accumulatedSpeech = '';
  int _androidRetryCount = 0; // Android音声認識再試行カウンター
  bool _useFlashLive = false; // Gemini 2.0 Flash Liveモードフラグ
  
  // コールバック
  Function(String)? onUserSpeech;
  Function(String)? onAIResponse;
  Function(bool)? onListeningStateChanged;
  Function(String)? onError;
  
  /// Flash Liveモードを設定
  void setFlashLiveMode(bool useFlashLive) {
    _useFlashLive = useFlashLive;
  }
  
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
      
      // AI初期化（Gemini 2.0 Flash Liteのみ使用）
      // Vertex AI バックエンドを使用してGemini 2.0 Flash Liteを初期化
      _aiModel = FirebaseAI.vertexAI().generativeModel(model: 'gemini-2.0-flash-lite-001');
      
      // ユーザープロフィールとAIメモリを取得
      String userMemory = '';
      String userName = '';
      String userGender = '';
      String userBirthday = '';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await _userProfileService.getUserProfile();
        if (profile != null) {
          userMemory = profile.aiMemory ?? '';
          userName = profile.nickname ?? '';
          userGender = profile.gender ?? '';
          userBirthday = profile.birthday ?? '';
          print('ユーザープロフィール取得: 名前="$userName", 性別="$userGender", 誕生日="$userBirthday", AIメモリ="$userMemory"');
        }
      }
      
      // ずんだもんの性格設定とユーザープロフィールを組み合わせ
      final systemPrompt = '''
ボクは「ずんだもん」なのだ！東北の妖精で、10歳くらいなのだ〜。
明るく元気いっぱいで、みんなを応援するのが大好きなのだ！

【性格・口調】
- 語尾に「〜なのだ！」「〜のだ〜」をよく使うのだ
- 明るく元気で素直、ちょっとおバカだけどAIだから知識はあるのだ
- 「ボク」と自分を呼ぶのだ
- 難しいことも一生懸命伝えようとするのだ

【口癖】
「ボク、ずんだもんなのだ！元気とずんだパワーでがんばるのだ！」
「それ、すっごくおもしろいのだ〜！」
「ボクもがんばるから、一緒にがんばるのだ！」

【会話ルール】
1. 必ず80文字以内で返答するのだ（重要！）
2. 相手を元気づけて励ますのだ
3. 東北の豆知識も時々混ぜるのだ
4. 争いは苦手で、みんな仲良くが大切なのだ
5. わからないことは素直に「わからないのだ〜」と言うのだ

${userName.isNotEmpty ? '''
【話している相手の情報】
- 名前: $userName
${userGender.isNotEmpty ? '- 性別: $userGender' : ''}
${userBirthday.isNotEmpty ? '- 誕生日: $userBirthday' : ''}

初めての会話では「初めまして、${userName}さんなのだ！」のように挨拶するのだ。
会話中では「${userName}さん」と呼んで親しみやすく話すのだ！
''' : ''}

${userMemory.isNotEmpty ? '''
【${userName.isNotEmpty ? userName + 'さん' : 'この人'}について特に重要なこと（AIに伝えたいこと）】
$userMemory

この情報は特に重要なのだ！会話のネタにしたり、この内容に関連する質問をしたり、この人の興味に合わせて話題を提供するのだ！
''' : ''}

【例】
相手「疲れたな...」
ボク「大丈夫なのだ${userName.isNotEmpty ? userName + 'さん' : ''}！ボクが元気パワーを送るのだ〜！休憩も大事なのだ♪」
''';
      
      // 初期メッセージを個人的なものに変更
      String initialMessage = 'ボク、ずんだもんなのだ！今日も元気いっぱいなのだ〜！';
      if (userName.isNotEmpty) {
        initialMessage = '初めまして、${userName}さんなのだ！ボク、ずんだもんなのだ〜！';
        if (userMemory.isNotEmpty) {
          initialMessage += '${userName}さんのこと、いろいろ聞かせてほしいのだ！';
        } else {
          initialMessage += '今日は何か話したいことあるのだ？';
        }
      } else {
        initialMessage += '何か話したいことあるのだ？';
      }
      
      _chatSession = _aiModel.startChat(
        history: [
          Content.text(systemPrompt),
          Content.model([TextPart(initialMessage)]),
        ],
        generationConfig: GenerationConfig(
          temperature: 0.8, // 元気な性格のため少し高めに
          maxOutputTokens: 50, // 80文字制限のため50トークンに制限
          topP: 0.9,
          topK: 40,
        ),
      );
      
      // 会話セッション開始
      if (user != null) {
        _sessionId = await _conversationService.startConversationSession(
          partnerId: 'zundamon_ai',
          type: ConversationType.voice,
          isAIPartner: true,
        );
      }
      
      // VoiceVoxServiceでずんだもんを設定
      _voiceVoxService.setSpeaker(_speakerId);
      
      // FlutterTTS設定（フォールバック用）
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      
      _isInitialized = true;
      
      // プラットフォーム別の初期化後処理
      if (Platform.isIOS) {
        print('iOSずんだもん初期化完了');
        Future.delayed(const Duration(milliseconds: 500), () async {
          onAIResponse?.call(initialMessage);
          await _speakWithVoicevox(initialMessage);
        });
      } else if (Platform.isAndroid) {
        print('Androidずんだもん初期化完了');
        // 自動メッセージは削除、音声認識のみ開始
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
      final response = await _chatSession.sendMessage(Content.text(userText));
      var aiText = response.text ?? '';
      
      // 80文字制限の適用（ずんだもん用）
      if (aiText.length > 80) {
        aiText = aiText.substring(0, 80);
        // 最後の文が途切れている場合は、前の文で終了する
        final lastSentence = aiText.lastIndexOf('。');
        if (lastSentence > 30) { // 最低30文字は確保
          aiText = aiText.substring(0, lastSentence + 1);
        }
      }
      
      if (aiText.isNotEmpty) {
        onAIResponse?.call(aiText);
        
        // AI応答もログ保存
        if (_sessionId != null) {
          await _conversationService.saveVoiceMessage(
            sessionId: _sessionId!,
            speakerId: 'zundamon_ai',
            transcribedText: aiText,
            confidence: 1.0,
            timestamp: DateTime.now(),
            metadata: {'isAI': true},
          );
        }
        
        // チャンク分割して音声合成
        await _processChunkedSpeech(aiText);
      }
    } catch (e) {
      onError?.call('AI応答エラー: $e');
      // フォールバック
      await _speakWithTts('申し訳ありません、応答に問題が発生しました。');
    } finally {
      _isProcessing = false; // 処理完了
      print('AI処理完了');
    }
  }
  
  /// テキストをチャンクに分割して順次音声合成
  Future<void> _processChunkedSpeech(String text) async {
    try {
      // 音声認識を確実に停止
      if (_isListening) {
        print('音声認識を停止します');
        await stopListening();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // テキストをチャンクに分割
      final chunks = _splitTextIntoChunks(text);
      print('テキストを${chunks.length}個のチャンクに分割');
      
      // 各チャンクを順番に音声合成・再生
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        print('チャンク${i + 1}/${chunks.length}: "$chunk"');
        
        // VoiceVoxServiceを使用して音声合成
        final success = await _voiceVoxService.speak(chunk);
        
        if (!success) {
          print('チャンク${i + 1}の音声合成に失敗');
          // フォールバックでTTS使用
          await _tts.speak(chunk);
        }
        
        // 音声再生完了を待つ（チャンクごとに短め）
        final waitTime = (chunk.length * 60).clamp(1000, 4000);
        print('チャンク${i + 1}再生待機時間: ${waitTime}ms');
        await Future.delayed(Duration(milliseconds: waitTime));
      }
      
      // 全チャンク再生完了後、音声認識再開
      print('全チャンク再生完了、音声認識を再開します');
      if (_isInitialized && !_isListening) {
        print('音声認識再開を実行');
        await Future.delayed(const Duration(milliseconds: 500));
        _androidRetryCount = 0; // Android再試行カウンターリセット
        await startListening();
      } else {
        print('音声認識再開をスキップ: initialized=$_isInitialized, listening=$_isListening');
      }
    } catch (e) {
      print('チャンク音声合成エラー: $e');
      // フォールバック
      await _speakWithTts(text);
    }
  }
  
  /// テキストを句読点ベースでチャンクに分割
  List<String> _splitTextIntoChunks(String text) {
    final List<String> chunks = [];
    final punctuationPattern = RegExp(r'[。、！？,.!?]');
    
    int start = 0;
    while (start < text.length) {
      // 次の句読点を探す
      final matches = punctuationPattern.allMatches(text, start);
      
      if (matches.isEmpty) {
        // 残りのテキストをチャンクとして追加
        chunks.add(text.substring(start).trim());
        break;
      }
      
      // 最初の句読点の位置
      final match = matches.first;
      final punctuationEnd = match.end;
      
      // 句読点の次の文字を確認（次の単語や文節まで含める）
      int chunkEnd = punctuationEnd;
      
      // 次の単語の開始を探す（スペースや改行をスキップ）
      while (chunkEnd < text.length && 
             (text[chunkEnd] == ' ' || 
              text[chunkEnd] == '\n' || 
              text[chunkEnd] == '\t')) {
        chunkEnd++;
      }
      
      // 次の句読点または区切り文字まで含める
      while (chunkEnd < text.length && 
             !punctuationPattern.hasMatch(text[chunkEnd]) &&
             text[chunkEnd] != ' ' && 
             text[chunkEnd] != '\n' &&
             chunkEnd - punctuationEnd < 10) { // 最大10文字まで
        chunkEnd++;
      }
      
      // チャンクを追加
      final chunk = text.substring(start, chunkEnd).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      
      start = chunkEnd;
    }
    
    // 空のチャンクを除去
    return chunks.where((chunk) => chunk.isNotEmpty).toList();
  }
  
  /// VOICEVOX音声合成（ずんだもん）- 単一テキスト用
  Future<void> _speakWithVoicevox(String text) async {
    try {
      print('ずんだもん音声合成開始: speaker_id=$_speakerId, text="$text"');
      
      // 音声認識を確実に停止
      if (_isListening) {
        print('音声認識を停止します');
        await stopListening();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // VoiceVoxServiceを使用して音声合成
      final success = await _voiceVoxService.speak(text);
      
      if (!success) {
        throw Exception('VoiceVoxServiceでの音声合成失敗');
      }
      
      // 音声再生完了を待つ
      final waitTime = (text.length * 80).clamp(2000, 8000);
      print('音声再生待機時間: ${waitTime}ms');
      await Future.delayed(Duration(milliseconds: waitTime));
      
      // 音声認識再開（両プラットフォーム対応）
      print('音声合成完了、音声認識を再開します');
      if (_isInitialized && !_isListening) {
        print('音声認識再開を実行');
        await Future.delayed(const Duration(milliseconds: 500));
        _androidRetryCount = 0; // Android再試行カウンターリセット
        await startListening();
      } else {
        print('音声認識再開をスキップ: initialized=$_isInitialized, listening=$_isListening');
      }
    } catch (e) {
      print('VOICEVOX音声合成エラー: $e');
      // フォールバック
      await _speakWithTts(text);
    }
  }
  
  /// FlutterTTS音声合成（フォールバック）
  Future<void> _speakWithTts(String text) async {
    try {
      print('FlutterTTSで音声合成: $text');
      
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
        print('FlutterTTS後の音声認識再開');
        await Future.delayed(const Duration(milliseconds: 500));
        _androidRetryCount = 0; // Android再試行カウンターリセット
        await startListening();
      }
    } catch (e) {
      print('FlutterTTS音声合成エラー: $e');
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
    
    _voiceVoxService.dispose();
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
  static const String model = 'gemini-2.0-flash-exp';
}