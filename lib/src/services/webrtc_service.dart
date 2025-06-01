import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(String)? onIceCandidate;
  Function()? onConnectionStateChange;
  Function(String)? onError;

  bool get isConnected => _peerConnection?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  Future<bool> requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();
    
    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  Future<void> initialize() async {
    try {
      if (!await requestPermissions()) {
        onError?.call('カメラ・マイクの許可が必要です');
        return;
      }

      _peerConnection = await createPeerConnection(_configuration, _constraints);
      
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        try {
          onIceCandidate?.call(jsonEncode({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }));
        } catch (e) {
          print('ICE candidate error: $e');
        }
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        try {
          _remoteStream = stream;
          onRemoteStream?.call(stream);
        } catch (e) {
          print('Remote stream error: $e');
          onError?.call('リモートストリーム取得エラー: $e');
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('Connection state: $state');
        try {
          onConnectionStateChange?.call();
          
          switch (state) {
            case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
              onError?.call('接続に失敗しました');
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
              onError?.call('接続が切断されました');
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
              print('Connection closed');
              break;
            default:
              break;
          }
        } catch (e) {
          print('Connection state change error: $e');
        }
      };

      // Set connection timeout
      Future.delayed(const Duration(seconds: 30), () {
        if (_peerConnection != null && 
            _peerConnection!.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          onError?.call('接続タイムアウト');
        }
      });

      await _createLocalStream();
    } catch (e) {
      onError?.call('WebRTC初期化エラー: $e');
    }
  }

  Future<void> _createLocalStream() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'video': {
          'width': 640,
          'height': 480,
          'frameRate': 30,
        },
        'audio': true,
      });

      _peerConnection!.addStream(_localStream!);
      onLocalStream?.call(_localStream!);
    } catch (e) {
      onError?.call('カメラ・マイクの取得に失敗: $e');
    }
  }

  Future<String?> createOffer() async {
    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      return offer.sdp;
    } catch (e) {
      onError?.call('オファー作成エラー: $e');
      return null;
    }
  }

  Future<String?> createAnswer() async {
    try {
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      return answer.sdp;
    } catch (e) {
      onError?.call('アンサー作成エラー: $e');
      return null;
    }
  }

  Future<void> setRemoteDescription(String sdp, String type) async {
    try {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
    } catch (e) {
      onError?.call('リモート記述設定エラー: $e');
    }
  }

  Future<void> addIceCandidate(String candidateJson) async {
    try {
      final data = jsonDecode(candidateJson);
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ),
      );
    } catch (e) {
      onError?.call('ICE候補追加エラー: $e');
    }
  }

  void toggleCamera() {
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = !track.enabled;
      });
    }
  }

  void toggleMicrophone() {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !track.enabled;
      });
    }
  }

  Future<void> hangUp() async {
    try {
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      await _peerConnection?.close();
      
      _localStream = null;
      _remoteStream = null;
      _peerConnection = null;
    } catch (e) {
      print('Hang up error: $e');
    }
  }

  void dispose() {
    hangUp();
    onLocalStream = null;
    onRemoteStream = null;
    onIceCandidate = null;
    onConnectionStateChange = null;
    onError = null;
  }
}