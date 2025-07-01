// Web版用のAgoraスタブファイル
// Web版では音声通話機能を無効化

class RtcEngine {
  // スタブ実装
}

class ChannelMediaOptions {
  // スタブ実装
}

enum ClientRoleType {
  clientRoleBroadcaster,
  clientRoleAudience,
}

class RtcEngineEventHandler {
  // スタブ実装
}

class ConnectionStateType {
  static const disconnected = 'disconnected';
  static const connecting = 'connecting';
  static const connected = 'connected';
  static const reconnecting = 'reconnecting';
  static const failed = 'failed';
}

class ConnectionChangedReasonType {
  static const joinSuccess = 'joinSuccess';
  static const leaveChannel = 'leaveChannel';
  static const interrupted = 'interrupted';
  static const banned = 'banned';
  static const joinFailed = 'joinFailed';
  static const rejected = 'rejected';
  static const lostToken = 'lostToken';
  static const tokenExpired = 'tokenExpired';
  static const invalidToken = 'invalidToken';
  static const clientIpAddressChanged = 'clientIpAddressChanged';
  static const keepAliveTimeout = 'keepAliveTimeout';
}

class RtcConnection {
  // スタブ実装
}

// Agoraエンジン作成用のスタブ関数
Future<RtcEngine> createAgoraRtcEngine() async {
  return RtcEngine();
}