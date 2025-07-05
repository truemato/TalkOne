import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ユーザーブロック機能管理サービス
class BlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 指定されたユーザーをブロック
  Future<bool> blockUser(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('ユーザーが認証されていません');
      }

      // 自分をブロックしようとした場合はエラー
      if (currentUserId == targetUserId) {
        throw Exception('自分自身をブロックすることはできません');
      }

      // ブロックリストに追加
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedUserId': targetUserId,
      });

      print('ユーザーブロック完了: $targetUserId');
      return true;
    } catch (e) {
      print('ブロックエラー: $e');
      return false;
    }
  }

  /// 指定されたユーザーのブロックを解除
  Future<bool> unblockUser(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('ユーザーが認証されていません');
      }

      // ブロックリストから削除
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .delete();

      print('ユーザーブロック解除完了: $targetUserId');
      return true;
    } catch (e) {
      print('ブロック解除エラー: $e');
      return false;
    }
  }

  /// 指定されたユーザーがブロックされているかチェック
  Future<bool> isUserBlocked(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .get();

      return doc.exists;
    } catch (e) {
      print('ブロック状態確認エラー: $e');
      return false;
    }
  }

  /// 自分がブロックしているユーザーのリストを取得
  Future<List<String>> getBlockedUserIds() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data()['blockedUserId'] as String)
          .toList();
    } catch (e) {
      print('ブロックリスト取得エラー: $e');
      return [];
    }
  }

  /// 自分をブロックしているユーザーのリストを取得（相互チェック用）
  Future<List<String>> getUsersWhoBlockedMe() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return [];

      // 全ユーザーのブロックリストを検索して、自分がブロックされているかチェック
      final querySnapshot = await _firestore
          .collectionGroup('blockedUsers')
          .where('blockedUserId', isEqualTo: currentUserId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.reference.parent.parent!.id)
          .toList();
    } catch (e) {
      print('被ブロックリスト取得エラー: $e');
      return [];
    }
  }

  /// 2つのユーザー間でブロック関係があるかチェック（相互ブロック確認）
  Future<bool> isBlockRelationshipExists(String userId1, String userId2) async {
    try {
      // userId1がuserId2をブロックしているかチェック
      final doc1 = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('blockedUsers')
          .doc(userId2)
          .get();

      // userId2がuserId1をブロックしているかチェック  
      final doc2 = await _firestore
          .collection('users')
          .doc(userId2)
          .collection('blockedUsers')
          .doc(userId1)
          .get();

      return doc1.exists || doc2.exists;
    } catch (e) {
      print('ブロック関係確認エラー: $e');
      return false;
    }
  }

  /// マッチング時にブロック関係をチェック（マッチングサービス用）
  Future<bool> canUsersMatch(String userId1, String userId2) async {
    // ブロック関係がある場合はマッチング不可
    final hasBlockRelation = await isBlockRelationshipExists(userId1, userId2);
    return !hasBlockRelation;
  }

  /// ブロック済みユーザーのブロック情報を取得
  Future<Map<String, dynamic>?> getBlockInfo(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('ブロック情報取得エラー: $e');
      return null;
    }
  }
}