import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallHistory {
  final String callId;
  final String partnerId;
  final String partnerNickname;
  final String partnerIconPath;
  final DateTime callDateTime;
  final int callDuration; // 秒数
  final bool isAiCall;
  final int? myRatingToPartner; // 相手への評価
  final int? partnerRatingToMe; // 相手からの評価

  CallHistory({
    required this.callId,
    required this.partnerId,
    required this.partnerNickname,
    required this.partnerIconPath,
    required this.callDateTime,
    required this.callDuration,
    required this.isAiCall,
    this.myRatingToPartner,
    this.partnerRatingToMe,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'callId': callId,
      'partnerId': partnerId,
      'partnerNickname': partnerNickname,
      'partnerIconPath': partnerIconPath,
      'callDateTime': Timestamp.fromDate(callDateTime),
      'callDuration': callDuration,
      'isAiCall': isAiCall,
      'myRatingToPartner': myRatingToPartner,
      'partnerRatingToMe': partnerRatingToMe,
    };
  }

  factory CallHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallHistory(
      callId: data['callId'] ?? '',
      partnerId: data['partnerId'] ?? '',
      partnerNickname: data['partnerNickname'] ?? 'Unknown',
      partnerIconPath: data['partnerIconPath'] ?? 'aseets/icons/Woman 1.svg',
      callDateTime: (data['callDateTime'] as Timestamp).toDate(),
      callDuration: data['callDuration'] ?? 0,
      isAiCall: data['isAiCall'] ?? false,
      myRatingToPartner: data['myRatingToPartner'],
      partnerRatingToMe: data['partnerRatingToMe'],
    );
  }
}

class CallHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 通話履歴を保存
  Future<void> saveCallHistory(CallHistory history) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('callHistories')
          .doc(user.uid)
          .collection('calls')
          .add(history.toFirestore());
    } catch (e) {
      print('Error saving call history: $e');
    }
  }

  // 通話履歴を取得（最新順）
  Future<List<CallHistory>> getCallHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('callHistories')
          .doc(user.uid)
          .collection('calls')
          .orderBy('callDateTime', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => CallHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting call history: $e');
      return [];
    }
  }

  // 通話履歴をリアルタイムで取得
  Stream<List<CallHistory>> getCallHistoryStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('callHistories')
        .doc(user.uid)
        .collection('calls')
        .orderBy('callDateTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CallHistory.fromFirestore(doc))
          .toList();
    });
  }

  // 評価を後から更新（双方向対応）
  Future<void> updateCallRating(String callId, int rating, bool isMyRating) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 自分の履歴を更新
      final mySnapshot = await _firestore
          .collection('callHistories')
          .doc(user.uid)
          .collection('calls')
          .where('callId', isEqualTo: callId)
          .get();

      for (var doc in mySnapshot.docs) {
        await doc.reference.update({
          isMyRating ? 'myRatingToPartner' : 'partnerRatingToMe': rating,
        });
      }

      // 相手の履歴も更新（評価の逆側を更新）
      if (isMyRating) {
        // 自分が相手を評価した場合、相手の履歴に「相手からの評価」として記録
        await _updatePartnerHistory(callId, rating, false);
      } else {
        // 相手が自分を評価した場合、相手の履歴に「自分の評価」として記録
        await _updatePartnerHistory(callId, rating, true);
      }
    } catch (e) {
      print('Error updating call rating: $e');
    }
  }

  // 相手の履歴を更新（双方向同期）
  Future<void> _updatePartnerHistory(String callId, int rating, bool isPartnerMyRating) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // まず自分の履歴から相手のIDを取得
      final mySnapshot = await _firestore
          .collection('callHistories')
          .doc(user.uid)
          .collection('calls')
          .where('callId', isEqualTo: callId)
          .get();
      
      if (mySnapshot.docs.isEmpty) return;
      
      final myCallData = mySnapshot.docs.first.data();
      final partnerId = myCallData['partnerId'];
      
      if (partnerId == null) return;
      
      // 相手の履歴を直接更新
      final partnerSnapshot = await _firestore
          .collection('callHistories')
          .doc(partnerId)
          .collection('calls')
          .where('callId', isEqualTo: callId)
          .get();
      
      for (var doc in partnerSnapshot.docs) {
        await doc.reference.update({
          isPartnerMyRating ? 'myRatingToPartner' : 'partnerRatingToMe': rating,
        });
      }
    } catch (e) {
      print('Error updating partner history: $e');
    }
  }

  // 評価データの同期（evaluationコレクションから履歴を更新）
  Future<void> syncRatingsFromEvaluations() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // 自分が評価者の評価データを取得
      final myEvaluationsSnapshot = await _firestore
          .collection('evaluations')
          .where('evaluatorId', isEqualTo: user.uid)
          .get();

      // 自分が評価された評価データを取得
      final receivedEvaluationsSnapshot = await _firestore
          .collection('evaluations')
          .where('evaluatedUserId', isEqualTo: user.uid)
          .get();

      // 自分の評価を履歴に反映
      for (var evalDoc in myEvaluationsSnapshot.docs) {
        final data = evalDoc.data();
        await updateCallRating(
          data['callId'],
          data['rating'],
          true, // 自分の評価
        );
      }

      // 受けた評価を履歴に反映
      for (var evalDoc in receivedEvaluationsSnapshot.docs) {
        final data = evalDoc.data();
        await updateCallRating(
          data['callId'],
          data['rating'],
          false, // 相手からの評価
        );
      }
    } catch (e) {
      print('Error syncing ratings: $e');
    }
  }
}