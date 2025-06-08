// lib/services/agora_call_service.dart
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/agora_config.dart';

enum AgoraConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class AgoraCallService {
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  AgoraConnectionState _connectionState = AgoraConnectionState.disconnected;
  
  // コールバック関数
  Function(String uid)? onUserJoined;
  Function(String uid)? onUserLeft;
  Function(AgoraConnectionState)? onConnectionStateChanged;
  Function(String error)? onError;
  
  // 音声レベルコールバック
  Function(int volume)? onAudioVolumeIndication;
  
  // Agora Engineを初期化
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // マイクの権限を確認
      await _requestPermissions();
      
      // Agora Engineを作成
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      
      // イベントハンドラーを設定
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('Agora: チャンネル参加成功 - ${connection.channelId}');
          _setConnectionState(AgoraConnectionState.connected);
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          print('Agora: ユーザー参加 - $uid');
          onUserJoined?.call(uid.toString());
        },
        onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          print('Agora: ユーザー離脱 - $uid');
          onUserLeft?.call(uid.toString());
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          print('Agora: 接続状態変更 - $state');
          switch (state) {
            case ConnectionStateType.connectionStateConnected:
              _setConnectionState(AgoraConnectionState.connected);
              break;
            case ConnectionStateType.connectionStateConnecting:
            case ConnectionStateType.connectionStateReconnecting:
              _setConnectionState(AgoraConnectionState.connecting);
              break;
            case ConnectionStateType.connectionStateDisconnected:
              _setConnectionState(AgoraConnectionState.disconnected);
              break;
            case ConnectionStateType.connectionStateFailed:
              _setConnectionState(AgoraConnectionState.failed);
              onError?.call('接続に失敗しました');
              break;
          }
        },
        onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
          if (speakers.isNotEmpty) {
            final volume = speakers.first.volume ?? 0;
            onAudioVolumeIndication?.call(volume);
          }
        },
        onError: (ErrorCodeType err, String msg) {
          print('Agora エラー: $err - $msg');
          onError?.call('通話エラー: $msg');
        },
      ));
      
      // 音声設定
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );
      
      // 音声レベル監視を有効化
      await _engine!.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );
      
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Agora初期化エラー: $e');
      onError?.call('音声通話の初期化に失敗しました');
      return false;
    }
  }
  
  // 権限を要求
  Future<void> _requestPermissions() async {
    await [Permission.microphone].request();
  }
  
  // チャンネルに参加
  Future<bool> joinChannel(String channelName, {String? token}) async {
    if (!_isInitialized || _engine == null) {
      print('Agora: 初期化されていません');
      return false;
    }
    
    try {
      _setConnectionState(AgoraConnectionState.connecting);
      
      final uid = DateTime.now().millisecondsSinceEpoch % 1000000; // 簡単なUID生成
      
      await _engine!.joinChannel(
        token: "",  // テスト用：空文字列
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );
      
      print('Agora: チャンネル参加開始 - $channelName (UID: $uid)');
      return true;
    } catch (e) {
      print('Agora: チャンネル参加エラー - $e');
      _setConnectionState(AgoraConnectionState.failed);
      onError?.call('通話に参加できませんでした');
      return false;
    }
  }
  
  // チャンネルから離脱
  Future<void> leaveChannel() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      _setConnectionState(AgoraConnectionState.disconnected);
      print('Agora: チャンネルから離脱');
    }
  }
  
  // マイクのミュート切り替え
  Future<void> toggleMute() async {
    if (_engine != null) {
      // 現在のミュート状態を確認する代わりに、シンプルにトグルする
      await _engine!.muteLocalAudioStream(!_isMuted);
      _isMuted = !_isMuted;
      print('Agora: マイク${_isMuted ? "ミュート" : "ミュート解除"}');
    }
  }
  
  // 現在のミュート状態を取得
  Future<bool> isMuted() async {
    return _isMuted;
  }
  
  // 接続状態を更新
  void _setConnectionState(AgoraConnectionState state) {
    _connectionState = state;
    onConnectionStateChanged?.call(state);
  }
  
  // 現在の接続状態を取得
  AgoraConnectionState get connectionState => _connectionState;
  
  // リソース解放
  Future<void> dispose() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
      _isInitialized = false;
      _setConnectionState(AgoraConnectionState.disconnected);
      print('Agora: リソース解放完了');
    }
  }
}