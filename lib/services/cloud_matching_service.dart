// lib/services/cloud_matching_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'evaluation_service.dart';

/// Cloud Runベースのスケーラブルマッチングサービス
/// 
/// アーキテクチャ:
/// 1. Flutter App -> Cloud Run (マッチングリクエスト)
/// 2. Cloud Run -> Cloud Tasks (非同期マッチング処理)
/// 3. Cloud Tasks -> Firestore (マッチング結果保存)
/// 4. Flutter App <- Firestore (リアルタイムリスナー)
class CloudMatchingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;
  final EvaluationService _evaluationService = EvaluationService();
  
  // Cloud RunのエンドポイントURL（環境変数から取得推奨）
  static const String _cloudRunUrl = 'https://matching-service-xxxxx.run.app';
  
  /// マッチングリクエストを送信
  /// Cloud Runに非同期でマッチング処理を依頼
  Future<String> requestMatching({
    bool forceAIMatch = false,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      // ユーザーの現在のレーティングを取得
      final userRating = await _evaluationService.getUserRating();
      
      // マッチングリクエストドキュメントを作成
      final requestRef = _db.collection('matchRequests').doc();
      
      final requestData = {
        'requestId': requestRef.id,
        'userId': _userId,
        'userRating': userRating,
        'forceAIMatch': forceAIMatch,
        'preferences': preferences ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'region': 'asia-northeast1', // リージョン別マッチング
      };
      
      // Firestoreに保存
      await requestRef.set(requestData);
      
      // Cloud Runエンドポイントを呼び出し
      final response = await http.post(
        Uri.parse('$_cloudRunUrl/api/match/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getIdToken()}',
        },
        body: jsonEncode({
          'requestId': requestRef.id,
          'userId': _userId,
          'userRating': userRating,
          'forceAIMatch': forceAIMatch,
          'preferences': preferences,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('マッチングリクエスト失敗: ${response.statusCode}');
      }
      
      return requestRef.id;
    } catch (e) {
      print('マッチングリクエストエラー: $e');
      rethrow;
    }
  }
  
  /// マッチング状態をリアルタイムで監視
  Stream<MatchStatus> watchMatchingStatus(String requestId) {
    return _db
        .collection('matchRequests')
        .doc(requestId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return MatchStatus(
          status: 'error',
          message: 'リクエストが見つかりません',
        );
      }
      
      final data = snapshot.data()!;
      return MatchStatus(
        status: data['status'],
        matchedWith: data['matchedWith'],
        channelName: data['channelName'],
        estimatedWaitTime: data['estimatedWaitTime'],
        queuePosition: data['queuePosition'],
        message: data['message'],
      );
    });
  }
  
  /// マッチングをキャンセル
  Future<void> cancelMatching(String requestId) async {
    try {
      // Cloud Runにキャンセルリクエスト送信
      final response = await http.post(
        Uri.parse('$_cloudRunUrl/api/match/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getIdToken()}',
        },
        body: jsonEncode({
          'requestId': requestId,
          'userId': _userId,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('キャンセル失敗: ${response.statusCode}');
      }
      
      // Firestoreのステータスも更新
      await _db.collection('matchRequests').doc(requestId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('マッチングキャンセルエラー: $e');
      rethrow;
    }
  }
  
  /// Firebase Auth IDトークン取得
  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('未認証');
    return await user.getIdToken();
  }
}

/// マッチング状態
class MatchStatus {
  final String status; // pending, searching, matched, cancelled, error
  final String? matchedWith;
  final String? channelName;
  final int? estimatedWaitTime; // 推定待ち時間（秒）
  final int? queuePosition; // キュー内の位置
  final String? message;
  
  MatchStatus({
    required this.status,
    this.matchedWith,
    this.channelName,
    this.estimatedWaitTime,
    this.queuePosition,
    this.message,
  });
  
  bool get isMatched => status == 'matched';
  bool get isPending => status == 'pending' || status == 'searching';
  bool get isCancelled => status == 'cancelled';
  bool get hasError => status == 'error';
}