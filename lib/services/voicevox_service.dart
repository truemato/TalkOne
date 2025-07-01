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
  
  // キャラクターごとの話者情報
  static const Map<String, dynamic> voicevoxSpeakers = {
    '春日部つむぎ': {
      'uuid': '35b2c544-660e-401e-b503-0e14c635303a',
      'styles': {
        'ノーマル': 8,
      }
    },
    'ずんだもん': {
      'uuid': '388f246b-8c41-4ac1-8e2d-5d79f3ff56d9',
      'styles': {
        'ノーマル': 3,
        'あまあま': 1,
        'ツンツン': 7,
        'セクシー': 5,
        'ささやき': 22,
        'ヒソヒソ': 38,
        'ヘロヘロ': 75,
        'なみだめ': 76,
      }
    },
    '四国めたん': {
      'uuid': '7ffcb7ce-00ec-4bdc-82cd-45a8889e43ff',
      'styles': {
        'ノーマル': 2,
        'あまあま': 0,
        'ツンツン': 6,
        'セクシー': 4,
        'ささやき': 36,
        'ヒソヒソ': 37,
      }
    },
    '雨晴はう': {
      'uuid': '3474ee95-c274-47f9-aa1a-8322163d96f1',
      'styles': {
        'ノーマル': 10,
      }
    },
    '青山龍星': {
      'uuid': '4f51116a-d9ee-4516-925d-21f183e2afad',
      'styles': {
        'ノーマル': 13,
        '熱血': 81,
        '不機嫌': 82,
        '喜び': 83,
        'しっとり': 84,
        'かなしみ': 85,
        '囁き': 86,
      }
    },
    '冥鳴ひまり': {
      'uuid': '8eaad775-3119-417e-8cf4-2a10bfd592c8',
      'styles': {
        'ノーマル': 14,
      }
    },
  };
  
  VoiceVoxService({
    String? host,
    bool useLocalEngine = false,
  }) : _host = host ?? (useLocalEngine ? _localHost : _defaultHost),
       _useLocalEngine = useLocalEngine;
  
  /// 話者IDを設定
  void setSpeaker(int speakerId) {
    _speakerId = speakerId;
    print('VOICEVOX話者変更: ID $_speakerId');
  }
  
  /// キャラクターIDに基づいて話者を設定
  void setSpeakerByCharacter(int characterId) {
    // キャラクターIDに対応するVOICEVOX話者IDマッピング
    // 注意: characterId 3は雨晴はうから春日部つむぎに変更されている
    final speakerMapping = {
      0: 8,  // 春日部つむぎ（ノーマル）
      1: 3,  // ずんだもん（ノーマル）
      2: 2,  // 四国めたん（ノーマル）
      3: 8,  // 春日部つむぎ（ノーマル）- 元は雨晴はう
      4: 13, // 青山龍星（ノーマル）
      5: 14, // 冥鳴ひまり（ノーマル）
    };
    
    final voicevoxSpeakerId = speakerMapping[characterId] ?? 3; // デフォルト: ずんだもん
    setSpeaker(voicevoxSpeakerId);
    
    // キャラクターに応じた音声パラメータの調整
    switch (characterId) {
      case 0: // 春日部つむぎ - 落ち着いた知的な声
      case 3: // 春日部つむぎ（ID 3も同じ）
        setVoiceParameters(speed: 0.95, pitch: 0.0, intonation: 1.0);
        break;
      case 1: // ずんだもん - 元気で明るい声
        setVoiceParameters(speed: 1.1, pitch: 0.1, intonation: 1.2);
        break;
      case 2: // 四国めたん - 明るくハキハキした声
        setVoiceParameters(speed: 1.05, pitch: 0.05, intonation: 1.1);
        break;
      case 4: // 青山龍星 - 力強い男性的な声
        setVoiceParameters(speed: 0.9, pitch: -0.1, intonation: 1.1);
        break;
      case 5: // 冥鳴ひまり - ミステリアスで落ち着いた声
        setVoiceParameters(speed: 0.85, pitch: -0.05, intonation: 0.9);
        break;
      default:
        setVoiceParameters(speed: 1.0, pitch: 0.0, intonation: 1.0);
    }
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
    
    print('VOICEVOX Engine接続失敗: ホスト=$_host');
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
  
  /// テキストを音声合成して再生（標準VOICEVOX API使用）
  Future<bool> speak(String text) async {
    if (text.isEmpty) return false;
    
    try {
      print('VOICEVOX音声合成開始: $_host, speaker: $_speakerId, text: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      
      // Step 1: audio_queryでクエリを作成
      final queryUrl = '$_host/audio_query?text=${Uri.encodeComponent(text)}&speaker=$_speakerId';
      print('Audio Query URL: $queryUrl');
      
      final queryResponse = await http.post(
        Uri.parse(queryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      
      print('Audio Query Response: ${queryResponse.statusCode}');
      
      if (queryResponse.statusCode != 200) {
        print('Audio Query失敗: ${queryResponse.statusCode}');
        print('エラーレスポンス: ${queryResponse.body}');
        return false;
      }
      
      // クエリレスポンスを取得してパラメータを適用
      final queryData = json.decode(queryResponse.body);
      queryData['speedScale'] = _speed;
      queryData['pitchScale'] = _pitch;
      queryData['intonationScale'] = _intonation;
      queryData['volumeScale'] = _volume;
      
      // Step 2: synthesisで音声を合成
      final synthesisUrl = '$_host/synthesis?speaker=$_speakerId';
      print('Synthesis URL: $synthesisUrl');
      print('Synthesis request body size: ${json.encode(queryData).length} bytes');
      
      final synthesisResponse = await http.post(
        Uri.parse(synthesisUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'audio/wav',
        },
        body: json.encode(queryData),
      ).timeout(const Duration(seconds: 30));
      
      print('Synthesis Response: ${synthesisResponse.statusCode}');
      print('Audio data size: ${synthesisResponse.bodyBytes.length} bytes');
      
      if (synthesisResponse.statusCode != 200) {
        print('Synthesis API音声合成失敗: ${synthesisResponse.statusCode}');
        print('エラーレスポンス: ${synthesisResponse.body}');
        return false;
      }
      
      // 音声再生（iOS対応）
      final audioBytes = synthesisResponse.bodyBytes;
      
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
          await iosPlayer.setReleaseMode(ReleaseMode.release);
          
          // 再生実行
          await iosPlayer.play(DeviceFileSource(tempFile.path));
          
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