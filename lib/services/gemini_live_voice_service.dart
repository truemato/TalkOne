// AI機能無効化のためGemini Live音声サービス全体をコメントアウト
/*
// lib/services/gemini_live_voice_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/personality_system.dart';

/// Gemini Live APIを使用したリアルタイム音声会話サービス
/// 音声入力をそのままGeminiに送信し、音声応答を直接受け取る
class GeminiLiveVoiceService {
  static const String _wsUrl = 'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1.GenerativeService.BidiGenerateContent';
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  // 現在の状態
  bool _isConnected = false;
  int? _currentPersonalityId;
  
  // コールバック
  Function(Uint8List audioData)? onAudioReceived;
  Function(String text)? onTranscriptReceived;
  Function(String error)? onError;
  Function(bool isListening)? onListeningStateChanged;
  
  // Gemini Live API用の設定
  final String _apiKey;
  final String _model = 'models/gemini-2.0-flash-exp'; // Live API対応モデル
  
  GeminiLiveVoiceService({required String apiKey}) : _apiKey = apiKey;
  
  /// WebSocket接続を初期化
  Future<bool> initialize() async {
    try {
      // ランダムに人格を選択
      _currentPersonalityId = PersonalitySystem.getRandomPersonality();
      
      // WebSocket接続
      final uri = Uri.parse('$_wsUrl?key=$_apiKey');
      _channel = WebSocketChannel.connect(uri);
      
      // 初期設定メッセージを送信
      await _sendInitialConfig();
      
      // ストリームを聞く
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          print('WebSocketエラー: $error');
          onError?.call('接続エラー: $error');
        },
        onDone: () {
          print('WebSocket接続が閉じられました');
          _isConnected = false;
        },
      );
      
      _isConnected = true;
      print('Gemini Live API: 接続成功');
      
      // 初回の挨拶を送信
      await _sendGreeting();
      
      return true;
    } catch (e) {
      print('Gemini Live API初期化エラー: $e');
      onError?.call('初期化エラー: $e');
      return false;
    }
  }
  
  /// 初期設定を送信
  Future<void> _sendInitialConfig() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final personalitySystem = PersonalitySystem();
    final systemPrompt = await personalitySystem.generateSystemPromptWithPersonality(
      user.uid,
      _currentPersonalityId!,
    );
    
    final config = {
      'setup': {
        'model': _model,
        'config': {
          'response_modalities': ['AUDIO', 'TEXT'], // 音声とテキスト両方を受信
          'speech_config': {
            'voice_config': {
              'language_code': 'ja-JP',
              'name': 'ja-JP-Neural2-B', // より自然な日本語音声
            }
          },
          'system_instruction': systemPrompt,
        }
      }
    };
    
    _channel!.sink.add(jsonEncode(config));
  }
  
  /// 初回の挨拶を送信
  Future<void> _sendGreeting() async {
    final greeting = PersonalitySystem.getPersonalityGreeting(_currentPersonalityId!);
    
    // テキストで挨拶を送信（音声で返答が来る）
    final message = {
      'client_content': {
        'parts': [
          {'text': 'こんにちは！自己紹介をしてください。'}
        ]
      }
    };
    
    _channel!.sink.add(jsonEncode(message));
  }
  
  /// 音声データを送信
  Future<void> sendAudioData(Uint8List audioData) async {
    if (!_isConnected || _channel == null) {
      onError?.call('接続されていません');
      return;
    }
    
    try {
      // 音声データをBase64エンコード
      final base64Audio = base64Encode(audioData);
      
      final message = {
        'realtime_input': {
          'media_chunks': [
            {
              'mime_type': 'audio/pcm',
              'data': base64Audio
            }
          ]
        }
      };
      
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      print('音声送信エラー: $e');
      onError?.call('音声送信エラー: $e');
    }
  }
  
  /// テキストメッセージを送信
  Future<void> sendTextMessage(String text) async {
    if (!_isConnected || _channel == null) {
      onError?.call('接続されていません');
      return;
    }
    
    try {
      final message = {
        'client_content': {
          'parts': [
            {'text': text}
          ]
        }
      };
      
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      print('テキスト送信エラー: $e');
      onError?.call('メッセージ送信エラー: $e');
    }
  }
  
  /// WebSocketメッセージを処理
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      
      if (data['server_content'] != null) {
        final content = data['server_content'];
        
        // 音声データの処理
        if (content['model_turn'] != null) {
          final parts = content['model_turn']['parts'] ?? [];
          
          for (final part in parts) {
            // 音声データ
            if (part['inline_data'] != null) {
              final mimeType = part['inline_data']['mime_type'];
              if (mimeType == 'audio/wav' || mimeType == 'audio/pcm') {
                final audioBase64 = part['inline_data']['data'];
                final audioData = base64Decode(audioBase64);
                onAudioReceived?.call(audioData);
              }
            }
            
            // テキストデータ（トランスクリプト）
            if (part['text'] != null) {
              onTranscriptReceived?.call(part['text']);
            }
          }
        }
      }
      
      // ツール使用応答（関数呼び出しなど）
      if (data['tool_call'] != null) {
        // 必要に応じて処理
      }
      
    } catch (e) {
      print('メッセージ処理エラー: $e');
      onError?.call('応答処理エラー: $e');
    }
  }
  
  /// マイクのON/OFF制御
  void setListening(bool listening) {
    onListeningStateChanged?.call(listening);
    
    if (!listening) {
      // リスニング停止時は、入力完了を通知
      final message = {
        'realtime_input': {
          'end_of_turn': true
        }
      };
      
      _channel?.sink.add(jsonEncode(message));
    }
  }
  
  /// 接続を閉じる
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    print('Gemini Live API: 接続終了');
  }
  
  // ゲッター
  bool get isConnected => _isConnected;
  int? get currentPersonalityId => _currentPersonalityId;
}
*/