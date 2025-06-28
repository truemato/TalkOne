import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/shikoku_metan_chat_service.dart';
import '../services/user_profile_service.dart';
import '../services/voicevox_service.dart';
import 'evaluation_screen.dart';

/// 四国めたんとの3分間会話画面
/// 
/// voice_call_screen.dartに似せたシンプルなUI
/// 音声認識と音声合成による対話機能を提供
class ShikokuMetanCallScreen extends StatefulWidget {
  const ShikokuMetanCallScreen({super.key});

  @override
  State<ShikokuMetanCallScreen> createState() => _ShikokuMetanCallScreenState();
}

class _ShikokuMetanCallScreenState extends State<ShikokuMetanCallScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final VoiceVoxService _voiceVoxService = VoiceVoxService();
  late ShikokuMetanChatService _chatService;
  Timer? _timer;
  int _remainingSeconds = 180; // 3分 = 180秒
  DateTime? _callStartTime;
  
  // UI用の変数
  String? _selectedIconPath;
  int _selectedThemeIndex = 0;
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentTranscript = '';
  String _aiResponse = '';
  bool _isVoiceVoxConnected = false;
  
  // テーマカラー配列（AppThemePaletteと同期）
  final List<Color> _themeColors = [
    const Color(0xFF5A64ED), // Default Blue
    const Color(0xFFE6D283), // Golden
    const Color(0xFFA482E5), // Purple  
    const Color(0xFF83C8E6), // Blue
    const Color(0xFFF0941F), // Orange
  ];
  
  Color get _currentThemeColor => _themeColors[_selectedThemeIndex];

  @override
  void initState() {
    super.initState();
    _chatService = ShikokuMetanChatService();
    _callStartTime = DateTime.now();
    _loadUserProfile();
    _checkVoiceVoxConnection();
    _initializeChat();
    _startTimer();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userProfileService.getUserProfile();
    if (mounted && profile != null) {
      setState(() {
        _selectedIconPath = profile.iconPath;
        _selectedThemeIndex = profile.themeIndex;
      });
    }
  }

  Future<void> _checkVoiceVoxConnection() async {
    final isConnected = await _voiceVoxService.isEngineAvailable();
    if (mounted) {
      setState(() {
        _isVoiceVoxConnected = isConnected;
      });
    }
  }

  Future<void> _initializeChat() async {
    final success = await _chatService.initialize();
    if (success && mounted) {
      setState(() {
        _isInitialized = true;
      });
      // リスナーを設定
      _chatService
        ..onUserSpeech = (text) {
          if (mounted) {
            setState(() {
              _currentTranscript = text;
            });
          }
        }
        ..onAIResponse = (response) {
          if (mounted) {
            setState(() {
              _aiResponse = response;
            });
          }
        }
        ..onListeningStateChanged = (isListening) {
          if (mounted) {
            setState(() {
              _isListening = isListening;
            });
          }
        }
        ..onError = (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $error')),
          );
        };
      
      // 自動的に音声認識を開始
      await _chatService.startListening();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('四国めたんの初期化に失敗しました')),
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _endCall();
      }
    });
  }

  void _endCall() {
    _timer?.cancel();
    _chatService.dispose();
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluationScreen(
          callId: 'shikoku_metan_${DateTime.now().millisecondsSinceEpoch}',
          partnerId: 'shikoku_metan_ai', // 特別なAI ID
          isDummyMatch: true, // AI会話なのでdummyMatchとして扱う
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentThemeColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // 四国めたんアイコン（固定）
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF7CECC6).withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF7CECC6),
                  width: 3,
                ),
              ),
              child: const Center(
                child: Text(
                  '🍀',
                  style: TextStyle(fontSize: 80),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 四国めたんの名前
            const Text(
              '四国めたん',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // AI状態表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isListening ? 'あなたの話を聞いています...' : 
                _aiResponse.isNotEmpty ? '話しています...' : '準備中...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // VOICEVOX接続状態表示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isVoiceVoxConnected ? Icons.check_circle : Icons.error,
                  color: _isVoiceVoxConnected ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'VOICEVOX: ${_isVoiceVoxConnected ? "接続済み" : "未接続"}',
                  style: TextStyle(
                    color: _isVoiceVoxConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _checkVoiceVoxConnection,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '再接続',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // タイマー表示
            Text(
              _formatTime(_remainingSeconds),
              style: GoogleFonts.notoSans(
                fontSize: 72,
                fontWeight: FontWeight.w300,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            // 現在の会話内容表示
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // ユーザーの発話
                    if (_currentTranscript.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentTranscript,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // AIの応答
                    if (_aiResponse.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7CECC6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Text('🍀', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _aiResponse,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 通話終了ボタン
            Padding(
              padding: const EdgeInsets.all(32),
              child: ElevatedButton(
                onPressed: _endCall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(24),
                ),
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chatService.dispose();
    super.dispose();
  }
}