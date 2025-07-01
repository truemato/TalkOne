// Web版でのAgora音声通話スタブ実装
// WebではAgora音声通話機能は利用できません

// 必要なスタブクラス
class RtcEngine {
  Future<void> initialize(RtcEngineContext context) async {}
  Future<void> release() async {}
  Future<void> enableAudio() async {}
  Future<void> disableAudio() async {}
  Future<void> enableLocalAudio(bool enabled) async {}
  Future<void> enableVideo() async {}
  Future<void> disableVideo() async {}
  Future<void> enableLocalVideo(bool enabled) async {}
  Future<void> muteLocalAudioStream(bool mute) async {}
  Future<void> muteLocalVideoStream(bool mute) async {}
  Future<void> setDefaultAudioRouteToSpeakerphone(bool speakerOn) async {}
  Future<void> switchCamera() async {}
  Future<void> enableAudioVolumeIndication({required int interval, required int smooth, required bool reportVad}) async {}
  Future<void> setBeautyEffectOptions({required bool enabled, required BeautyOptions options}) async {}
  Future<void> renewToken(String newToken) async {}
  Future<void> setChannelProfile(ChannelProfileType profile) async {}
  Future<void> setClientRole({required ClientRoleType role}) async {}
  Future<void> setAudioProfile({required AudioProfileType profile, required AudioScenarioType scenario}) async {}
  Future<void> setVideoEncoderConfiguration(VideoEncoderConfiguration config) async {}
  Future<void> joinChannel({
    required String token,
    required String channelId, 
    required int uid,
    required ChannelMediaOptions options,
  }) async {}
  Future<void> leaveChannel() async {}
  void registerEventHandler(RtcEngineEventHandler eventHandler) {}
  void unregisterEventHandler() {}
}

class RtcEngineContext {
  String? appId;
  ChannelProfileType? channelProfile;
  AudioScenarioType? audioScenario;
  RtcEngineContext({this.appId, this.channelProfile, this.audioScenario});
}

class ChannelMediaOptions {
  final ClientRoleType? clientRoleType;
  final bool? publishMicrophoneTrack;
  final bool? publishCameraTrack;
  final bool? autoSubscribeAudio;
  final bool? autoSubscribeVideo;
  final ChannelProfileType? channelProfile;
  const ChannelMediaOptions({
    this.clientRoleType,
    this.publishMicrophoneTrack,
    this.publishCameraTrack,
    this.autoSubscribeAudio,
    this.autoSubscribeVideo,
    this.channelProfile,
  });
}

enum ClientRoleType {
  clientRoleBroadcaster,
  clientRoleAudience,
}

class RtcEngineEventHandler {
  Function(RtcConnection connection, int elapsed)? onJoinChannelSuccess;
  Function(RtcConnection connection, int uid, int elapsed)? onUserJoined;
  Function(RtcConnection connection, int uid, UserOfflineReasonType reason)? onUserOffline;
  Function(RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason)? onConnectionStateChanged;
  Function(RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume)? onAudioVolumeIndication;
  Function(ErrorCodeType err, String msg)? onError;
  Function(RtcConnection connection, RemoteVideoStats stats)? onRemoteVideoStats;
  
  RtcEngineEventHandler({
    this.onJoinChannelSuccess,
    this.onUserJoined,
    this.onUserOffline,
    this.onConnectionStateChanged,
    this.onAudioVolumeIndication,
    this.onError,
    this.onRemoteVideoStats,
  });
}

class RtcConnection {
  String? channelId;
  RtcConnection({this.channelId});
}

enum ChannelProfileType {
  channelProfileCommunication,
  channelProfileLiveBroadcasting,
  channelProfileGame,
  channelProfileCloudGaming,
}

enum AudioProfileType {
  audioProfileDefault,
  audioProfileSpeechStandard,
  audioProfileMusicStandard,
  audioProfileMusicStandardStereo,
  audioProfileMusicHighQuality,
  audioProfileMusicHighQualityStereo,
}

enum AudioScenarioType {
  audioScenarioDefault,
  audioScenarioGameStreaming,
  audioScenarioChatRoom,
  audioScenarioChorus,
  audioScenarioMeeting,
}

class VideoEncoderConfiguration {
  final VideoDimensions? dimensions;
  final int? frameRate;
  final int? bitrate;
  final OrientationMode? orientationMode;
  
  const VideoEncoderConfiguration({
    this.dimensions,
    this.frameRate,
    this.bitrate,
    this.orientationMode,
  });
}

class VideoDimensions {
  final int width;
  final int height;
  const VideoDimensions({required this.width, required this.height});
}

enum OrientationMode {
  orientationModeAdaptive,
  orientationModeFixedLandscape,
  orientationModeFixedPortrait,
}

enum ConnectionStateType {
  connectionStateDisconnected,
  connectionStateConnecting,
  connectionStateConnected,
  connectionStateReconnecting,
  connectionStateFailed,
}

