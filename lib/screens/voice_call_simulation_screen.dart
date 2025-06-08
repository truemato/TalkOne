// lib/screens/voice_call_simulation_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/call_matching_service.dart';
import '../config/agora_config.dart';

class VoiceCallSimulationScreen extends StatefulWidget {
  final String channelName;
  final String callId;
  final String partnerId;

  const VoiceCallSimulationScreen({
    super.key,
    required this.channelName,
    required this.callId,
    required this.partnerId,
  });

  @override
  State<VoiceCallSimulationScreen> createState() => _VoiceCallSimulationScreenState();
}

class _VoiceCallSimulationScreenState extends State<VoiceCallSimulationScreen>
    with TickerProviderStateMixin {
  final CallMatchingService _matchingService = CallMatchingService();
  
  bool _isConnected = true;
  bool _isMuted = false;
  bool _partnerJoined = true;
  int _remainingSeconds = AgoraConfig.callDurationSeconds;
  String _connectionStatus = '通話中（シミュレーション）';
  int _myVolume = 0;
  int _partnerVolume = 0;
  
  Timer? _timer;
  Timer? _volumeSimulationTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    
    // パルスアニメーション設定
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _startCallTimer();
    _startVolumeSimulation();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _volumeSimulationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
  
  void _startCallTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        _endCall(reason: '通話時間が終了しました');
      }
    });
  }
  
  void _startVolumeSimulation() {
    _volumeSimulationTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) return;
      
      setState(() {
        // 自分の音声レベル（ミュート時は0）
        _myVolume = _isMuted ? 0 : _random.nextInt(30);
        
        // 相手の音声レベル（シンプルなランダム）
        if (_random.nextDouble() < 0.3) {
          // 30%の確率で相手が話す
          _partnerVolume = 20 + _random.nextInt(25);
        } else {
          // 70%の確率で静か
          _partnerVolume = _random.nextInt(5);
        }
      });
      
      // パルスアニメーション制御
      if (_myVolume > 15 || _partnerVolume > 15) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }
  
  
  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMuted ? 'マイクをミュートしました' : 'マイクのミュートを解除しました'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  void _endCall({String reason = '通話を終了しました'}) {
    _timer?.cancel();
    _volumeSimulationTimer?.cancel();
    
    // 通話終了を記録
    _matchingService.finishCall(widget.callId);
    
    _showCallEndDialog(reason);
  }
  
  void _showCallEndDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('通話終了'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.call_end,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(reason),
              const SizedBox(height: 16),
              Text(
                '通話時間: ${_formatTime(AgoraConfig.callDurationSeconds - _remainingSeconds)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '※ これはシミュレーション画面です\n実際の音声通話にはAgoraの設定が必要です',
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
                // 安全にホーム画面に戻る
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('ホームに戻る'),
            ),
          ],
        );
      },
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  String _getPartnerStatusText() {
    return '相手（音声レベル: $_partnerVolume）';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_connectionStatus),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _timer?.cancel();
            _volumeSimulationTimer?.cancel();
            _matchingService.finishCall(widget.callId);
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // シミュレーション表示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.science, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'シミュレーションモード',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '音声は聞こえません - 視覚的なデモのみ',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // タイマー表示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // 相手の状態表示
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _partnerVolume > 10 ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _partnerJoined 
                                ? Colors.green.withOpacity(0.7)
                                : Colors.grey.withOpacity(0.7),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            _partnerJoined ? Icons.person : Icons.person_outline,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getPartnerStatusText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              
              // 自分の状態表示
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _myVolume > 10 ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isMuted 
                                ? Colors.red.withOpacity(0.7)
                                : Colors.blue.withOpacity(0.7),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            _isMuted ? Icons.mic_off : Icons.mic,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isMuted ? 'ミュート中' : 'あなた（音声レベル: $_myVolume）',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              
              // 通話コントロール
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // ミュートボタン
                  FloatingActionButton(
                    heroTag: "mute",
                    backgroundColor: _isMuted ? Colors.red : Colors.grey[700],
                    foregroundColor: Colors.white,
                    onPressed: _toggleMute,
                    child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                  ),
                  
                  // 通話終了ボタン
                  FloatingActionButton(
                    heroTag: "end_call",
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    onPressed: () => _endCall(),
                    child: const Icon(Icons.call_end, size: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}