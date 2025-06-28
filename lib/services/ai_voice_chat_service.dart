// AI機能無効化のためAI音声チャットサービス全体をコメントアウト
/*
// lib/services/ai_voice_chat_service.dart
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/personality_system.dart';

enum VoiceChatState {
  idle,         // 待機中
  listening,    // ユーザーの音声を聞いている
  processing,   // AIが考え中
  speaking,     // AIが話している
  error,        // エラー状態
}

class AIVoiceChatService {
  final SpeechToText _speech;
  final FlutterTts _tts;
  late final GenerativeModel _aiModel;
  late final ChatSession _session;
  
  VoiceChatState _currentState = VoiceChatState.idle;
  int? _currentPersonalityId;
  bool _isInitialized = false;
  
  // コールバック関数
  Function(VoiceChatState)? onStateChanged;
  Function(String)? onUserSpeech;
  Function(String)? onAIResponse;
  Function(String)? onError;
  Function(double)? onSoundLevel;
  
  // 音声認識の結果を蓄積
  String _accumulatedSpeech = '';
  Timer? _speechTimer;
  
  AIVoiceChatService({
    required SpeechToText speech,
    required FlutterTts tts,
  }) : _speech = speech, _tts = tts;
  
  // 初期化
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // ランダムに人格を選択
      _currentPersonalityId = PersonalitySystem.getRandomPersonality();
      
      // AIモデルの初期化
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        onError?.call('ユーザー認証が必要です');
        return false;
      }
      
      final personalitySystem = PersonalitySystem();
      final systemPrompt = await personalitySystem.generateSystemPromptWithPersonality(
        user.uid, 
        _currentPersonalityId!,
      );
      
      _aiModel = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash-preview-05-20',
        systemInstruction: Content.text(systemPrompt),
      );
      _session = _aiModel.startChat();
      
      // TTSの設定
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      
      // TTS完了コールバック
      _tts.setCompletionHandler(() {
        _setState(VoiceChatState.idle);
        print('AI音声会話: TTS完了');
      });
      
      print('AI音声会話: 初期化完了 - 人格: ${PersonalitySystem.getPersonalityName(_currentPersonalityId!)}');
      _isInitialized = true;
      
      // 初回挨拶
      await _speakAIResponse(PersonalitySystem.getPersonalityGreeting(_currentPersonalityId!));
      
      return true;
    } catch (e) {
      onError?.call('初期化エラー: $e');
      return false;
    }
  }
  
  // ユーザー音声の聞き取り開始
  Future<void> startListening() async {
    if (!_isInitialized || !_speech.isAvailable) {
      onError?.call('音声認識が利用できません');
      return;
    }
    
    if (_currentState == VoiceChatState.speaking) {
      // AI話中の場合は停止
      await _tts.stop();
    }
    
    _setState(VoiceChatState.listening);
    _accumulatedSpeech = '';
    
    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        localeId: 'ja_JP',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        onSoundLevelChange: (level) {
          onSoundLevel?.call(level);
        },
      );
      
      // 一定時間で自動終了
      _speechTimer?.cancel();
      _speechTimer = Timer(const Duration(seconds: 3), () {
        if (_currentState == VoiceChatState.listening && _accumulatedSpeech.trim().isNotEmpty) {
          _processSpeechInput(_accumulatedSpeech.trim());
        }
      });
      
    } catch (e) {
      onError?.call('音声認識エラー: $e');
      _setState(VoiceChatState.error);
    }
  }
  
  // 音声認識結果の処理
  void _onSpeechResult(SpeechRecognitionResult result) {
    _accumulatedSpeech = result.recognizedWords;
    onUserSpeech?.call(_accumulatedSpeech);
    
    // 音声認識が完了したら処理
    if (_accumulatedSpeech.trim().isNotEmpty) {
      _speechTimer?.cancel();
      _speechTimer = Timer(const Duration(milliseconds: 1500), () {
        if (_currentState == VoiceChatState.listening) {
          _processSpeechInput(_accumulatedSpeech.trim());
        }
      });
    }
  }
  
  // 音声入力をAIに送信
  Future<void> _processSpeechInput(String userText) async {
    if (userText.isEmpty) return;
    
    await _speech.stop();
    _setState(VoiceChatState.processing);
    
    try {
      print('AI音声会話: ユーザー発言処理 - "$userText"');
      
      final response = await _session.sendMessage(Content.text(userText));
      final aiText = response.text ?? '';
      
      if (aiText.isNotEmpty) {
        await _speakAIResponse(aiText);
      } else {
        onError?.call('AI応答が空です');
        _setState(VoiceChatState.idle);
      }
      
    } catch (e) {
      onError?.call('AI処理エラー: $e');
      _setState(VoiceChatState.error);
    }
  }
  
  // AI応答を音声で再生
  Future<void> _speakAIResponse(String aiText) async {
    _setState(VoiceChatState.speaking);
    onAIResponse?.call(aiText);
    
    try {
      print('AI音声会話: AI応答再生 - "$aiText"');
      await _tts.speak(aiText);
    } catch (e) {
      onError?.call('音声再生エラー: $e');
      _setState(VoiceChatState.error);
    }
  }
  
  // 音声停止
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _setState(VoiceChatState.idle);
  }
  
  // 聞き取り停止
  Future<void> stopListening() async {
    await _speech.stop();
    _speechTimer?.cancel();
    if (_currentState == VoiceChatState.listening) {
      _setState(VoiceChatState.idle);
    }
  }
  
  // 状態変更
  void _setState(VoiceChatState newState) {
    if (_currentState != newState) {
      final oldState = _currentState;
      _currentState = newState;
      onStateChanged?.call(newState);
      print('AI音声会話状態変更: $oldState -> $newState');
    }
  }
  
  // 現在の状態取得
  VoiceChatState get currentState => _currentState;
  
  // 現在の人格取得
  int? get currentPersonalityId => _currentPersonalityId;
  
  // リソース解放
  Future<void> dispose() async {
    _speechTimer?.cancel();
    await _speech.stop();
    await _tts.stop();
    print('AI音声会話: リソース解放完了');
  }
}
*/