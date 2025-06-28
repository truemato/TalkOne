import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// VOICEVOX音声合成サービス
/// 
/// VOICEVOX Engineを使用して高品質な音声合成を提供します。
/// 様々な話者（キャラクター）と音声パラメータの調整が可能です。
class VoiceVoxService {
  static const String _defaultHost = "https://voicevox-engine-198779252752.asia-northeast1.run.app"; // GCP Cloud Run URL
  static const String _localHost = "http://127.0.0.1:50021"; // ローカル開発用
  static const String _fallbackHost = "https://api.su-shiki.com/v2/voicevox"; // 代替API（将来の実装用）
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _host;
  bool _useLocalEngine;
  
  // 音声パラメータ
  int _speakerId = 1;
  double _speed = 1.0;
  double _pitch = 0.0;
  double _intonation = 1.0;
  double _volume = 1.0;
  
  VoiceVoxService({
    String? host,
    bool useLocalEngine = false,
  }) : _host = host ?? (useLocalEngine ? _localHost : _defaultHost),
       _useLocalEngine = useLocalEngine;
  
  /// 話者IDを設定
  void setSpeaker(int speakerId) {
    _speakerId = speakerId;
  }
  
  /// 音声パラメータを設定
  void setVoiceParameters({
    double? speed,
    double? pitch,
    double? intonation,
    double? volume,
  }) {
    if (speed != null) _speed = speed;
    if (pitch != null) _pitch = pitch;
    if (intonation != null) _intonation = intonation;
    if (volume != null) _volume = volume;
  }
  
  /// ホストURLを変更（ローカル/クラウドの切り替え）
  void switchToLocalEngine() {
    _host = _localHost;
    _useLocalEngine = true;
  }
  
  void switchToCloudEngine() {
    _host = _defaultHost;
    _useLocalEngine = false;
  }
  
  /// VOICEVOX Engineが利用可能かチェック（フォールバック機能付き）
  Future<bool> isEngineAvailable() async {
    // 現在のホストをテスト
    if (await _testConnection(_host)) {
      return true;
    }
    
    // ローカルエンジンでない場合、ローカルにフォールバック
    if (!_useLocalEngine && await _testConnection(_localHost)) {
      print('Cloud Run接続失敗、ローカルエンジンに切り替え');
      _host = _localHost;
      _useLocalEngine = true;
      return true;
    }
    
    // クラウドエンジンでない場合、クラウドにフォールバック
    if (_useLocalEngine && await _testConnection(_defaultHost)) {
      print('ローカル接続失敗、クラウドエンジンに切り替え');
      _host = _defaultHost;
      _useLocalEngine = false;
      return true;
    }
    
    return false;
  }
  
  /// 指定したホストへの接続テスト
  Future<bool> _testConnection(String host) async {
    try {
      final response = await http.get(
        Uri.parse('$host/version'),
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('VOICEVOX Engine接続成功: $host');
        return true;
      }
    } catch (e) {
      print('VOICEVOX Engine接続失敗: $host - $e');
    }
    return false;
  }
  
  /// 利用可能な話者（キャラクター）のリストを取得
  Future<List<VoiceVoxSpeaker>> getSpeakers() async {
    try {
      final response = await http.get(
        Uri.parse('$_host/speakers'),
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> speakersJson = json.decode(response.body);
        return speakersJson.map((json) => VoiceVoxSpeaker.fromJson(json)).toList();
      }
    } catch (e) {
      print('話者リスト取得エラー: $e');
    }
    return [];
  }
  
