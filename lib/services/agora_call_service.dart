// lib/services/agora_call_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/agora_config.dart';
import 'agora_token_service.dart';

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
  bool _isVideoEnabled = false;
  bool _isFrontCamera = true;
  AgoraConnectionState _connectionState = AgoraConnectionState.disconnected;
  
  // トークン管理
  String? _currentToken;
  String? _currentChannelName;
  int? _currentUid;
  Timer? _tokenRefreshTimer;
  
  // コールバック関数
  Function(String uid)? onUserJoined;
  Function(String uid)? onUserLeft;
  Function(AgoraConnectionState)? onConnectionStateChanged;
  Function(String error)? onError;
  
  // 音声レベルコールバック
  Function(int volume)? onAudioVolumeIndication;
  
  // ビデオコールバック
  Function(String uid, int width, int height)? onRemoteVideoStats;
  
  // エンジンのgetter（ビデオ通話で必要）
  RtcEngine? get engine => _engine;
  
  // 接続テスト用の簡単なメソッド
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized) {
        final success = await initialize();
        if (!success) return false;
      }
      
      // テスト用チャンネルに参加してすぐ離脱
      final testChannelName = 'test_connection_${DateTime.now().millisecondsSinceEpoch}';
      print('Agora: 接続テスト開始 - $testChannelName');
      
      await _engine!.joinChannel(
        token: '',
        channelId: testChannelName,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
      
      // 2秒待って離脱
      await Future.delayed(const Duration(seconds: 2));
      await _engine!.leaveChannel();
      
      print('Agora: 接続テスト完了');
      return true;
    } catch (e) {
      print('Agora: 接続テストエラー - $e');
      return false;
    }
  }
  
  // Agora Engineを初期化
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      print('Agora: 初期化開始 - App ID: ${AgoraConfig.appId}');
      
      // 権限確認（ホーム画面で実行済みのため、状態のみ確認）
      await _checkPermissions();
      
      // 既存のエンジンがあれば解放
      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }
      
      // Agora Engineを作成
      print('Agora: エンジン作成開始...');
      _engine = createAgoraRtcEngine();
      
      if (_engine == null) {
        throw Exception('Agora RTC Engineの作成に失敗しました');
      }
      
      // エンジン初期化（iOS用の安全な設定）
      print('Agora: エンジン初期化開始...');
      print('Agora: 使用するApp ID: ${AgoraConfig.appId}');
      print('Agora: App ID長さ: ${AgoraConfig.appId.length}');
      
      await _engine!.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        audioScenario: AudioScenarioType.audioScenarioDefault, // 安定した設定
      ));
      
      print('Agora: 基本設定を適用中...');
      
      // 最小限の設定で初期化
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      
      // 基本的な音声設定のみ
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioDefault,
      );
      
      print('Agora: Engine初期化完了（基本設定）');
      
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
          print('Agora: ユーザー離脱 - $uid (理由: $reason)');
          
          // 離脱理由に関係なく通知（ネットワーク切断、アプリ終了、手動切断など）
          String reasonText = '';
          switch (reason) {
            case UserOfflineReasonType.userOfflineQuit:
              reasonText = '手動で通話を終了';
              break;
            case UserOfflineReasonType.userOfflineDropped:
              reasonText = 'ネットワーク切断';
              break;
            case UserOfflineReasonType.userOfflineBecomeAudience:
              reasonText = '視聴者モードに変更';
              break;
          }
          print('Agora: 離脱理由詳細 - $reasonText');
          
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
          print('エラーコード詳細: ${err.toString()}');
          
          String userFriendlyMessage = 'エラーが発生しました';
          switch (err) {
            case ErrorCodeType.errInvalidAppId:
              userFriendlyMessage = 'アプリIDが無効です';
              break;
            case ErrorCodeType.errInvalidChannelName:
              userFriendlyMessage = 'チャンネル名が無効です';
              break;
            case ErrorCodeType.errNoServerResources:
              userFriendlyMessage = 'サーバーリソースが不足しています';
              break;
            case ErrorCodeType.errTokenExpired:
              userFriendlyMessage = 'トークンの有効期限が切れています';
              break;
            case ErrorCodeType.errInvalidToken:
              userFriendlyMessage = 'トークンが無効です';
              break;
            case ErrorCodeType.errConnectionInterrupted:
              userFriendlyMessage = 'ネットワーク接続が中断されました';
              break;
            case ErrorCodeType.errConnectionLost:
              userFriendlyMessage = 'ネットワーク接続が失われました';
              break;
            default:
              userFriendlyMessage = '通話エラー: $msg';
          }
          
          onError?.call(userFriendlyMessage);
        },
      ));
      
      // 音声を有効化（念のため）
      await _engine!.enableAudio(); // ローカルキャプチャ ON
      await _engine!.setDefaultAudioRouteToSpeakerphone(true); // iOS/Android共通でスピーカー出力
      
      // プラットフォーム別の追加設定
      await _engine!.setChannelProfile(ChannelProfileType.channelProfileCommunication);
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      
      // Android特有の設定
      if (Platform.isAndroid) {
        print('Agora: Android追加設定適用中...');
        // オーディオプロファイルを明示的に設定
        await _engine!.setAudioProfile(
          profile: AudioProfileType.audioProfileDefault,
          scenario: AudioScenarioType.audioScenarioDefault,
        );
        // マイクを有効化
        await _engine!.enableLocalAudio(true);
        print('Agora: Android追加設定完了');
      }
      
      // 音声レベル監視を有効化
      await _engine!.enableAudioVolumeIndication(
        interval: 500,
        smooth: 3,
        reportVad: true,
      );
      
      print('Agora: 音声設定完了（iOS最適化適用）');
      
      _isInitialized = true;
      print('Agora: 初期化完了');
      return true;
    } catch (e) {
      print('Agora初期化エラー: $e');
      print('エラーの詳細: ${e.toString()}');
      
      if (e is AgoraRtcException) {
        print('エラーコード: ${e.code}');
        // エラーコードの詳細
        switch (e.code) {
          case -4:
            print('エラー: Invalid App ID - App IDが無効です');
            print('現在のApp ID: "${AgoraConfig.appId}"');
            print('App IDの文字数: ${AgoraConfig.appId.length}');
            break;
          case -2:
            print('エラー: Invalid Argument - 引数が無効です');
            break;
          case -7:
            print('エラー: Not Initialized - 初期化されていません');
            break;
          default:
            print('エラー: 不明なエラーコード ${e.code}');
        }
      }
      
      // エンジンの解放
      if (_engine != null) {
        try {
          await _engine!.release();
        } catch (releaseError) {
          print('Agora: エンジン解放エラー - $releaseError');
        }
        _engine = null;
      }
      
      _isInitialized = false;
      
      // より詳細なエラーメッセージ
      String errorMessage = '音声通話の初期化に失敗しました';
      if (e.toString().contains('permission')) {
        errorMessage = 'マイクの権限が許可されていません。設定から許可してください。';
      } else if (e.toString().contains('network')) {
        errorMessage = 'ネットワーク接続を確認してください。';
      } else if (e.toString().contains('Invalid')) {
        errorMessage = '設定エラーです。アプリを再起動してください。';
      }
      
      onError?.call(errorMessage);
      return false;
    }
  }
  
  // 権限を要求
  Future<void> _checkPermissions() async {
    try {
      print('Agora: 権限状態確認開始');
      
      // マイク権限の現在の状態を確認（要求はしない）
      final micStatus = await Permission.microphone.status;
      print('Agora: マイク権限状態: $micStatus');
      
      if (micStatus != PermissionStatus.granted) {
        throw Exception('マイクの権限が許可されていません。ホーム画面から権限を許可してください。');
      }
      
      // ビデオが有効な場合のみカメラ権限をチェック
      if (_isVideoEnabled) {
        final cameraStatus = await Permission.camera.status;
        print('Agora: カメラ権限状態: $cameraStatus');
        
        if (cameraStatus != PermissionStatus.granted) {
          throw Exception('カメラの権限が許可されていません。設定から権限を許可してください。');
        }
      }
      
      print('Agora: 権限確認完了');
      
    } catch (e) {
      print('Agora: 権限確認エラー - $e');
      rethrow;
    }
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
      _currentChannelName = channelName;
      _currentUid = uid;
      
      String? agoraToken;
      
      // 強制的にテストモード（トークンなし）で接続
      print('Agora: テストモード - トークンなしで接続');
      agoraToken = null;
      
      print('Agora: チャンネル参加試行 - Channel: $channelName, UID: $uid, Token: ${agoraToken == null ? "null" : "設定済み"}');
      
      // Android の場合、参加前に再度音声設定を確認
      if (Platform.isAndroid) {
        print('Agora: Android音声設定再確認...');
        await _engine!.enableAudio();
        await _engine!.enableLocalAudio(true);
        await _engine!.muteLocalAudioStream(false);
        print('Agora: Android音声設定再確認完了');
      }
      
      // チャンネルメディアオプションを設定（SDK 6系必須）
      final mediaOptions = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster, // Broadcasterでないとpublishが無視される
        publishMicrophoneTrack: true, // 自分のマイクを送る
        autoSubscribeAudio: true, // 相手の音声を自動受信
        publishCameraTrack: _isVideoEnabled, // カメラ映像を送信（ビデオ有効時のみ）
        autoSubscribeVideo: _isVideoEnabled, // ビデオ自動購読
        channelProfile: ChannelProfileType.channelProfileCommunication, // 通話プロファイル明示的指定
      );
      
      await _engine!.joinChannel(
        token: agoraToken ?? '', // nullの場合は空文字列
        channelId: channelName,
        uid: uid,
        options: mediaOptions,
      );
      
      print('Agora: チャンネル参加コマンド送信完了 - $channelName (UID: $uid)');
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
    try {
      print('Agora: チャンネル離脱開始 - ${_currentChannelName ?? "不明"}');
      
      if (_engine != null) {
        // トークン更新タイマーを停止
        _tokenRefreshTimer?.cancel();
        _tokenRefreshTimer = null;
        
        // チャンネルから離脱（他のユーザーに通知される）
        await _engine!.leaveChannel();
        _setConnectionState(AgoraConnectionState.disconnected);
        
        print('Agora: チャンネル離脱完了');
      } else {
        print('Agora: エンジンが既に解放されています');
      }
      
      // 通話終了を記録（本番モードの場合）
      if (AgoraConfig.useTokenAuthentication && _currentChannelName != null) {
        final callDuration = getCallDuration();
        await AgoraTokenService.recordCallEnd(
          channelName: _currentChannelName!,
          duration: callDuration,
          callType: _isVideoEnabled ? 'video' : 'voice',
        );
      }
      
      _currentToken = null;
      _currentChannelName = null;
      _currentUid = null;
      
      print('Agora: チャンネルから離脱');
    } catch (e) {
      print('Agora: チャンネル離脱エラー - $e');
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
  
  // ビデオを有効化
  Future<void> enableVideo() async {
    if (_engine != null) {
      await _engine!.enableVideo();
      
      // ビデオ設定
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 30,
          bitrate: 0,
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );
      
      _isVideoEnabled = true;
      print('Agora: ビデオ有効化');
    }
  }
  
  // ビデオを無効化
  Future<void> disableVideo() async {
    if (_engine != null) {
      await _engine!.disableVideo();
      _isVideoEnabled = false;
      print('Agora: ビデオ無効化');
    }
  }
  
  // カメラを切り替え
  Future<void> switchCamera() async {
    if (_engine != null && _isVideoEnabled) {
      await _engine!.switchCamera();
      _isFrontCamera = !_isFrontCamera;
      print('Agora: カメラ切り替え - ${_isFrontCamera ? "前面" : "背面"}');
    }
  }
  
  // ローカルビデオのON/OFF
  Future<void> muteLocalVideo(bool mute) async {
    if (_engine != null) {
      await _engine!.muteLocalVideoStream(mute);
      print('Agora: ローカルビデオ${mute ? "ミュート" : "ミュート解除"}');
    }
  }
  
  // 美顔フィルターを有効化
  Future<void> setBeautyEffect({
    double smoothness = 0.5,
    double brightness = 0.5,
    double redness = 0.5,
  }) async {
    if (_engine != null) {
      await _engine!.setBeautyEffectOptions(
        enabled: true,
        options: BeautyOptions(
          lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: brightness,
          smoothnessLevel: smoothness,
          rednessLevel: redness,
        ),
      );
    }
  }
  
  // ビデオが有効かどうか
  bool get isVideoEnabled => _isVideoEnabled;
  
  // 前面カメラを使用しているか
  bool get isFrontCamera => _isFrontCamera;
  
  // 接続状態を更新
  void _setConnectionState(AgoraConnectionState state) {
    _connectionState = state;
    onConnectionStateChanged?.call(state);
  }
  
  // 現在の接続状態を取得
  AgoraConnectionState get connectionState => _connectionState;
  
  // トークンの自動更新タイマーを開始
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    
    // 50分後にトークンを更新（1時間の有効期限の10分前）
    _tokenRefreshTimer = Timer(const Duration(minutes: 50), () async {
      await _refreshToken();
    });
  }
  
  // トークンを更新
  Future<void> _refreshToken() async {
    if (_currentChannelName == null || _currentToken == null || _currentUid == null) {
      return;
    }
    
    try {
      print('Agora: トークンを更新中...');
      final newToken = await AgoraTokenService.refreshToken(
        channelName: _currentChannelName!,
        oldToken: _currentToken!,
        uid: _currentUid!,
      );
      
      if (newToken != null && _engine != null) {
        await _engine!.renewToken(newToken);
        _currentToken = newToken;
        print('Agora: トークン更新成功');
        
        // 次の更新タイマーを設定
        _startTokenRefreshTimer();
      } else {
        print('Agora: トークン更新に失敗しました');
        onError?.call('認証の更新に失敗しました。通話を再開してください。');
      }
    } catch (e) {
      print('Agora: トークン更新エラー - $e');
      onError?.call('認証エラーが発生しました');
    }
  }
  
  // 通話開始時刻を記録
  DateTime? _callStartTime;
  
  // 通話開始を記録
  void recordCallStart() {
    _callStartTime = DateTime.now();
  }
  
  // 通話時間を取得（秒）
  int getCallDuration() {
    if (_callStartTime == null) return 0;
    return DateTime.now().difference(_callStartTime!).inSeconds;
  }
  
  // リソース解放
  Future<void> dispose() async {
    if (_engine != null) {
      _tokenRefreshTimer?.cancel();
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
      _isInitialized = false;
      _setConnectionState(AgoraConnectionState.disconnected);
      print('Agora: リソース解放完了');
    }
  }
}