// lib/services/vap_system_v2.dart
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VAPState {
  idle,           // 待機中
  speaking,       // AI音声再生中
  listening,      // ユーザー音声検出中
  interrupted,    // 音声中断発生
}

class VAPSystemV2 {
  final FlutterTts _tts;
  final stt.SpeechToText _speech;
  
  VAPState _currentState = VAPState.idle;
  bool _isMonitoring = false;
  String? _currentSpeechText;
  double _speechProgress = 0.0;
  Timer? _progressTimer;
  Timer? _speechTimer;
  DateTime? _speechStartTime;
  int _estimatedDuration = 0; // ミリ秒
  
  // コールバック関数
  Function()? onInterruption;
  Function(String)? onUserSpeech;
  Function(VAPState)? onStateChanged;
  Function(double)? onSpeechProgress; // 0.0-1.0
  
  VAPSystemV2({
    required FlutterTts tts,
    required stt.SpeechToText speech,
  }) : _tts = tts, _speech = speech {
    _initializeTTS();
  }
  
  void _initializeTTS() {
    // TTS完了コールバック
    _tts.setCompletionHandler(() {
      print('VAP: TTS完了');
      _setState(VAPState.idle);
      _stopAllTimers();
    });
  }
  
  // AI音声を開始（VAPモニタリング付き）
  Future<void> speakWithVAP(String text) async {
    if (text.isEmpty) return;
    
    print('VAP: 音声開始 - "$text"');
    
    _currentSpeechText = text;
    _speechProgress = 0.0;
    _speechStartTime = DateTime.now();
    
    // 日本語の読み上げ時間を推定（1文字あたり約150ms）
    _estimatedDuration = (text.length * 150);
    
    _setState(VAPState.speaking);
    
    // 進行度シミュレーション開始
    _startProgressTracking();
    
    // 音声モニタリング開始
    _startSpeechMonitoring();
    
    // TTS開始
    await _tts.speak(text);
  }
  
  // 進行度追跡開始
  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentState != VAPState.speaking || _speechStartTime == null) {
        timer.cancel();
        return;
      }
      
      final elapsed = DateTime.now().difference(_speechStartTime!).inMilliseconds;
      _speechProgress = _estimatedDuration > 0 
          ? (elapsed / _estimatedDuration).clamp(0.0, 1.0)
          : 0.0;
      
      onSpeechProgress?.call(_speechProgress);
      
      // 完了チェック
      if (_speechProgress >= 1.0) {
        timer.cancel();
        if (_currentState == VAPState.speaking) {
          _setState(VAPState.idle);
        }
      }
    });
  }
  
  // 音声モニタリング開始
  void _startSpeechMonitoring() {
    if (!_speech.isAvailable) {
      print('VAP: 音声認識が利用できません');
      return;
    }
    
    if (_isMonitoring) {
      print('VAP: 既に音声モニタリング中です');
      return;
    }
    
    _isMonitoring = true;
    print('VAP: 音声モニタリング開始 - 音声認識利用可能: ${_speech.isAvailable}');
    print('VAP: 現在の状態: $_currentState, 中断可能: $canInterrupt');
    
    // 継続的な音声検出
    _speech.listen(
      onResult: (result) {
        print('VAP: 音声結果受信 - "${result.recognizedWords}" (信頼度: ${result.confidence})');
        print('VAP: 現在の状態: $_currentState, 中断可能: $canInterrupt, 進行度: ${(_speechProgress * 100).toStringAsFixed(1)}%');
        
        if (_currentState == VAPState.speaking && canInterrupt) {
          print('VAP: 中断可能な状態で音声を検出');
          if (result.hasConfidenceRating && result.confidence > 0.5) { // 閾値を下げる
            if (result.recognizedWords.trim().length > 0) { // 1文字でも有効
              print('VAP: ★有効なユーザー発言を検出 - 中断実行★');
              _executeInterruption(result.recognizedWords);
            } else {
              print('VAP: 認識された文字列が短すぎます');
            }
          } else {
            print('VAP: 信頼度が低すぎます (${result.confidence})');
          }
        } else {
          print('VAP: 中断不可能な状態です (状態: $_currentState, 中断可能: $canInterrupt)');
        }
      },
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(milliseconds: 100), // より短く
      partialResults: true,
      onSoundLevelChange: (level) {
        if (level > 0.1) { // 低い閾値でもログ出力
          print('VAP: 音声レベル検出 - $level (状態: $_currentState)');
        }
      },
    );
  }
  
  // 中断実行
  void _executeInterruption(String userSpeech) {
    print('VAP: 中断実行チェック - 状態: $_currentState, 中断可能: $canInterrupt');
    
    if (_currentState != VAPState.speaking) {
      print('VAP: 音声再生中ではないため中断しません');
      return;
    }
    
    if (!canInterrupt) {
      print('VAP: 中断不可能期間のため中断しません (進行度: ${(_speechProgress * 100).toStringAsFixed(1)}%)');
      return;
    }
    
    print('VAP: ★★★ 音声中断実行 ★★★ (進行度: ${(_speechProgress * 100).toStringAsFixed(1)}%)');
    print('VAP: ユーザー発言: "$userSpeech"');
    
    // TTS停止
    _tts.stop();
    print('VAP: TTS停止実行');
    
    // 全タイマー停止
    _stopAllTimers();
    print('VAP: タイマー停止実行');
    
    // モニタリング停止
    _stopSpeechMonitoring();
    print('VAP: 音声モニタリング停止実行');
    
    // 状態リセット
    _setState(VAPState.idle);
    print('VAP: 状態をidleにリセット');
    
    // コールバック実行
    print('VAP: コールバック実行開始');
    onInterruption?.call();
    onUserSpeech?.call(userSpeech);
    print('VAP: コールバック実行完了');
  }
  
  // 音声モニタリング停止
  void _stopSpeechMonitoring() {
    if (_isMonitoring) {
      _speech.stop();
      _isMonitoring = false;
      print('VAP: 音声モニタリング停止');
    }
  }
  
  // 全タイマー停止
  void _stopAllTimers() {
    _progressTimer?.cancel();
    _speechTimer?.cancel();
  }
  
  // 状態変更
  void _setState(VAPState newState) {
    if (_currentState != newState) {
      final oldState = _currentState;
      _currentState = newState;
      onStateChanged?.call(newState);
      print('VAP状態変更: $oldState -> $newState');
    }
  }
  
  // 手動停止
  void stop() {
    print('VAP: 手動停止');
    _tts.stop();
    _stopAllTimers();
    _stopSpeechMonitoring();
    _setState(VAPState.idle);
  }
  
  // 現在の状態取得
  VAPState get currentState => _currentState;
  
  // 進行度取得
  double get speechProgress => _speechProgress;
  
  // 中断可能かどうか
  bool get canInterrupt {
    return _currentState == VAPState.speaking && _speechProgress <= 0.5;
  }
  
  // 現在話している内容
  String? get currentSpeechText => _currentSpeechText;
  
  // リソース解放
  void dispose() {
    print('VAP: リソース解放');
    _stopAllTimers();
    _stopSpeechMonitoring();
  }
}