  /// テキストを音声合成して再生（non-blocking TTS API使用）
  Future<bool> speak(String text) async {
    if (text.isEmpty) return false;
    
    try {
      // TTS API（一発変換）を使用
      final ttsResponse = await http.post(
        Uri.parse('$_host/tts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'speaker': _speakerId,
          'speed': _speed,
          'pitch': _pitch,
          'intonation': _intonation,
          'volume': _volume,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (ttsResponse.statusCode != 200) {
        print('TTS API音声合成失敗: ${ttsResponse.statusCode}');
        print('エラーレスポンス: ${ttsResponse.body}');
        return false;
      }
      
      // 音声再生（iOS対応）
      final audioBytes = ttsResponse.bodyBytes;
      
      try {
        // iOSの場合は一時ファイルに保存してから再生
        if (Platform.isIOS) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/voicevox_${DateTime.now().millisecondsSinceEpoch}.wav');
          await tempFile.writeAsBytes(audioBytes);
          
          // ファイルが正しく書き込まれたか確認
          if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
            throw Exception('音声ファイルの書き込みに失敗しました');
          }
          
          // 新しいAudioPlayerインスタンスを作成（iOS用）
          final iosPlayer = AudioPlayer();
          
          // iOS用の詳細設定
          await iosPlayer.setPlayerMode(PlayerMode.mediaPlayer);
          await iosPlayer.setReleaseMode(ReleaseMode.release);
          
          // ファイルURIとして設定
          final source = DeviceFileSource(tempFile.path);
          await iosPlayer.setSource(source);
          
          // 少し待機してから再生
          await Future.delayed(const Duration(milliseconds: 100));
          await iosPlayer.resume();
          
          // 再生完了を待つか、タイムアウト
          try {
            await iosPlayer.onPlayerComplete.first.timeout(
              const Duration(seconds: 30),
            );
          } catch (e) {
            print('音声再生タイムアウトまたはエラー: $e');
          }
          
          // リソース解放
          await iosPlayer.stop();
          await iosPlayer.dispose();
          
          // ファイルを削除
          if (tempFile.existsSync()) {
            try {
              tempFile.deleteSync();
            } catch (e) {
              print('一時ファイル削除エラー: $e');
            }
          }
        } else {
          // Androidの場合はメモリから直接再生
          await _audioPlayer.play(BytesSource(audioBytes));
        }
        
        print('VOICEVOX音声再生開始: ${text.length}文字');
        return true;
      } catch (e) {
        print('音声再生エラー: $e');
        return false;
      }
    } catch (e) {
      print('VOICEVOX音声合成エラー: $e');
      return false;
    }
  }
  
  /// 音声再生を停止
  Future<void> stop() async {
    await _audioPlayer.stop();
  }
  
  /// 現在の設定を取得
  Map<String, dynamic> getCurrentSettings() {
    return {
      'host': _host,
      'useLocalEngine': _useLocalEngine,
      'speakerId': _speakerId,
      'speed': _speed,
      'pitch': _pitch,
      'intonation': _intonation,
      'volume': _volume,
    };
  }
  
  /// リソース解放
  void dispose() {
    _audioPlayer.dispose();
  }
}

/// VOICEVOX話者
class VoiceVoxSpeaker {
  final String name;
  final String speakerUuid;
  final List<VoiceVoxStyle> styles;
  final String version;
  
  VoiceVoxSpeaker({
    required this.name,
    required this.speakerUuid,
    required this.styles,
    required this.version,
  });
  
  factory VoiceVoxSpeaker.fromJson(Map<String, dynamic> json) {
    return VoiceVoxSpeaker(
      name: json['name'] ?? '',
      speakerUuid: json['speaker_uuid'] ?? '',
      styles: (json['styles'] as List<dynamic>?)
          ?.map((style) => VoiceVoxStyle.fromJson(style))
          .toList() ?? [],
      version: json['version'] ?? '',
    );
  }
}

/// VOICEVOX音声スタイル
class VoiceVoxStyle {
  final String name;
  final int id;
  final String type;
  
  VoiceVoxStyle({
    required this.name,
    required this.id,
    required this.type,
  });
  
  factory VoiceVoxStyle.fromJson(Map<String, dynamic> json) {
    return VoiceVoxStyle(
      name: json['name'] ?? '',
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
    );
  }
}