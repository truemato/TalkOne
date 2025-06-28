// lib/services/audio_stream_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// リアルタイム音声ストリーミングサービス
/// マイクからの音声をストリーミングし、受信した音声を再生
class AudioStreamService {
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  
  StreamController<Uint8List>? _audioStreamController;
  Stream<Uint8List>? _audioStream;
  bool _isRecording = false;
  bool _isPlaying = false;
  
  // コールバック
  Function(String error)? onError;
  
  /// 初期化
  Future<bool> initialize() async {
    try {
      // マイク権限確認
      if (!await _recorder.hasPermission()) {
        onError?.call('マイクの権限がありません');
        return false;
      }
      
      // プレイヤー初期化
      await _player.openPlayer();
      
      print('AudioStreamService: 初期化完了');
      return true;
    } catch (e) {
      print('AudioStreamService初期化エラー: $e');
      onError?.call('音声サービス初期化エラー: $e');
      return false;
    }
  }
  
  /// 録音開始（ストリーミング）
  Future<Stream<Uint8List>> startRecording() async {
    if (_isRecording) {
      return _audioStream!;
    }
    
    try {
      _audioStreamController = StreamController<Uint8List>();
      
      // PCM形式で録音開始（Gemini Live APIに適した形式）
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000, // 16kHz
          numChannels: 1,    // モノラル
        ),
      );
      
      // ストリームを変換
      stream.listen(
        (data) {
          _audioStreamController?.add(data);
        },
        onError: (error) {
          print('録音エラー: $error');
          onError?.call('録音エラー: $error');
        },
      );
      
      _isRecording = true;
      _audioStream = _audioStreamController!.stream.asBroadcastStream();
      
      print('AudioStreamService: 録音開始');
      return _audioStream!;
    } catch (e) {
      print('録音開始エラー: $e');
      onError?.call('録音開始エラー: $e');
      rethrow;
    }
  }
  
  /// 録音停止
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    try {
      await _recorder.stop();
      await _audioStreamController?.close();
      _audioStreamController = null;
      _audioStream = null;
      _isRecording = false;
      
      print('AudioStreamService: 録音停止');
    } catch (e) {
      print('録音停止エラー: $e');
      onError?.call('録音停止エラー: $e');
    }
  }
  
  /// 音声再生（ストリーミング）
  Future<void> playAudioStream(Uint8List audioData) async {
    try {
      if (!_isPlaying) {
        // PCM形式で再生開始
        await _player.startPlayerFromStream(
          codec: Codec.pcm16,
          sampleRate: 16000,
          numChannels: 1,
          bufferSize: 4096,
          interleaved: true, 
        );
        _isPlaying = true;
      }
      
      // 音声データをフィード
      _player.foodSink!.add(FoodData(audioData));
      
    } catch (e) {
      print('音声再生エラー: $e');
      onError?.call('音声再生エラー: $e');
    }
  }
  
  /// 再生停止
  Future<void> stopPlaying() async {
    if (!_isPlaying) return;
    
    try {
      await _player.stopPlayer();
      _isPlaying = false;
      
      print('AudioStreamService: 再生停止');
    } catch (e) {
      print('再生停止エラー: $e');
      onError?.call('再生停止エラー: $e');
    }
  }
  
  /// 音量設定（0.0 - 1.0）
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }
  
  /// リソース解放
  Future<void> dispose() async {
    await stopRecording();
    await stopPlaying();
    await _player.closePlayer();
    await _recorder.dispose();
    
    print('AudioStreamService: リソース解放完了');
  }
  
  // ゲッター
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
}