import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_ai/firebase_ai.dart';
import 'voicevox_service.dart';
import 'conversation_data_service.dart';
import '../config/gemini_config.dart';

/// 四国めたん専用リアルタイム音声チャットサービス
/// 
/// STT → Gemini → VOICEVOX四国めたん → 音声再生の完全パイプライン
/// 全ての会話内容をFirebaseに自動保存
class ShikokuMetanChatService {
  static const String _shikokuMetanSpeakerId = '2'; // 四国めたん ノーマル
  static const String _shikokuMetanUuid = '7ffcb7ce-00ec-4bdc-82cd-45a8889e43ff';
  
  late stt.SpeechToText _speechToText;
  late GenerativeModel _geminiModel;
  late ChatSession _chatSession;
  late VoiceVoxService _voiceVoxService;
  late ConversationDataService _conversationService;
  
  String _currentSessionId = '';
  String _currentUserId = '';
  bool _isListening = false;
  bool _isProcessing = false;
  
  // ストリームコントローラー
  final StreamController<String> _userTextController = StreamController<String>.broadcast();
  final StreamController<String> _aiResponseController = StreamController<String>.broadcast();
  final StreamController<bool> _listeningStateController = StreamController<bool>.broadcast();
  final StreamController<bool> _processingStateController = StreamController<bool>.broadcast();
  
  // 公開ストリーム
  Stream<String> get userTextStream => _userTextController.stream;
  Stream<String> get aiResponseStream => _aiResponseController.stream;
  Stream<bool> get listeningStateStream => _listeningStateController.stream;
  Stream<bool> get processingStateStream => _processingStateController.stream;
  
  // 現在の状態
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  String get currentSessionId => _currentSessionId;
  
  ShikokuMetanChatService();
  
