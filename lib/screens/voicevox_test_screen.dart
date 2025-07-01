import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/voicevox_service.dart';

/// VOICEVOX機能テスト画面
/// TalkOne-testから復活させた開発者向けテストページ
class VoicevoxTestScreen extends StatefulWidget {
  const VoicevoxTestScreen({super.key});

  @override
  State<VoicevoxTestScreen> createState() => _VoicevoxTestScreenState();
}

class _VoicevoxTestScreenState extends State<VoicevoxTestScreen> {
  final VoiceVoxService _voiceVoxService = VoiceVoxService(useLocalEngine: false); // 明示的にCloud Runを使用
  final TextEditingController _textController = TextEditingController();
  
  bool _isProcessing = false;
  bool _isEngineAvailable = false;
  String _statusMessage = '接続確認中...';
  int _selectedSpeakerId = 3; // デフォルト: ずんだもん
  double _speed = 1.0;
  double _pitch = 0.0;
  double _intonation = 1.0;
  double _volume = 1.0;
  
  // デバッグ用
  String _debugInfo = '';
  
  // VOICEVOX話者リスト
  final Map<String, int> _speakers = {
    'ずんだもん（ノーマル）': 3,
    '四国めたん（ノーマル）': 2,
    '春日部つむぎ（ノーマル）': 8,
    '青山龍星（ノーマル）': 13,
    '冥鳴ひまり（ノーマル）': 14,
    'ずんだもん（あまあま）': 1,
    'ずんだもん（ツンツン）': 7,
    'ずんだもん（セクシー）': 5,
  };

  @override
  void initState() {
    super.initState();
    _checkEngineAvailability();
    _textController.text = 'こんにちは！VOICEVOX音声合成のテストです。ボクはずんだもんなのだ！';
  }

  @override
  void dispose() {
    _textController.dispose();
    _voiceVoxService.dispose();
    super.dispose();
  }

  Future<void> _checkEngineAvailability() async {
    try {
      final isAvailable = await _voiceVoxService.isEngineAvailable();
      if (mounted) {
        setState(() {
          _isEngineAvailable = isAvailable;
          _statusMessage = isAvailable 
              ? 'VOICEVOX Engine接続成功' 
              : 'VOICEVOX Engine接続失敗（ローカル・クラウド両方とも）';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEngineAvailable = false;
          _statusMessage = 'Engine確認エラー: $e';
        });
      }
    }
  }

  Future<void> _testSpeech() async {
    if (!_isEngineAvailable) {
      _showSnackBar('VOICEVOX Engineが利用できません');
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('テキストを入力してください');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // デバッグ情報を表示
      print('=== VOICEVOXテスト開始 ===');
      print('テキスト: $text');
      print('話者ID: $_selectedSpeakerId');
      print('パラメータ: speed=$_speed, pitch=$_pitch, intonation=$_intonation, volume=$_volume');
      
      // 音声パラメータを設定
      _voiceVoxService.setSpeaker(_selectedSpeakerId);
      _voiceVoxService.setVoiceParameters(
        speed: _speed,
        pitch: _pitch,
        intonation: _intonation,
        volume: _volume,
      );

      // 音声合成・再生実行
      final success = await _voiceVoxService.speak(text);
      
      print('VOICEVOX speak結果: $success');
      print('=== VOICEVOXテスト終了 ===');
      
      if (mounted) {
        _showSnackBar(success ? '音声再生開始' : '音声合成に失敗しました');
      }
    } catch (e, stackTrace) {
      print('❌ VOICEVOXテストエラー: $e');
      print('スタックトレース: $stackTrace');
      if (mounted) {
        _showSnackBar('エラー: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _stopSpeech() async {
    await _voiceVoxService.stop();
    if (mounted) {
      _showSnackBar('音声再生停止');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // シンプルなオーディオテスト
  Future<void> _testSimpleAudio() async {
    setState(() {
      _debugInfo = 'オーディオテスト中...';
    });
    
    try {
      print('=== シンプルオーディオテスト ===');
      final player = AudioPlayer();
      
      // シンプルなサウンドを再生
      await player.play(AssetSource('sounds/notification.mp3')).catchError((e) {
        print('アセットがないため、URLから再生を試みます: $e');
        return player.play(UrlSource('https://www.soundjay.com/misc/sounds/bell-ringing-05.wav'));
      });
      
      setState(() {
        _debugInfo = 'オーディオ再生成功\nAudioPlayerは正常に動作しています';
      });
      
      _showSnackBar('オーディオテスト成功');
      print('=== オーディオテスト成功 ===');
    } catch (e) {
      print('❌ オーディオテスト失敗: $e');
      setState(() {
        _debugInfo = 'オーディオ再生失敗:\n$e';
      });
      _showSnackBar('オーディオテスト失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF81C784), // ずんだもんカラー
      appBar: AppBar(
        title: Text(
          'VOICEVOX テスト',
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF66BB6A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Engine状態表示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isEngineAvailable 
                      ? Colors.green.withOpacity(0.2) 
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isEngineAvailable ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isEngineAvailable ? Icons.check_circle : Icons.error,
                          color: _isEngineAvailable ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Engine状態',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _checkEngineAvailability,
                      icon: const Icon(Icons.refresh),
                      label: const Text('再接続'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF81C784),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 話者選択
              Text(
                '話者選択',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  value: _selectedSpeakerId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _speakers.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.value,
                      child: Text(
                        entry.key,
                        style: GoogleFonts.notoSans(),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedSpeakerId = value;
                      });
                    }
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 音声パラメータ調整
              Text(
                '音声パラメータ',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildSlider('話速', _speed, 0.5, 2.0, (value) {
                setState(() {
                  _speed = value;
                });
              }),
              
              _buildSlider('音高', _pitch, -0.15, 0.15, (value) {
                setState(() {
                  _pitch = value;
                });
              }),
              
              _buildSlider('抑揚', _intonation, 0.0, 2.0, (value) {
                setState(() {
                  _intonation = value;
                });
              }),
              
              _buildSlider('音量', _volume, 0.0, 2.0, (value) {
                setState(() {
                  _volume = value;
                });
              }),
              
              const SizedBox(height: 20),
              
              // テキスト入力
              Text(
                'テスト文章',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLines: 4,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'ここにテスト文章を入力してください...',
                  hintStyle: GoogleFonts.notoSans(color: Colors.grey),
                ),
                style: GoogleFonts.notoSans(),
              ),
              
              const SizedBox(height: 20),
              
              // 制御ボタン
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isEngineAvailable && !_isProcessing ? _testSpeech : null,
                      icon: _isProcessing 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_isProcessing ? '合成中...' : '音声合成・再生'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _stopSpeech,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Engine設定情報
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Engine設定',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _voiceVoxService.getCurrentSettings().toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (_debugInfo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'デバッグ情報:\n$_debugInfo',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.yellow,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // オーディオテストボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _testSimpleAudio,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('シンプルオーディオテスト'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                value.toStringAsFixed(2),
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.1),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}