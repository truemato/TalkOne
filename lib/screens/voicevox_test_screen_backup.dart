import 'package:flutter/material.dart';
import '../services/voicevox_service.dart';

/// VOICEVOX機能テスト画面
/// 
/// 音声合成の動作確認と設定変更が可能
class VoiceVoxTestScreen extends StatefulWidget {
  const VoiceVoxTestScreen({super.key});

  @override
  State<VoiceVoxTestScreen> createState() => _VoiceVoxTestScreenState();
}

class _VoiceVoxTestScreenState extends State<VoiceVoxTestScreen> {
  final VoiceVoxService _voiceVoxService = VoiceVoxService();
  final TextEditingController _textController = TextEditingController();
  
  bool _isEngineAvailable = false;
  bool _isPlaying = false;
  List<VoiceVoxSpeaker> _speakers = [];
  VoiceVoxSpeaker? _selectedSpeaker;
  VoiceVoxStyle? _selectedStyle;
  
  // 音声パラメータ
  double _speed = 1.0;
  double _pitch = 0.0;
  double _intonation = 1.0;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _textController.text = "こんにちは、VOICEVOXのテストです。";
    _checkEngineAndLoadSpeakers();
  }

  Future<void> _checkEngineAndLoadSpeakers() async {
    setState(() => _isEngineAvailable = false);
    
    // エンジンの可用性チェック
    final available = await _voiceVoxService.isEngineAvailable();
    setState(() => _isEngineAvailable = available);
    
    if (available) {
      // 話者リストの取得
      final speakers = await _voiceVoxService.getSpeakers();
      setState(() {
        _speakers = speakers;
        if (speakers.isNotEmpty) {
          _selectedSpeaker = speakers.first;
          if (_selectedSpeaker!.styles.isNotEmpty) {
            _selectedStyle = _selectedSpeaker!.styles.first;
            _voiceVoxService.setSpeaker(_selectedStyle!.id);
          }
        }
      });
    }
  }

  Future<void> _testSpeech() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テキストを入力してください')),
      );
      return;
    }

    setState(() => _isPlaying = true);
    
    // 音声パラメータの適用
    _voiceVoxService.setVoiceParameters(
      speed: _speed,
      pitch: _pitch,
      intonation: _intonation,
      volume: _volume,
    );

    try {
      final success = await _voiceVoxService.speak(_textController.text);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('音声合成に失敗しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _stopSpeech() async {
    await _voiceVoxService.stop();
    setState(() => _isPlaying = false);
  }

  void _onSpeakerChanged(VoiceVoxSpeaker? speaker) {
    setState(() {
      _selectedSpeaker = speaker;
      if (speaker != null && speaker.styles.isNotEmpty) {
        _selectedStyle = speaker.styles.first;
        _voiceVoxService.setSpeaker(_selectedStyle!.id);
      }
    });
  }

  void _onStyleChanged(VoiceVoxStyle? style) {
    setState(() {
      _selectedStyle = style;
      if (style != null) {
        _voiceVoxService.setSpeaker(style.id);
      }
    });
  }

  Widget _buildEngineStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  'VOICEVOX Engine: ${_isEngineAvailable ? "接続中" : "未接続"}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('ホスト: ${_voiceVoxService.getCurrentSettings()["host"]}'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkEngineAndLoadSpeakers,
              child: const Text('再接続'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakerSelection() {
    if (!_isEngineAvailable || _speakers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '話者選択',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<VoiceVoxSpeaker>(
              value: _selectedSpeaker,
              isExpanded: true,
              items: _speakers.map((speaker) {
                return DropdownMenuItem(
                  value: speaker,
                  child: Text(speaker.name),
                );
              }).toList(),
              onChanged: _onSpeakerChanged,
            ),
            if (_selectedSpeaker != null && _selectedSpeaker!.styles.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('音声スタイル'),
              DropdownButton<VoiceVoxStyle>(
                value: _selectedStyle,
                isExpanded: true,
                items: _selectedSpeaker!.styles.map((style) {
                  return DropdownMenuItem(
                    value: style,
                    child: Text(style.name),
                  );
                }).toList(),
                onChanged: _onStyleChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceParameters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '音声パラメータ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildSlider('話速', _speed, 0.5, 2.0, (value) {
              setState(() => _speed = value);
            }),
            _buildSlider('音高', _pitch, -0.15, 0.15, (value) {
              setState(() => _pitch = value);
            }),
            _buildSlider('抑揚', _intonation, 0.0, 2.0, (value) {
              setState(() => _intonation = value);
            }),
            _buildSlider('音量', _volume, 0.0, 2.0, (value) {
              setState(() => _volume = value);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 20,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(value.toStringAsFixed(2)),
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'テキスト入力',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '読み上げたいテキストを入力してください',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isEngineAvailable && !_isPlaying ? _testSpeech : null,
                    child: Text(_isPlaying ? '再生中...' : '読み上げ開始'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isPlaying ? _stopSpeech : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('停止'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VOICEVOX テスト'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildEngineStatus(),
            const SizedBox(height: 16),
            _buildSpeakerSelection(),
            const SizedBox(height: 16),
            _buildVoiceParameters(),
            const SizedBox(height: 16),
            _buildTextInput(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _voiceVoxService.dispose();
    super.dispose();
  }
}