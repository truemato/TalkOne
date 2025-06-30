import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// AI会話履歴管理サービス
/// 
/// AIとの会話回数、完了セッション、ユーザー特徴を管理します。
class AIConversationHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// AIとの会話回数を取得
  Future<int> getAIConversationCount(int personalityId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('aiConversationHistory')
          .doc(user.uid)
          .collection('personalities')
          .doc(personalityId.toString())
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return data['conversationCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('AI会話回数取得エラー: $e');
      return 0;
    }
  }

  /// AI会話完了を記録（3分完了時のみ）
  Future<void> recordCompletedAIConversation(
    int personalityId,
    List<String> userMessages,
    List<String> aiResponses,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = _firestore
          .collection('aiConversationHistory')
          .doc(user.uid)
          .collection('personalities')
          .doc(personalityId.toString());

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final data = snapshot.exists ? snapshot.data() as Map<String, dynamic> : {};
        
        final currentCount = data['conversationCount'] ?? 0;
        final currentFeatures = List<String>.from(data['userFeatures'] ?? []);

        // ユーザー特徴を抽出・更新
        final newFeatures = await _extractUserFeatures(userMessages, aiResponses);
        final updatedFeatures = _updateUserFeatures(currentFeatures, newFeatures);

        transaction.set(docRef, {
          'conversationCount': currentCount + 1,
          'lastConversationDate': FieldValue.serverTimestamp(),
          'userFeatures': updatedFeatures,
          'personalityId': personalityId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      print('AI会話完了記録: 性格ID=$personalityId, 新回数=${await getAIConversationCount(personalityId)}');
    } catch (e) {
      print('AI会話記録エラー: $e');
    }
  }

  /// ユーザー特徴を取得
  Future<List<String>> getUserFeatures(int personalityId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('aiConversationHistory')
          .doc(user.uid)
          .collection('personalities')
          .doc(personalityId.toString())
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return List<String>.from(data['userFeatures'] ?? []);
      }
      return [];
    } catch (e) {
      print('ユーザー特徴取得エラー: $e');
      return [];
    }
  }

  /// ユーザー特徴を抽出（簡易版AI解析）
  Future<List<String>> _extractUserFeatures(
    List<String> userMessages,
    List<String> aiResponses,
  ) async {
    final features = <String>[];
    final combinedText = userMessages.join(' ');

    // キーワードベース特徴抽出
    final interestKeywords = {
      '映画': 'ユーザーは映画に興味がある。',
      '音楽': 'ユーザーは音楽に興味がある。',
      'ゲーム': 'ユーザーはゲームに興味がある。',
      '読書': 'ユーザーは読書に興味がある。',
      '料理': 'ユーザーは料理に興味がある。',
      'スポーツ': 'ユーザーはスポーツに興味がある。',
      '旅行': 'ユーザーは旅行に興味がある。',
      'アニメ': 'ユーザーはアニメに興味がある。',
      '技術': 'ユーザーは技術に興味がある。',
      'プログラミング': 'ユーザーはプログラミングに興味がある。',
    };

    final skillKeywords = {
      '得意': 'ユーザーは{}が得意。',
      '上手': 'ユーザーは{}が上手。',
      'できる': 'ユーザーは{}ができる。',
    };

    final topicKeywords = {
      '仕事': 'ユーザーは仕事の話題を出した。',
      '学校': 'ユーザーは学校の話題を出した。',
      '家族': 'ユーザーは家族の話題を出した。',
      '友達': 'ユーザーは友達の話題を出した。',
      '恋愛': 'ユーザーは恋愛の話題を出した。',
      '趣味': 'ユーザーは趣味の話題を出した。',
    };

    // 興味キーワード検出
    for (final entry in interestKeywords.entries) {
      if (combinedText.contains(entry.key)) {
        features.add(entry.value);
      }
    }

    // 話題キーワード検出
    for (final entry in topicKeywords.entries) {
      if (combinedText.contains(entry.key)) {
        features.add(entry.value);
      }
    }

    // スキルキーワード検出（より複雑な処理）
    for (final message in userMessages) {
      for (final skillEntry in skillKeywords.entries) {
        if (message.contains(skillEntry.key)) {
          // 「〜が得意」のような文脈を抽出
          final words = message.split(' ');
          for (int i = 0; i < words.length - 1; i++) {
            if (words[i + 1].contains(skillEntry.key)) {
              features.add(skillEntry.value.replaceAll('{}', words[i]));
              break;
            }
          }
        }
      }
    }

    return features.take(5).toList(); // 1回の会話で最大5個まで
  }

  /// ユーザー特徴リストを更新（最大10個、新しいものを優先）
  List<String> _updateUserFeatures(List<String> current, List<String> newFeatures) {
    final updated = List<String>.from(current);
    
    for (final feature in newFeatures) {
      // 重複チェック
      if (!updated.contains(feature)) {
        updated.insert(0, feature); // 新しいものを先頭に追加
      }
    }

    // 最大10個まで保持
    if (updated.length > 10) {
      return updated.take(10).toList();
    }
    
    return updated;
  }

  /// デバッグ用：特定ユーザーの全AI会話履歴を取得
  Future<Map<String, dynamic>> getDebugInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      final snapshot = await _firestore
          .collection('aiConversationHistory')
          .doc(user.uid)
          .collection('personalities')
          .get();

      final info = <String, dynamic>{};
      for (final doc in snapshot.docs) {
        info[doc.id] = doc.data();
      }
      return info;
    } catch (e) {
      print('デバッグ情報取得エラー: $e');
      return {};
    }
  }
}