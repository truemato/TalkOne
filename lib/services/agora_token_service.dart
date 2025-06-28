// lib/services/agora_token_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class AgoraTokenService {
  // Cloud RunのエンドポイントURL（環境変数から取得するべき）
  static const String _baseUrl = 'https://agora-token-service-xxxxx.run.app';
  
  /// Agoraトークンを取得
  static Future<String?> getToken({
    required String channelName,
    int uid = 0,
    String callType = 'voice',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('ユーザーが認証されていません');
        return null;
      }
      
      final response = await http.post(
        Uri.parse('$_baseUrl/agora/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({
          'channel_name': channelName,
          'uid': uid,
          'user_id': user.uid,
          'call_type': callType,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('Agoraトークン取得成功');
          return data['token'];
        }
      }
      
      print('Agoraトークン取得失敗: ${response.body}');
      return null;
    } catch (e) {
      print('Agoraトークン取得エラー: $e');
      return null;
    }
  }
  
  /// トークンを更新
  static Future<String?> refreshToken({
    required String channelName,
    required String oldToken,
    int uid = 0,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/agora/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({
          'channel_name': channelName,
          'uid': uid,
          'user_id': user.uid,
          'old_token': oldToken,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['token'];
        }
      }
      
      return null;
    } catch (e) {
      print('トークン更新エラー: $e');
      return null;
    }
  }
  
  /// 通話終了を記録
  static Future<void> recordCallEnd({
    required String channelName,
    required int duration,
    String callType = 'voice',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await http.post(
        Uri.parse('$_baseUrl/agora/end_call'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await user.getIdToken()}',
        },
        body: jsonEncode({
          'channel_name': channelName,
          'user_id': user.uid,
          'duration': duration,
          'call_type': callType,
        }),
      );
      
      print('通話終了記録完了: $duration秒');
    } catch (e) {
      print('通話終了記録エラー: $e');
    }
  }
}