enum ConnectionChangedReasonType {
  connectionChangedJoinSuccess,
  connectionChangedLeaveChannel,
  connectionChangedInterrupted,
  connectionChangedBannedByServer,
  connectionChangedJoinFailed,
  connectionChangedRejoinSuccess,
  connectionChangedLostToken,
  connectionChangedTokenExpired,
  connectionChangedInvalidToken,
  connectionChangedClientIpAddressChanged,
  connectionChangedKeepAliveTimeout,
}

enum UserOfflineReasonType {
  userOfflineQuit,
  userOfflineDropped,
  userOfflineBecomeAudience,
}

class AudioVolumeInfo {
  int? volume;
  AudioVolumeInfo({this.volume});
}


enum ErrorCodeType {
  errOk,
  errFailed,
  errInvalidArgument,
  errNotReady,
  errNotSupported,
  errRefused,
  errBufferTooSmall,
  errNotInitialized,
  errInvalidState,
  errNoPermission,
  errTimedOut,
  errCanceled,
  errTooOften,
  errBindSocket,
  errNetDown,
  errNetNobufs,
  errJoinChannelRejected,
  errLeaveChannelRejected,
  errAlreadyInUse,
  errAbort,
  errInitNetEngine,
  errResourceLimited,
  errInvalidAppId,
  errInvalidChannelName,
  errNoServerResources,
  errTokenExpired,
  errInvalidToken,
  errConnectionInterrupted,
  errConnectionLost,
  errNotInChannel,
  errSizeTooLarge,
  errBitrateLimit,
  errTooManyDataStreams,
  errStreamMessageTimeout,
  errSetClientRoleNotAuthorized,
  errDecryptionFailed,
  errInvalidUserId,
  errClientIsNotBroadcaster,
}

class BeautyOptions {
  final LighteningContrastLevel? lighteningContrastLevel;
  final double? lighteningLevel;
  final double? smoothnessLevel;
  final double? rednessLevel;
  final double? sharpnessLevel;
  
  const BeautyOptions({
    this.lighteningContrastLevel,
    this.lighteningLevel,
    this.smoothnessLevel,
    this.rednessLevel,
    this.sharpnessLevel,
  });
}

enum LighteningContrastLevel {
  lighteningContrastLow,
  lighteningContrastNormal,
  lighteningContrastHigh,
}

class RemoteVideoStats {}

class AgoraRtcException implements Exception {
  final ErrorCodeType code;
  final String message;
  AgoraRtcException(this.code, this.message);
}

// Agoraエンジン作成用のスタブ関数
RtcEngine createAgoraRtcEngine() {
  return RtcEngine();
}

enum AgoraConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class AgoraCallService {
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isVideoEnabled = false;
  bool _isFrontCamera = true;
  AgoraConnectionState _connectionState = AgoraConnectionState.disconnected;
  
  // コールバック関数
  Function(String uid)? onUserJoined;
  Function(String uid)? onUserLeft;
  Function(AgoraConnectionState)? onConnectionStateChanged;
  Function(String error)? onError;
  Function(int volume)? onAudioVolumeIndication;
  Function(String uid, int width, int height)? onRemoteVideoStats;
  
  // スタブエンジン
  Object? get engine => null;
  
  AgoraConnectionState get connectionState => _connectionState;
  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isFrontCamera => _isFrontCamera;
  
  Future<bool> testConnection() async {
    print('Web版: Agora接続テストはサポートされていません');
    return false;
  }

  Future<void> initializeEngine() async {
    print('Web版: Agora音声通話はサポートされていません');
    _isInitialized = true;
  }

  Future<void> joinChannel(String channelName, String? token, {int? uid}) async {
    print('Web版: チャンネル参加はサポートされていません');
    _connectionState = AgoraConnectionState.connected;
    onConnectionStateChanged?.call(_connectionState);
  }

  Future<void> leaveChannel() async {
    print('Web版: チャンネル退出はサポートされていません');
    _connectionState = AgoraConnectionState.disconnected;
    onConnectionStateChanged?.call(_connectionState);
  }

  Future<void> muteLocalAudioStream(bool mute) async {
    print('Web版: 音声ミュートはサポートされていません');
    _isMuted = mute;
  }

  Future<void> enableLocalVideo(bool enabled) async {
    print('Web版: ビデオ有効化はサポートされていません');
    _isVideoEnabled = enabled;
  }

  Future<void> switchCamera() async {
    print('Web版: カメラ切り替えはサポートされていません');
    _isFrontCamera = !_isFrontCamera;
  }

  Future<void> setDefaultAudioRouteToSpeakerphone(bool speakerOn) async {
    print('Web版: スピーカー設定はサポートされていません');
  }

  Future<void> enableAudioVolumeIndication(int interval, int smooth, bool reportVad) async {
    print('Web版: 音量インジケーターはサポートされていません');
  }

  Future<void> setBeautyEffectOptions(bool enabled, Map<String, dynamic> options) async {
    print('Web版: 美肌効果はサポートされていません');
  }

  Future<void> renewToken(String newToken) async {
    print('Web版: トークン更新はサポートされていません');
  }

  Future<void> dispose() async {
    print('Web版: Agoraエンジン終了処理');
    _isInitialized = false;
    _connectionState = AgoraConnectionState.disconnected;
  }
}