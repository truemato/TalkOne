// lib/services/vap_system.dart
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VAPState {
  idle,           // 待機中
  speaking,       // AI音声再生中
  listening,      // ユーザー音声検出中
  interrupted,    // 音声中断発生
}

class VAPSystem {
  final FlutterTts _tts;
  final stt.SpeechToText _speech;
  
  VAPState _currentState = VAPState.idle;
  bool _isMonitoring = false;
  String? _currentSpeechText;
  int _currentSpeechPosition = 0;
  int _totalSpeechLength = 0;
  Timer? _monitoringTimer;
  
  // コールバック関数
  Function()? onInterruption;
  Function(String)? onUserSpeech;
  Function(VAPState)? onStateChanged;
  Function(double)? onSpeechProgress; // 0.0-1.0
  
  VAPSystem({
    required FlutterTts tts,
    required stt.SpeechToText speech,
  }) : _tts = tts, _speech = speech {
    _initializeTTS();
  }
  
  void _initializeTTS() {
    // TTS完了コールバック
    _tts.setCompletionHandler(() {
      _setState(VAPState.idle);
      _stopMonitoring();
    });
    
    // TTS進行状況コールバック（利用可能な場合）
    _tts.setProgressHandler((String text, int start, int end, String word) {
      _currentSpeechPosition = end;
      final progress = _totalSpeechLength > 0 
          ? end / _totalSpeechLength 
          : 0.0;
      onSpeechProgress?.call(progress);
      
      // 50%以下で中断検出した場合のみ処理
      if (progress <= 0.5 && _currentState == VAPState.interrupted) {
        _handleInterruption();
      }
    });
  }
  
  // AI音声を開始（VAPモニタリング付き）
  Future<void> speakWithVAP(String text) async {
    if (text.isEmpty) return;
    
    _currentSpeechText = text;
    _totalSpeechLength = text.length;
    _currentSpeechPosition = 0;
    _setState(VAPState.speaking);
    
    // 音声モニタリング開始
    _startMonitoring();
    
    // TTS開始
    await _tts.speak(text);
  }
  
  // 音声モニタリング開始
  void _startMonitoring() {
    if (!_speech.isAvailable || _isMonitoring) return;
    
    _isMonitoring = true;
    
    // 継続的な音声検出
    _speech.listen(
      onResult: (result) {
        if (result.hasConfidenceRating && result.confidence > 0.7) {
          _detectUserSpeech(result.recognizedWords);
        }
      },
      listenFor: const Duration(minutes: 5), // 長時間リスン
      pauseFor: const Duration(milliseconds: 500),
      partialResults: true,
      onSoundLevelChange: (level) {
        // 音声レベルが閾値を超えた場合の処理
        if (level > 0.3 && _currentState == VAPState.speaking) {
          _detectPotentialInterruption();
        }
      },
    );
  }
  
  // 音声中断の可能性を検出
  void _detectPotentialInterruption() {
    if (_currentState != VAPState.speaking) return;
    
    final progress = _totalSpeechLength > 0 
        ? _currentSpeechPosition / _totalSpeechLength 
        : 0.0;
    
    // 50%以下での中断のみ受け付ける
    if (progress <= 0.5) {
      _setState(VAPState.listening);
      // 短時間待って音声を確認
      Timer(const Duration(milliseconds: 300), () {
        if (_currentState == VAPState.listening) {
          _setState(VAPState.interrupted);
        }
      });
    }
  }
  
  // ユーザー音声検出
  void _detectUserSpeech(String recognizedWords) {
    if (_currentState == VAPState.listening || _currentState == VAPState.interrupted) {
      // 有効な発言として認識
      if (recognizedWords.length > 2) { // 最低3文字以上
        _handleUserInterruption(recognizedWords);
      }
    }
  }
  
  // ユーザー中断処理
  void _handleUserInterruption(String userSpeech) {
    final progress = _totalSpeechLength > 0 
        ? _currentSpeechPosition / _totalSpeechLength 
        : 0.0;
    
    // 50%以下でのみ中断を受け付ける
    if (progress <= 0.5) {
      _handleInterruption();
      onUserSpeech?.call(userSpeech);
    }
  }
  
  // 中断処理実行
  void _handleInterruption() {
    // TTS停止
    _tts.stop();
    
    // モニタリング停止
    _stopMonitoring();
    
    // 状態リセット
    _setState(VAPState.idle);
    
    // 中断コールバック実行
    onInterruption?.call();
    
    print('VAP: 音声が中断されました（進行度: ${(_currentSpeechPosition / _totalSpeechLength * 100).toStringAsFixed(1)}%）');
  }
  
  // モニタリング停止
  void _stopMonitoring() {
    if (_isMonitoring) {
      _speech.stop();
      _isMonitoring = false;
    }
    _monitoringTimer?.cancel();
  }
  
  // 状態変更
  void _setState(VAPState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      onStateChanged?.call(newState);
      print('VAP状態変更: $newState');
    }
  }
  
  // 手動停止
  void stop() {
    _tts.stop();
    _stopMonitoring();
    _setState(VAPState.idle);
  }
  
  // 現在の状態取得
  VAPState get currentState => _currentState;
  
  // 進行度取得
  double get speechProgress {
    return _totalSpeechLength > 0 
        ? _currentSpeechPosition / _totalSpeechLength 
        : 0.0;
  }
  
  // 中断可能かどうか
  bool get canInterrupt {
    return _currentState == VAPState.speaking && speechProgress <= 0.5;
  }
  
  // 現在話している内容
  String? get currentSpeechText => _currentSpeechText;
  
  // リソース解放
  void dispose() {
    _stopMonitoring();
    _monitoringTimer?.cancel();
  }
}