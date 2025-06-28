// lib/services/evaluation_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_service.dart';
import 'call_history_service.dart';

class EvaluationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;
  final UserProfileService _userProfileService = UserProfileService();
  final CallHistoryService _callHistoryService = CallHistoryService();

  // 評価を送信する
  Future<void> submitEvaluation({
    required String callId,
    required String partnerId,
    required int rating, // 1-5
    String? comment,
    bool isDummyMatch = false,
  }) async {
    try {
      // 評価データを保存
      await _db.collection('evaluations').add({
        'callId': callId,
        'evaluatorId': _userId,
        'evaluatedUserId': partnerId,
        'rating': rating,
        'comment': comment ?? '',
        'isDummyMatch': isDummyMatch,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('評価送信完了: $rating stars for $partnerId');
      
      // 双方の通話履歴を更新
      // 1. 自分の履歴：自分が相手を評価
      await _callHistoryService.updateCallRating(callId, rating, true);
      
      // 2. 相手の履歴：相手が自分に評価された
      // CallHistoryServiceの_updatePartnerHistoryは既に処理されるので追加処理不要
      
    } catch (e) {
      print('評価送信エラー: $e');
      rethrow;
    }
  }


  // 評価履歴を取得
  Future<List<Map<String, dynamic>>> getEvaluationHistory() async {
    final evaluations = await _db
        .collection('evaluations')
        .where('evaluatedUserId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return evaluations.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  // ユーザーレーティングを取得（汎用版）
  Future<double> getUserRating([String? userId]) async {
    final targetUserId = userId ?? _userId;
    try {
      final profile = await _userProfileService.getUserProfileById(targetUserId);
      if (profile != null) {
        return profile.rating.toDouble();
      }
      
      // UserProfileがない場合、usersコレクションから直接取得
      final userDoc = await _db.collection('users').doc(targetUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return (userData['rating'] ?? 1000.0).toDouble();
      }
      
      return 1000.0; // デフォルトレーティング
    } catch (e) {
      print('ユーザーレーティング取得エラー: $e');
      return 1000.0;
    }
  }

  // AI練習モードを推奨するかチェック（AI機能無効化のため常にfalseを返す）
  Future<bool> shouldMatchWithAI(double userRating) async {
    // AI機能を無効化するため、常にfalseを返す
    return false;
    
    // 元のロジック（コメントアウト）:
    // レーティングが低い場合やAI練習が必要な場合にtrueを返していた
    // return userRating < 800.0;
  }

}