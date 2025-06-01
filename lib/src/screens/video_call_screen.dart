import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import '../services/matching_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final String peerId;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.peerId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webrtc = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isConnected = false;
  bool _isCameraOn = true;
  bool _isMicOn = true;
  String _connectionStatus = '接続中...';

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _setupWebRTC();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupWebRTC() {
    _webrtc.onLocalStream = (stream) {
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    _webrtc.onRemoteStream = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
        _isConnected = true;
        _connectionStatus = '接続済み';
      });
    };

    _webrtc.onConnectionStateChange = () {
      setState(() {
        _isConnected = _webrtc.isConnected;
        _connectionStatus = _isConnected ? '接続済み' : '接続中...';
      });
    };

    _webrtc.onError = (error) {
      setState(() {
        _connectionStatus = 'エラー: $error';
      });
      _showErrorDialog(error);
    };
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('接続エラー'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _hangUp();
            },
            child: const Text('終了'),
          ),
        ],
      ),
    );
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    _webrtc.toggleCamera();
  }

  void _toggleMicrophone() {
    setState(() {
      _isMicOn = !_isMicOn;
    });
    _webrtc.toggleMicrophone();
  }

  void _hangUp() {
    MatchingService.endCall();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: _remoteRenderer.srcObject != null
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person,
                              size: 100,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _connectionStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Local video (picture-in-picture)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _localRenderer.srcObject != null
                      ? RTCVideoView(
                          _localRenderer,
                          mirror: true,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.videocam_off,
                            color: Colors.white54,
                            size: 40,
                          ),
                        ),
                ),
              ),
            ),

            // Status bar
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected ? Icons.videocam : Icons.wifi_tethering,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _connectionStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Control buttons
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Toggle camera
                  Container(
                    decoration: BoxDecoration(
                      color: _isCameraOn ? Colors.white.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _toggleCamera,
                      icon: Icon(
                        _isCameraOn ? Icons.videocam : Icons.videocam_off,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                  // Hang up
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _hangUp,
                      icon: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Toggle microphone
                  Container(
                    decoration: BoxDecoration(
                      color: _isMicOn ? Colors.white.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _toggleMicrophone,
                      icon: Icon(
                        _isMicOn ? Icons.mic : Icons.mic_off,
                        color: Colors.white,
                        size: 28,
                      ),
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