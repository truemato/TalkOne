// lib/screens/video_call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/agora_call_service.dart';
import '../services/call_matching_service.dart';
import '../services/ai_filter_service.dart';
import '../config/agora_config.dart';
import 'evaluation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String callId;
  final String partnerId;
  final bool enableAIFilter;
  final bool privacyMode;

  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.callId,
    required this.partnerId,
    this.enableAIFilter = false,
    this.privacyMode = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with TickerProviderStateMixin {
  final AgoraCallService _agoraService = AgoraCallService();
  final CallMatchingService _matchingService = CallMatchingService();
  final AIFilterService _aiFilterService = AIFilterService();
  
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoMuted = false;
  bool _partnerJoined = false;
  int _remainingSeconds = AgoraConfig.callDurationSeconds;
  String _connectionStatus = '接続中...';
  int? _remoteUid;
  bool _localUserJoined = false;
  
  Timer? _timer;
  bool _callEnded = false;
  bool _isAIFilterEnabled = false;
  double? _userRating;
  bool _hasAIFilterAccess = false;
  
  @override
  void initState() {
    super.initState();
    _checkUserRating();
    _initializeCall();
    _autoEnableAIFilter();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _agoraService.dispose();
    _aiFilterService.dispose();
    super.dispose();
  }
  
  Future<void> _requestPermissions() async {
    // マイク権限
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      throw Exception('マイクのアクセス許可が必要です');
    }
    
    // カメラ権限
    final cameraStatus = await Permission.camera.request();  
    if (cameraStatus != PermissionStatus.granted) {
      throw Exception('カメラのアクセス許可が必要です');
    }
  }
  
  Future<void> _checkUserRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final rating = doc.data()?['rating']?.toDouble() ?? 3.0;
        setState(() {
          _userRating = rating;
          _hasAIFilterAccess = _aiFilterService.hasAccess(rating);
        });
        
        if (_hasAIFilterAccess) {
          await _aiFilterService.initialize();
        }
      }
    }
  }
  
  Future<void> _autoEnableAIFilter() async {
    // プライバシーモードまたはユーザーがAIフィルターを有効にした場合のみ
    if (widget.enableAIFilter && (_hasAIFilterAccess || widget.privacyMode)) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          setState(() {
            _isAIFilterEnabled = true;
          });
          await _aiFilterService.setEnabled(true);
          
          // Pythonコードと同じパラメータを設定
          await _aiFilterService.updateFilterParams(
            threshold1: 100,  // Canny edge detection threshold1
            threshold2: 200,  // Canny edge detection threshold2  
            colorful: true,   // Enable colorful edge effect
          );
          
          if (widget.privacyMode) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('プライバシー保護のためAIフィルターが有効になりました'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      });
    } else {
      // 通常のビデオ通話ではAIフィルターを無効化
      setState(() {
        _isAIFilterEnabled = false;
      });
      await _aiFilterService.setEnabled(false);
      print('通常のビデオ通話：AIフィルター無効');
    }
  }
  
  Future<void> _initializeCall() async {
    // Agoraコールバック設定
    _agoraService.onUserJoined = (uid) {
      if (!mounted) return;
      setState(() {
        _remoteUid = int.parse(uid);
        _partnerJoined = true;
        _connectionStatus = 'ビデオ通話中';
      });
      _startCallTimer();
      print('相手が参加しました: $uid');
    };
    
    _agoraService.onUserLeft = (uid) {
      if (!mounted) return;
      print('相手が退出しました: $uid');
      setState(() {
        _remoteUid = null;
        _partnerJoined = false;
        _connectionStatus = '相手が退出しました';
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _endCall(reason: '相手が通話を終了しました');
        }
      });
    };
    
    _agoraService.onConnectionStateChanged = (state) {
      if (!mounted) return;
      setState(() {
        _isConnected = state == AgoraConnectionState.connected;
        switch (state) {
          case AgoraConnectionState.connecting:
            _connectionStatus = '接続中...';
            break;
          case AgoraConnectionState.connected:
            _connectionStatus = '接続完了';
            _localUserJoined = true;
            break;
          case AgoraConnectionState.disconnected:
            _connectionStatus = '接続切断';
            if (_partnerJoined) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted) {
                  _endCall(reason: '接続が切断されました');
                }
              });
            }
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
    
    // Agora初期化
    final initialized = await _agoraService.initialize();
    if (!initialized) {
      _showErrorDialog('ビデオ通話の初期化に失敗しました');
      return;
    }
    
    // ビデオを有効化
    await _agoraService.enableVideo();
    
    // チャンネル参加
    final joined = await _agoraService.joinChannel(widget.channelName);
    if (!joined) {
      _showErrorDialog('通話チャンネルへの参加に失敗しました');
      return;
    }
    
    if (mounted) {
      setState(() {
        _connectionStatus = '相手の参加を待っています...';
      });
    }
  }
  
  void _startCallTimer() {
    if (_timer != null) return;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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
    if (mounted) {
      setState(() {
        _isMuted = muted;
      });
    }
  }
  
  Future<void> _toggleVideo() async {
    setState(() {
      _isVideoMuted = !_isVideoMuted;
    });
    await _agoraService.muteLocalVideo(_isVideoMuted);
  }
  
  Future<void> _switchCamera() async {
    await _agoraService.switchCamera();
  }
  
  void _endCall({String reason = '通話を終了しました'}) {
    if (_callEnded) return;
    _callEnded = true;
    
    print('通話終了処理開始: $reason');
    _timer?.cancel();
    
    // 通話終了を記録
    _matchingService.finishCall(widget.callId);
    
    // Agoraから離脱
    _agoraService.leaveChannel();
    
    // 評価画面に直接遷移
    _navigateToEvaluation();
  }
  
  void _navigateToEvaluation() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => EvaluationScreen(
          callId: widget.callId,
          partnerId: widget.partnerId,
          isDummyMatch: false,
        ),
      ),
      (route) => false,
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
  
  void _showAIFilterSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        double tempThreshold1 = _aiFilterService.threshold1.toDouble();
        double tempThreshold2 = _aiFilterService.threshold2.toDouble();
        bool tempColorful = _aiFilterService.enableColorful;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('AIフィルター設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('エッジ検出感度'),
                  Slider(
                    value: tempThreshold1,
                    min: 50,
                    max: 200,
                    divisions: 30,
                    label: tempThreshold1.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        tempThreshold1 = value;
                      });
                    },
                  ),
                  const Text('エッジ検出強度'),
                  Slider(
                    value: tempThreshold2,
                    min: 100,
                    max: 300,
                    divisions: 40,
                    label: tempThreshold2.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        tempThreshold2 = value;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('カラフルエフェクト'),
                    value: tempColorful,
                    onChanged: (value) {
                      setState(() {
                        tempColorful = value ?? true;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () async {
                    await _aiFilterService.updateFilterParams(
                      threshold1: tempThreshold1.round(),
                      threshold2: tempThreshold2.round(),
                      colorful: tempColorful,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('適用'),
                ),
              ],
            );
          },
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
      body: SafeArea(
        child: Stack(
          children: [
            // リモートビデオ（全画面）
            if (_remoteUid != null)
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _agoraService.engine!,
                  canvas: VideoCanvas(uid: _remoteUid),
                  connection: RtcConnection(channelId: widget.channelName),
                ),
              )
            else
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '相手の参加を待っています...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            
            // ローカルビデオ（小さく右上に）
            if (_localUserJoined && !_isVideoMuted)
              Positioned(
                top: 100,
                right: 16,
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _agoraService.engine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            
            // 上部の情報バー
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 接続状態
                    Text(
                      _connectionStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    // タイマー
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 下部のコントロールボタン
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // カメラ切り替え
                  _ControlButton(
                    icon: Icons.cameraswitch,
                    onPressed: _switchCamera,
                    backgroundColor: Colors.grey[700]!,
                  ),
                  
                  // ビデオON/OFF
                  _ControlButton(
                    icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                    onPressed: _toggleVideo,
                    backgroundColor: _isVideoMuted ? Colors.red : Colors.grey[700]!,
                  ),
                  
                  // 通話終了
                  _ControlButton(
                    icon: Icons.call_end,
                    onPressed: () => _endCall(),
                    backgroundColor: Colors.red,
                    size: 70,
                    iconSize: 35,
                  ),
                  
                  // マイクON/OFF
                  _ControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: _toggleMute,
                    backgroundColor: _isMuted ? Colors.red : Colors.grey[700]!,
                  ),
                  
                  // 美顔フィルター
                  _ControlButton(
                    icon: Icons.face_retouching_natural,
                    onPressed: () async {
                      await _agoraService.setBeautyEffect();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('美顔フィルターを適用しました'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    backgroundColor: Colors.grey[700]!,
                  ),
                  
                  // AIフィルター（アメニティ機能）
                  if (_hasAIFilterAccess)
                    GestureDetector(
                      onLongPress: widget.privacyMode ? null : _showAIFilterSettings,
                      child: _ControlButton(
                        icon: _isAIFilterEnabled 
                            ? Icons.blur_on 
                            : Icons.blur_off,
                        onPressed: widget.privacyMode 
                            ? () {} // プライバシーモードでは無効化（空の関数）
                            : () async {
                                setState(() {
                                  _isAIFilterEnabled = !_isAIFilterEnabled;
                                });
                                await _aiFilterService.setEnabled(_isAIFilterEnabled);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_isAIFilterEnabled 
                                        ? 'AIフィルターを有効にしました（長押しで設定）' 
                                        : 'AIフィルターを無効にしました'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                        backgroundColor: widget.privacyMode
                            ? Colors.red // プライバシーモードでは赤色表示
                            : _isAIFilterEnabled 
                                ? Colors.purple 
                                : Colors.grey[700]!,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// コントロールボタンウィジェット
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final double size;
  final double iconSize;
  
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    this.size = 56,
    this.iconSize = 28,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: iconSize),
        color: Colors.white,
        onPressed: onPressed,
      ),
    );
  }
}