  /// サービス初期化
  Future<bool> initialize({
    required String sessionId,
    required String userId,
  }) async {
    try {
      _currentSessionId = sessionId;
      _currentUserId = userId;
      
      // STT初期化
      _speechToText = stt.SpeechToText();
      final sttAvailable = await _speechToText.initialize(
        onError: (error) => print('STTエラー: $error'),
        onStatus: (status) => print('STTステータス: $status'),
      );
      
      if (!sttAvailable) {
        print('音声認識が利用できません');
        return false;
      }
      
      // Firebase AI (Gemini)初期化
      print('Firebase AI初期化開始...');
      _geminiModel = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-1.5-flash',
        systemInstruction: Content.system(GeminiConfig.shikokuMetanSystemPrompt),
        generationConfig: GenerationConfig(
          temperature: GeminiConfig.temperature,
          maxOutputTokens: GeminiConfig.maxOutputTokens,
          topP: GeminiConfig.topP,
          topK: GeminiConfig.topK,
        ),
      );
      print('Firebase AIモデル作成完了: gemini-1.5-flash');
      
      // チャットセッション開始
      _chatSession = _geminiModel.startChat();
      
      // VOICEVOX初期化（四国めたん専用設定）
      _voiceVoxService = VoiceVoxService();
      _voiceVoxService.setSpeaker(int.parse(_shikokuMetanSpeakerId));
      _voiceVoxService.setVoiceParameters(
        speed: 1.1,     // 少し早口で元気に
        pitch: 0.1,     // 少し高めの声
        intonation: 1.2, // 抑揚豊かに
        volume: 1.0,
      );
      
      // 会話ログサービス初期化
      _conversationService = ConversationDataService();
      
      print('四国めたんチャットサービス初期化完了');
      return true;
      
    } catch (e) {
      print('初期化エラー: $e');
      return false;
    }
  }
  
  /// 音声認識開始
  Future<void> startListening() async {
    if (_isListening || _isProcessing) return;
    
    try {
      _isListening = true;
      _listeningStateController.add(true);
      
      await _speechToText.listen(
        onResult: (result) {
          print('音声認識結果: ${result.recognizedWords} (final: ${result.finalResult})');
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _handleUserSpeech(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'ja_JP',
        partialResults: true,
      );
      
    } catch (e) {
      print('音声認識開始エラー: $e');
      _isListening = false;
      _listeningStateController.add(false);
    }
  }
  
  /// 音声認識停止
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      await _speechToText.stop();
      _isListening = false;
      _listeningStateController.add(false);
    } catch (e) {
      print('音声認識停止エラー: $e');
    }
  }
  
  /// ユーザーの音声テキストを処理
  Future<void> _handleUserSpeech(String userText) async {
    if (userText.trim().isEmpty || _isProcessing) return;
    
    try {
      _isProcessing = true;
      _processingStateController.add(true);
      
      // ユーザーテキストをストリームに送信
      _userTextController.add(userText);
      print('ユーザー: $userText');
      
      // Geminiで応答生成
      final aiResponse = await _generateAiResponse(userText);
      
      if (aiResponse.isNotEmpty) {
        // AI応答をストリームに送信
        _aiResponseController.add(aiResponse);
        print('四国めたん: $aiResponse');
        
        // Firebase会話ログ保存
        await _saveConversationLog(userText, aiResponse);
        
        // VOICEVOX音声合成・再生
        await _speakWithShikokuMetan(aiResponse);
      }
      
    } catch (e) {
      print('音声処理エラー: $e');
    } finally {
      _isProcessing = false;
      _processingStateController.add(false);
      
      // 音声認識を確実に停止してから再開（連続会話のため）
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 500)); // 少し待機
      await startListening();
    }
  }
  
  /// Gemini AIで応答生成
  Future<String> _generateAiResponse(String userText) async {
    try {
      print('Gemini応答生成開始: $userText');
      
      // チャットセッションが初期化されていない場合は再初期化
      if (_chatSession == null) {
        print('チャットセッションを再初期化中...');
        _chatSession = _geminiModel.startChat();
      }
      
      print('Geminiにメッセージ送信: $userText');
      final response = await _chatSession.sendMessage(Content.text(userText));
      final aiText = response.text ?? '';
      
      print('Gemini応答受信: $aiText (${aiText.length}文字)');
      
      if (aiText.isEmpty) {
        return 'ごめんやで〜、ちょっと聞こえへんかった💦 もう一回言うてくれる？';
      }
      
      return aiText;
      
    } catch (e) {
      print('AI応答生成エラー: $e');
      // エラーが発生した場合はチャットセッションを再初期化
      try {
        print('チャットセッションエラー後再初期化: $e');
        _chatSession = _geminiModel.startChat();
      } catch (reinitError) {
        print('チャットセッション再初期化失敗: $reinitError');
      }
      return 'ごめんやで〜、ちょっと調子悪いわ💦 もう一回言うてくれる？';
    }
  }
  
  /// 四国めたんの声で音声合成・再生
  Future<void> _speakWithShikokuMetan(String text) async {
    try {
      // VOICEVOX Engineが利用可能か確認
      final isAvailable = await _voiceVoxService.isEngineAvailable();
      if (!isAvailable) {
        print('VOICEVOX Engine利用不可');
        return;
      }
      
      // 四国めたんの声で合成・再生
      final success = await _voiceVoxService.speak(text);
      if (!success) {
        print('音声合成失敗: $text');
      }
      
    } catch (e) {
      print('音声合成エラー: $e');
    }
  }
  
  /// 会話ログをFirebaseに保存
  Future<void> _saveConversationLog(String userText, String aiResponse) async {
    try {
      await _conversationService.saveConversation(
        sessionId: _currentSessionId,
        userId: _currentUserId,
        userText: userText,
        aiResponse: aiResponse,
        aiCharacter: '四国めたん',
        metadata: {
          'voicevox_speaker_id': _shikokuMetanSpeakerId,
          'voicevox_speaker_uuid': _shikokuMetanUuid,
          'voice_settings': {
            'speed': 1.1,
            'pitch': 0.1,
            'intonation': 1.2,
            'volume': 1.0,
          }
        },
      );
      
    } catch (e) {
      print('会話ログ保存エラー: $e');
    }
  }
  
  /// テスト用：テキスト入力での会話
  Future<void> sendTextMessage(String text) async {
    await _handleUserSpeech(text);
  }
  
  /// セッション終了・クリーンアップ
  Future<void> dispose() async {
    try {
      await stopListening();
      await _voiceVoxService.stop();
      _voiceVoxService.dispose();
      
      await _userTextController.close();
      await _aiResponseController.close();
      await _listeningStateController.close();
      await _processingStateController.close();
      
      print('四国めたんチャットサービス終了');
      
    } catch (e) {
      print('サービス終了エラー: $e');
    }
  }
  
  /// 四国めたんからの挨拶開始
  Future<void> startGreeting() async {
    final greetings = [
      'こんにちは〜♪ 四国めたんやで！今日はどんなお話しよか？',
      'やっほー！めたんと一緒におしゃべりしよ〜♪',
      'おつかれさま〜！何かええこと、あった？',
    ];
    
    final greeting = (greetings..shuffle()).first;
    _aiResponseController.add(greeting);
    await _speakWithShikokuMetan(greeting);
  }
  
  /// VOICEVOX Engine接続状態確認
  Future<bool> checkVoiceEngineStatus() async {
    return await _voiceVoxService.isEngineAvailable();
  }
  
  /// 音声設定変更
  void updateVoiceSettings({
    double? speed,
    double? pitch, 
    double? intonation,
    double? volume,
  }) {
    _voiceVoxService.setVoiceParameters(
      speed: speed,
      pitch: pitch,
      intonation: intonation,
      volume: volume,
    );
  }
}