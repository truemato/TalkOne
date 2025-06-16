// lib/services/call_matching_service.dart
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'evaluation_service.dart';
import '../models/user_model.dart';

enum CallStatus {
  waiting,      // 待機中
  matched,      // マッチング完了
  calling,      // 通話中
  finished,     // 通話終了
  cancelled,    // キャンセル
}

class CallMatchingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;
  final EvaluationService _evaluationService = EvaluationService();
  
  StreamSubscription? _matchingSubscription;
  String? _currentCallId;
  String? currentChannelName;
  
  // 通話リクエストを作成（通話ボタンを押したとき）
  Future<String> createCallRequest({
    bool forceAIMatch = false,
    bool enableAIFilter = false,
    bool privacyMode = false,
  }) async {
    print('=== マッチング開始 ===');
    print('UserID: $_userId');
    print('Device: ${Platform.isAndroid ? "Android" : "iOS"} ${kIsWeb ? "Web" : "Native"}');
    
    // まず古い自分のリクエストをクリーンアップ
    await _cleanupOldRequests();
    
    final callRequestRef = _db.collection('callRequests').doc();
    
    // ユーザーの現在のレーティングを取得
    final userRating = await _evaluationService.getUserRating();
    
    await callRequestRef.set({
      'userId': _userId,
      'status': CallStatus.waiting.name,
      'createdAt': FieldValue.serverTimestamp(),
      'matchedWith': null,
      'channelName': null,
      'userRating': userRating,
      'forceAIMatch': forceAIMatch,
      'enableAIFilter': enableAIFilter,
      'privacyMode': privacyMode,
      'deviceInfo': '${Platform.isAndroid ? "Android" : "iOS"}_${kIsWeb ? "Web" : "Native"}',
    });
    
    print('通話リクエスト作成: ${callRequestRef.id} (Rating: $userRating)');
    _currentCallId = callRequestRef.id;
    return callRequestRef.id;
  }
  
  // 古いリクエストをクリーンアップ
  Future<void> _cleanupOldRequests() async {
    try {
      final oldRequests = await _db
          .collection('callRequests')
          .where('userId', isEqualTo: _userId)
          .get();
      
      for (final doc in oldRequests.docs) {
        await doc.reference.delete();
        print('古いリクエストを削除: ${doc.id}');
      }
    } catch (e) {
      print('古いリクエストクリーンアップエラー: $e');
    }
  }
  
  // マッチング待機を開始
  Future<void> startMatching({
    bool isVideoCall = false,
    required Function(UserModel) onMatchFound,
    required Function() onTimeExpired,
  }) async {
    String callRequestId = await createCallRequest();
    _startMatchingStream(callRequestId, isVideoCall, onMatchFound, onTimeExpired);
  }
  
  // キャンセル処理
  Future<void> cancelMatching() async {
    if (_currentCallId != null) {
      await _db.collection('callRequests').doc(_currentCallId).update({
        'status': CallStatus.cancelled.name,
      });
    }
    dispose();
  }
  
  Stream<CallMatch?> _startMatchingStream(String callRequestId, bool isVideoCall, Function(UserModel) onMatchFound, Function() onTimeExpired) {
    final controller = StreamController<CallMatch?>();
    
    // 他の待機中のリクエストを検索してマッチング
    _findAndMatch(callRequestId);
    
    // リアルタイムでマッチング状況を監視
    _matchingSubscription = _db
        .collection('callRequests')
        .doc(callRequestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        controller.add(null);
        return;
      }
      
      final data = snapshot.data()!;
      final status = CallStatus.values.byName(data['status']);
      
      if (status == CallStatus.matched) {
        currentChannelName = data['channelName'];
        // パートナー情報を取得
        _db.collection('users').doc(data['matchedWith']).get().then((partnerDoc) {
          if (partnerDoc.exists) {
            final partner = UserModel.fromFirestore(partnerDoc);
            onMatchFound(partner);
          }
        });
      } else if (status == CallStatus.cancelled || status == CallStatus.finished) {
        controller.add(null);
        controller.close();
      }
    });
    
    // タイムアウト処理
    Timer(const Duration(seconds: 30), () {
      if (_currentCallId != null) {
        onTimeExpired();
      }
    });
    
    return controller.stream;
  }
  
  // 待機中の他のユーザーを検索してマッチング
  Future<void> _findAndMatch(String callRequestId) async {
    try {
      print('通話マッチング: 他のユーザーを検索中... (自分: $_userId)');
      
      await _db.runTransaction((transaction) async {
        // 自分のリクエスト情報を取得
        final myRequestDoc = await transaction.get(_db.collection('callRequests').doc(callRequestId));
        if (!myRequestDoc.exists) return;
        
        final myData = myRequestDoc.data()!;
        final myRating = (myData['userRating'] ?? 1000.0).toDouble();
        final forceAIMatch = myData['forceAIMatch'] ?? false;
        
        // AI強制マッチングまたはAI推奨条件の場合
        if (forceAIMatch || await _evaluationService.shouldMatchWithAI(myRating)) {
          print('通話マッチング: AI練習モードを開始');
          await _createAIPartner(callRequestId, transaction);
          return;
        }
        
        // レーティングベースマッチング
        final availablePartners = await _findRatingBasedPartners(myRating);
        
        print('通話マッチング: 利用可能なパートナー数: ${availablePartners.length}');
        
        if (availablePartners.isNotEmpty) {
          final partnerDoc = availablePartners.first;
          final partnerId = partnerDoc['userId'];
          
          // チャンネル名を生成
          final channelName = _generateChannelName();
          
          // 両方のリクエストをマッチ済みに更新
          final myRequestRef = _db.collection('callRequests').doc(callRequestId);
          final partnerRequestRef = _db.collection('callRequests').doc(partnerDoc.id);
          
          transaction.update(myRequestRef, {
            'status': CallStatus.matched.name,
            'matchedWith': partnerId,
            'channelName': channelName,
            'matchedAt': FieldValue.serverTimestamp(),
          });
          
          transaction.update(partnerRequestRef, {
            'status': CallStatus.matched.name,
            'matchedWith': _userId,
            'channelName': channelName,
            'matchedAt': FieldValue.serverTimestamp(),
          });
          
          print('マッチング成功: $_userId <-> $partnerId (チャンネル: $channelName)');
        } else {
          print('通話マッチング: 適切なパートナーが見つかりませんでした');
          
          // 段階的マッチング範囲拡大
          _scheduleExpandedMatching(callRequestId, myRating);
        }
      });
    } catch (e) {
      print('マッチングエラー: $e');
    }
  }

  // レーティングベースのパートナー検索
  Future<List<QueryDocumentSnapshot>> _findRatingBasedPartners(double myRating) async {
    try {
      // インデックスが不要なシンプルなクエリに変更
      final waitingRequests = await _db
          .collection('callRequests')
          .where('status', isEqualTo: CallStatus.waiting.name)
          .limit(50)  // 多めに取得してクライアント側でフィルタリング
          .get();
      
      // クライアント側でレーティング範囲フィルタリング（999基準に調整）
      var ratingRange = 50.0;  // ±50ポイント
      final maxRange = 150.0;  // 最大±150ポイント
      
      while (ratingRange <= maxRange) {
        final minRating = myRating - ratingRange;
        final maxRating = myRating + ratingRange;
        
        // 自分以外で、レーティング範囲内、AI強制マッチング以外のユーザーを検索
        final availablePartners = waitingRequests.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final userRating = (data['userRating'] ?? 1000.0).toDouble();
              return doc['userId'] != _userId && 
                     userRating >= minRating &&
                     userRating <= maxRating &&
                     !(data['forceAIMatch'] ?? false);
            })
            .toList();
        
        if (availablePartners.isNotEmpty) {
          // レーティング差で並び替え
          availablePartners.sort((a, b) {
            final aRating = (a['userRating'] ?? 1000.0).toDouble();
            final bRating = (b['userRating'] ?? 1000.0).toDouble();
            final aDiff = (aRating - myRating).abs();
            final bDiff = (bRating - myRating).abs();
            return aDiff.compareTo(bDiff);
          });
          
          return availablePartners;
        }
        
        // 範囲を拡大して再検索
        ratingRange += 10.0;
      }
    } catch (e) {
      print('レーティングベースパートナー検索エラー: $e');
    }
    
    return [];
  }

  // 段階的マッチング範囲拡大
  void _scheduleExpandedMatching(String callRequestId, double myRating) {
    // 10秒後：範囲を大幅拡大して再検索
    Future.delayed(const Duration(seconds: 10), () async {
      try {
        final stillWaiting = await _db.collection('callRequests').doc(callRequestId).get();
        if (stillWaiting.exists && stillWaiting.data()?['status'] == CallStatus.waiting.name) {
          print('通話マッチング: 拡大範囲で再検索');
          
          // 全レーティング範囲で検索
          final waitingRequests = await _db
              .collection('callRequests')
              .where('status', isEqualTo: CallStatus.waiting.name)
              .limit(20)
              .get();
          
          final availablePartners = waitingRequests.docs
              .where((doc) => doc['userId'] != _userId)
              .toList();
          
          if (availablePartners.isNotEmpty) {
            final partnerDoc = availablePartners.first;
            final partnerId = partnerDoc['userId'];
            final channelName = _generateChannelName();
            
            await _db.runTransaction((transaction) async {
              transaction.update(_db.collection('callRequests').doc(callRequestId), {
                'status': CallStatus.matched.name,
                'matchedWith': partnerId,
                'channelName': channelName,
                'matchedAt': FieldValue.serverTimestamp(),
              });
              
              transaction.update(_db.collection('callRequests').doc(partnerDoc.id), {
                'status': CallStatus.matched.name,
                'matchedWith': _userId,
                'channelName': channelName,
                'matchedAt': FieldValue.serverTimestamp(),
              });
            });
            
            print('拡大範囲マッチング成功: $_userId <-> $partnerId');
          } else {
            // 20秒後：AI練習パートナーを提案
            Future.delayed(const Duration(seconds: 10), () async {
              final stillWaiting2 = await _db.collection('callRequests').doc(callRequestId).get();
              if (stillWaiting2.exists && stillWaiting2.data()?['status'] == CallStatus.waiting.name) {
                print('通話マッチング: AI練習パートナーを作成');
                await _createAIPartner(callRequestId, null);
              }
            });
          }
        }
      } catch (e) {
        print('拡大マッチングエラー: $e');
      }
    });
  }
  
  // AI練習パートナーを作成
  Future<void> _createAIPartner(String callRequestId, Transaction? transaction) async {
    final channelName = _generateChannelName();
    final aiPartnerId = 'ai_practice_${DateTime.now().millisecondsSinceEpoch}';
    
    final updateData = {
      'status': CallStatus.matched.name,
      'matchedWith': aiPartnerId,
      'channelName': channelName,
      'matchedAt': FieldValue.serverTimestamp(),
      'isDummyMatch': true,  // AI練習のフラグ
      'isAIMatch': true,     // AI練習専用フラグ
    };

    if (transaction != null) {
      transaction.update(_db.collection('callRequests').doc(callRequestId), updateData);
    } else {
      await _db.collection('callRequests').doc(callRequestId).update(updateData);
    }
    
    print('AI練習パートナー作成完了: $aiPartnerId (チャンネル: $channelName)');
  }

  // テスト用ダミーパートナーを作成（後方互換性のため残す）
  Future<void> _createDummyPartner(String callRequestId) async {
    await _createAIPartner(callRequestId, null);
  }
  
  // チャンネル名を生成
  String _generateChannelName() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNumber = random.nextInt(9999);
    return 'talkone_${timestamp}_$randomNumber';
  }
  
  // 通話リクエストをキャンセル
  Future<void> cancelCallRequest(String callRequestId) async {
    await _db.collection('callRequests').doc(callRequestId).update({
      'status': CallStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    
    _matchingSubscription?.cancel();
    _currentCallId = null;
  }
  
  // 通話終了をマーク
  Future<void> finishCall(String callRequestId) async {
    await _db.collection('callRequests').doc(callRequestId).update({
      'status': CallStatus.finished.name,
      'finishedAt': FieldValue.serverTimestamp(),
    });
    
    _matchingSubscription?.cancel();
    _currentCallId = null;
  }
  
  // 待機中のユーザー数をリアルタイムで取得
  Stream<int> getWaitingUsersCount() {
    return _db
        .collection('callRequests')
        .where('status', isEqualTo: CallStatus.waiting.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  // リソース解放
  void dispose() {
    _matchingSubscription?.cancel();
  }
}

// マッチング結果を表すクラス
class CallMatch {
  final String callId;
  final String partnerId;
  final String channelName;
  final CallStatus status;
  final bool enableAIFilter;
  final bool privacyMode;
  
  CallMatch({
    required this.callId,
    required this.partnerId,
    required this.channelName,
    required this.status,
    this.enableAIFilter = false,
    this.privacyMode = false,
  });
}