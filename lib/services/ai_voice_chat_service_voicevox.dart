// AI機能無効化のためVOICEVOX AI音声チャットサービス全体をコメントアウト
/*
// lib/services/ai_voice_chat_service_voicevox.dart
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/personality_system.dart';
import '../services/voicevox_service.dart';

enum VoiceChatState {
  idle,         // 待機中
  listening,    // ユーザーの音声を聞いている
  processing,   // AIが考え中
  speaking,     // AIが話している
  error,        // エラー状態
}

/// VOICEVOX統合AI音声チャットサービス
/// 
/// 既存のFlutterTTSとVOICEVOXの両方をサポートし、
/// より高品質な音声合成を提供します。
class AIVoiceChatServiceVoiceVox {
  final SpeechToText _speech;
  final FlutterTts _tts;
  final VoiceVoxService _voiceVoxService;
  late final GenerativeModel _aiModel;
  late final ChatSession _session;
  
  VoiceChatState _currentState = VoiceChatState.idle;
  int? _currentPersonalityId;
  bool _isInitialized = false;
  bool _useVoiceVox = true; // VoiceVox使用フラグ
  
  // コールバック関数
  Function(VoiceChatState)? onStateChanged;
  Function(String)? onUserSpeech;
  Function(String)? onAIResponse;
  Function(String)? onError;
  Function(double)? onSoundLevel;
  
  // 音声認識の結果を蓄積
  String _accumulatedSpeech = '';
  Timer? _speechTimer;
  
  AIVoiceChatServiceVoiceVox({
    required SpeechToText speech,
    required FlutterTts tts,
    VoiceVoxService? voiceVoxService,
    bool useVoiceVox = true,
  }) : _speech = speech, 
       _tts = tts,
       _voiceVoxService = voiceVoxService ?? VoiceVoxService(),
       _useVoiceVox = useVoiceVox;
  
  /// VoiceVox使用設定を切り替え
  void setUseVoiceVox(bool useVoiceVox) {
    _useVoiceVox = useVoiceVox;
  }
  
  /// 現在のVoiceVox使用状態を取得
  bool get isUsingVoiceVox => _useVoiceVox;
  
  /// VoiceVoxサービスのエンジン接続状態をチェック
  Future<bool> checkVoiceVoxConnection() async {
    return await _voiceVoxService.isEngineAvailable();
  }
  
  // 初期化
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // VoiceVoxエンジンの接続確認
      if (_useVoiceVox) {
        final isVoiceVoxAvailable = await _voiceVoxService.isEngineAvailable();
        if (!isVoiceVoxAvailable) {
          print('VoiceVox Engine接続失敗、FlutterTTSにフォールバック');
          _useVoiceVox = false;
        }
      }
      
      // ランダムに人格を選択
      _currentPersonalityId = PersonalitySystem.getRandomPersonality();
      
      // AI人格に応じたVoiceVox音声設定
      if (_useVoiceVox && _currentPersonalityId != null) {
        final voiceConfig = PersonalityVoiceMapping.getVoiceConfig(_currentPersonalityId!);
        if (voiceConfig != null) {
          _voiceVoxService.setSpeaker(voiceConfig.speakerId);
          _voiceVoxService.setVoiceParameters(
            speed: voiceConfig.speed,
            pitch: voiceConfig.pitch,
            intonation: voiceConfig.intonation,
            volume: voiceConfig.volume,
          );
        }
      }
      
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
      
      // FlutterTTSのフォールバック設定
      if (!_useVoiceVox) {
        await _tts.setLanguage('ja-JP');
        await _tts.setSpeechRate(0.5);
        await _tts.setPitch(1.0);
        
        _tts.setCompletionHandler(() {
          _setState(VoiceChatState.idle);
          print('AI音声会話: TTS完了');
        });
      }
      
      print('AI音声会話: 初期化完了 - 人格: ${PersonalitySystem.getPersonalityName(_currentPersonalityId!)} - 音声: ${_useVoiceVox ? "VoiceVox" : "FlutterTTS"}');
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
      await _stopCurrentSpeech();
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
      print('AI音声会話: AI応答再生 - "$aiText" (${_useVoiceVox ? "VoiceVox" : "FlutterTTS"})');
      
      if (_useVoiceVox) {
        // VoiceVoxで音声合成
        final success = await _voiceVoxService.speak(aiText);
        if (!success) {
          // VoiceVox失敗時はFlutterTTSにフォールバック
          print('VoiceVox音声合成失敗、FlutterTTSにフォールバック');
          await _tts.speak(aiText);
        }
        // VoiceVoxの場合は手動で状態変更
        _setState(VoiceChatState.idle);
      } else {
        // FlutterTTSで音声合成
        await _tts.speak(aiText);
        // FlutterTTSはコールバックで状態変更
      }
    } catch (e) {
      onError?.call('音声再生エラー: $e');
      _setState(VoiceChatState.error);
    }
  }
  
  // 現在の音声再生を停止
  Future<void> _stopCurrentSpeech() async {
    if (_useVoiceVox) {
      await _voiceVoxService.stop();
    } else {
      await _tts.stop();
    }
  }
  
  // 音声停止
  Future<void> stopSpeaking() async {
    await _stopCurrentSpeech();
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
  
  // VoiceVoxサービスのアクセス
  VoiceVoxService get voiceVoxService => _voiceVoxService;
  
  // 音声設定情報の取得
  Map<String, dynamic> getVoiceSettings() {
    final settings = _voiceVoxService.getCurrentSettings();
    settings['useVoiceVox'] = _useVoiceVox;
    settings['personalityId'] = _currentPersonalityId;
    return settings;
  }
  
  // リソース解放
  Future<void> dispose() async {
    _speechTimer?.cancel();
    await _speech.stop();
    await _stopCurrentSpeech();
    _voiceVoxService.dispose();
    print('AI音声会話: リソース解放完了');
  }
}
*/