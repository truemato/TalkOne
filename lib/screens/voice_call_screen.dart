// lib/screens/voice_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/agora_call_service.dart';
import '../services/call_matching_service.dart';
import '../config/agora_config.dart';

class VoiceCallScreen extends StatefulWidget {
  final String channelName;
  final String callId;
  final String partnerId;

  const VoiceCallScreen({
    super.key,
    required this.channelName,
    required this.callId,
    required this.partnerId,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  final AgoraCallService _agoraService = AgoraCallService();
  final CallMatchingService _matchingService = CallMatchingService();
  
  bool _isConnected = false;
  bool _isMuted = false;
  bool _partnerJoined = false;
  int _remainingSeconds = AgoraConfig.callDurationSeconds;
  String _connectionStatus = '接続中...';
  int _myVolume = 0;
  int _partnerVolume = 0;
  
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
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
    
    _initializeCall();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _agoraService.dispose();
    super.dispose();
  }
  
  Future<void> _initializeCall() async {
    // Agoraコールバック設定
    _agoraService.onUserJoined = (uid) {
      setState(() {
        _partnerJoined = true;
        _connectionStatus = '通話中';
      });
      _startCallTimer();
      print('相手が参加しました: $uid');
    };
    
    _agoraService.onUserLeft = (uid) {
      setState(() {
        _partnerJoined = false;
        _connectionStatus = '相手が退出しました';
      });
      _endCall(reason: '相手が通話を終了しました');
      print('相手が退出しました: $uid');
    };
    
    _agoraService.onConnectionStateChanged = (state) {
      setState(() {
        _isConnected = state == AgoraConnectionState.connected;
        switch (state) {
          case AgoraConnectionState.connecting:
            _connectionStatus = '接続中...';
            break;
          case AgoraConnectionState.connected:
            _connectionStatus = '接続完了';
            break;
          case AgoraConnectionState.disconnected:
            _connectionStatus = '接続切断';
            break;
          case AgoraConnectionState.failed:
            _connectionStatus = '接続失敗';
            break;
          case AgoraConnectionState.reconnecting:
            _connectionStatus = '再接続中...';
            break;
        }
      });
    };
    
    _agoraService.onError = (error) {
      _showErrorDialog(error);
    };
    
    _agoraService.onAudioVolumeIndication = (volume) {
      setState(() {
        _myVolume = volume;
      });
      
      // ボリュームに応じてパルスアニメーション
      if (volume > 10) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    };
    
    // Agora初期化
    final initialized = await _agoraService.initialize();
    if (!initialized) {
      _showErrorDialog('音声通話の初期化に失敗しました');
      return;
    }
    
    // チャンネル参加
    final joined = await _agoraService.joinChannel(widget.channelName);
    if (!joined) {
      _showErrorDialog('通話チャンネルへの参加に失敗しました');
      return;
    }
    
    setState(() {
      _connectionStatus = '相手の参加を待っています...';
    });
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
  
  Future<void> _toggleMute() async {
    await _agoraService.toggleMute();
    final muted = await _agoraService.isMuted();
    setState(() {
      _isMuted = muted;
    });
  }
  
  void _endCall({String reason = '通話を終了しました'}) {
    _timer?.cancel();
    
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
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
                Navigator.of(context).pop(); // 通話画面を閉じる
                Navigator.of(context).pop(); // マッチング画面を閉じる
              },
              child: const Text('ホームに戻る'),
            ),
          ],
        );
      },
    );
  }
  
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('エラー'),
          content: Text(error),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('戻る'),
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
          onPressed: () => _endCall(reason: '通話をキャンセルしました'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
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
                        scale: _partnerJoined && _partnerVolume > 10 
                            ? _pulseAnimation.value 
                            : 1.0,
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
                    _partnerJoined ? '相手' : '相手を待っています...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
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
                    _isMuted ? 'ミュート中' : 'あなた',
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