import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/ai_voice_chat_service_voicevox.dart';
import '../services/personality_system.dart';
import '../services/voicevox_service.dart';

class TalkToAIScreen extends StatefulWidget {
  final int personalityId;

  const TalkToAIScreen({
    super.key,
    this.personalityId = 1,
  });

  @override
  State<TalkToAIScreen> createState() => _TalkToAIScreenState();
}

class _TalkToAIScreenState extends State<TalkToAIScreen> {
  late AIVoiceChatServiceVoiceVox _aiService;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _userText = '';
  String _aiResponse = '';
  bool _isAISpeaking = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    final tts = FlutterTts();
    _aiService = AIVoiceChatServiceVoiceVox(speech: _speech, tts: tts);
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize();
    if (!available) {
      print('音声認識が利用できません');
    }
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _userText = result.recognizedWords;
            });
            if (result.finalResult) {
              _processUserInput(result.recognizedWords);
            }
          },
          localeId: 'ja_JP',
        );
      }
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _processUserInput(String text) async {
    setState(() {
      _isAISpeaking = true;
      _aiResponse = '考え中...';
    });

    try {
      final response = await _aiService.processConversation(text);
      
      setState(() {
        _aiResponse = response;
      });
    } catch (e) {
      setState(() {
        _aiResponse = 'エラーが発生しました: $e';
      });
    } finally {
      setState(() {
        _isAISpeaking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final personality = PersonalitySystem.personalities[widget.personalityId] ?? {
      'name': '四国めたん',
      'description': '元気で明るい四国のご当地キャラクター',
      'emoji': '🌟',
      'themeColor': Colors.orange,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('${personality['name']}と会話'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // AI人格情報
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: personality['themeColor'] ?? Colors.orange,
                      child: Text(
                        personality['emoji'] ?? '🌟',
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      personality['name'] ?? 'AI',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      personality['description'] ?? '',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 会話内容表示
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_userText.isNotEmpty) ...[
                        const Text(
                          'あなた:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(_userText),
                        const SizedBox(height: 16),
                      ],
                      if (_aiResponse.isNotEmpty) ...[
                        Text(
                          '${personality['name']}:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: personality['themeColor'] ?? Colors.orange,
                          ),
                        ),
                        Text(_aiResponse),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 音声入力ボタン
            Center(
              child: GestureDetector(
                onTapDown: (_) => _startListening(),
                onTapUp: (_) => _stopListening(),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red : (personality['themeColor'] ?? Colors.orange),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            Text(
              _isListening ? '話してください...' : 'ボタンを押して話す',
              style: const TextStyle(fontSize: 16),
            ),
            
            if (_isAISpeaking)
              const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    _aiService.dispose();
    super.dispose();
  }
}