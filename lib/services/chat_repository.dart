// lib/services/chat_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRepository {
  final _db = FirebaseFirestore.instance;

  /// 進行中 convo が無ければ新規
  Future<DocumentReference> currentOrNewConv(String uid) async {
    final col = _db.collection('users').doc(uid).collection('conversations');
    final q = await col.where('endedAt', isNull: true).limit(1).get();
    if (q.docs.isNotEmpty) return q.docs.first.reference;
    final ref = col.doc();
    await ref.set({
      'startedAt': FieldValue.serverTimestamp(),
      'userId': uid,
    });
    return ref;
  }

  Future<void> addMessage(
      DocumentReference conv, String from, String text) async {
    await conv.collection('messages').add({
      'sender': from,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isSummary': from == 'system' && text.contains('[以前の会話の要約]'),
    });
    await conv.update({'lastMessage': text});
  }
  
  // 要約情報を保存
  Future<void> saveSummaryInfo(
    DocumentReference conv,
    int summarizedCount,
  ) async {
    await conv.update({
      'hasSummary': true,
      'lastSummaryAt': FieldValue.serverTimestamp(),
      'summarizedMessageCount': FieldValue.increment(summarizedCount),
    });
  }

  Future<void> finishConv(DocumentReference conv) =>
      conv.update({'endedAt': FieldValue.serverTimestamp()});
}