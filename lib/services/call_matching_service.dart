// lib/services/call_matching_service.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  
  StreamSubscription? _matchingSubscription;
  String? _currentCallId;
  
  // 通話リクエストを作成（通話ボタンを押したとき）
  Future<String> createCallRequest() async {
    // まず古い自分のリクエストをクリーンアップ
    await _cleanupOldRequests();
    
    final callRequestRef = _db.collection('callRequests').doc();
    
    await callRequestRef.set({
      'userId': _userId,
      'status': CallStatus.waiting.name,
      'createdAt': FieldValue.serverTimestamp(),
      'matchedWith': null,
      'channelName': null,
    });
    
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
  Stream<CallMatch?> startMatching(String callRequestId) {
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
        final match = CallMatch(
          callId: callRequestId,
          partnerId: data['matchedWith'],
          channelName: data['channelName'],
          status: status,
        );
        controller.add(match);
      } else if (status == CallStatus.cancelled || status == CallStatus.finished) {
        controller.add(null);
        controller.close();
      }
    });
    
    return controller.stream;
  }
  
  // 待機中の他のユーザーを検索してマッチング
  Future<void> _findAndMatch(String callRequestId) async {
    try {
      print('通話マッチング: 他のユーザーを検索中... (自分: $_userId)');
      
      await _db.runTransaction((transaction) async {
        // 待機中の他のリクエストを検索（自分以外）- インデックス不要の単純なクエリに変更
        final waitingRequests = await _db
            .collection('callRequests')
            .where('status', isEqualTo: CallStatus.waiting.name)
            .limit(10)  // 複数取得して自分を除外
            .get();
        
        print('通話マッチング: 待機中のリクエスト数: ${waitingRequests.docs.length}');
        
        // 自分以外の待機中ユーザーを検索
        final availablePartners = waitingRequests.docs
            .where((doc) => doc['userId'] != _userId)
            .toList();
        
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
          print('通話マッチング: 他に待機中のユーザーが見つかりませんでした');
          
          // テスト用：10秒後にダミーパートナーを作成
          Future.delayed(const Duration(seconds: 10), () async {
            try {
              final stillWaiting = await _db.collection('callRequests').doc(callRequestId).get();
              if (stillWaiting.exists && stillWaiting.data()?['status'] == CallStatus.waiting.name) {
                print('通話マッチング: テスト用ダミーパートナーを作成');
                await _createDummyPartner(callRequestId);
              }
            } catch (e) {
              print('ダミーパートナー作成エラー: $e');
            }
          });
        }
      });
    } catch (e) {
      print('マッチングエラー: $e');
    }
  }
  
  // テスト用ダミーパートナーを作成
  Future<void> _createDummyPartner(String callRequestId) async {
    final channelName = _generateChannelName();
    final dummyPartnerId = 'dummy_${DateTime.now().millisecondsSinceEpoch}';
    
    await _db.collection('callRequests').doc(callRequestId).update({
      'status': CallStatus.matched.name,
      'matchedWith': dummyPartnerId,
      'channelName': channelName,
      'matchedAt': FieldValue.serverTimestamp(),
      'isDummyMatch': true,  // ダミーマッチのフラグ
    });
    
    print('ダミーパートナー作成完了: $dummyPartnerId (チャンネル: $channelName)');
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
  
  CallMatch({
    required this.callId,
    required this.partnerId,
    required this.channelName,
    required this.status,
  });
}