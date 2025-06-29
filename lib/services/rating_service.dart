import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_service.dart';

class RatingData {
  final int currentRating;
  final int consecutiveUp;
  final int consecutiveDown;
  final DateTime lastUpdated;

  RatingData({
    required this.currentRating,
    required this.consecutiveUp,
    required this.consecutiveDown,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'currentRating': currentRating,
      'consecutiveUp': consecutiveUp,
      'consecutiveDown': consecutiveDown,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  factory RatingData.fromMap(Map<String, dynamic> map) {
    return RatingData(
      currentRating: map['currentRating'] ?? 1000,
      consecutiveUp: map['consecutiveUp'] ?? 0,
      consecutiveDown: map['consecutiveDown'] ?? 0,
      lastUpdated: map['lastUpdated'] != null 
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  RatingData copyWith({
    int? currentRating,
    int? consecutiveUp,
    int? consecutiveDown,
    DateTime? lastUpdated,
  }) {
    return RatingData(
      currentRating: currentRating ?? this.currentRating,
      consecutiveUp: consecutiveUp ?? this.consecutiveUp,
      consecutiveDown: consecutiveDown ?? this.consecutiveDown,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class RatingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserProfileService _userProfileService = UserProfileService();
  
  String? get _userId => _auth.currentUser?.uid;
  
  // デフォルトレーティング値
  static const int defaultRating = 1000;
  
  // ネガティブロジック（星1-2）の下降幅
  static const List<int> negativeDropAmounts = [3, 9, 15, 21, 27, 33, 39, 45, 51, 57];
  
  // ポジティブロジック（星3-5）の上昇基数
  static const List<int> positiveMultipliers = [1, 2, 4, 8, 16];

  // 現在のレーティングデータを取得
  Future<RatingData> getRatingData([String? userId]) async {
    final targetUserId = userId ?? _userId;
    if (targetUserId == null) {
      return RatingData(
        currentRating: defaultRating,
        consecutiveUp: 0,
        consecutiveDown: 0,
        lastUpdated: DateTime.now(),
      );
    }
    
    try {
      final doc = await _db.collection('userRatings').doc(targetUserId).get();
      if (doc.exists) {
        return RatingData.fromMap(doc.data()!);
      } else {
        // 初回の場合、デフォルト値を保存
        final defaultData = RatingData(
          currentRating: defaultRating,
          consecutiveUp: 0,
          consecutiveDown: 0,
          lastUpdated: DateTime.now(),
        );
        await _saveRatingData(defaultData, targetUserId);
        return defaultData;
      }
    } catch (e) {
      print('レーティングデータ取得エラー: $e');
      return RatingData(
        currentRating: defaultRating,
        consecutiveUp: 0,
        consecutiveDown: 0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  // レーティングを更新（星の評価に基づく、streakCountベース）
  Future<RatingData> updateRating(int stars, [String? userId]) async {
    final targetUserId = userId ?? _userId;
    if (targetUserId == null) {
      throw Exception('ユーザーIDが取得できません');
    }
    
    // 現在のレーティングデータとストリークカウントを取得
    final currentData = await getRatingData(targetUserId);
    final currentProfile = await _userProfileService.getUserProfileById(targetUserId);
    final currentStreakCount = currentProfile?.streakCount ?? 0;
    
    // 新しいレーティングを計算（streakCountベース）
    final result = calculateNewRatingWithStreakCount(currentData, currentStreakCount, stars);
    final newRating = result['ratingData'] as RatingData;
    final newStreakCount = result['streakCount'] as int;
    
    // データベースに保存
    await _saveRatingData(newRating, targetUserId);
    
    // ストリークカウントを更新
    await _userProfileService.updateStreakCountDirect(targetUserId, newStreakCount);
    
    return newRating;
  }

  // streakCountベースの新しいレーティング計算
  Map<String, dynamic> calculateNewRatingWithStreakCount(RatingData currentData, int currentStreakCount, int stars) {
    if (stars < 1 || stars > 5) {
      throw ArgumentError('星の評価は1-5の範囲で指定してください');
    }
    
    int newRating = currentData.currentRating;
    int newStreakCount = currentStreakCount;
    
    if (stars <= 2) {
      // ネガティブ評価（星1-2）
      // streakcountの絶対値を取って-1した数値番目をnegativeDropAmountsから選択
      final dropIndex = (currentStreakCount.abs() - 1).clamp(0, negativeDropAmounts.length - 1);
      final dropAmount = negativeDropAmounts[dropIndex];
      newRating = (currentData.currentRating - dropAmount).clamp(0, double.infinity).toInt();
      
      // streakCountの更新: プラスの時に星2以下を取得すると必ず-1になる
      if (currentStreakCount > 0) {
        newStreakCount = -1;
      } else {
        // マイナスの時はさらに減らす（-11以下にはならない）
        newStreakCount = (currentStreakCount - 1).clamp(-10, 5);
      }
      
    } else {
      // ポジティブ評価（星3-5）
      // streakcountの数値を取って-1した数値番目をpositiveMultipliersから選択
      final multiplierIndex = (currentStreakCount - 1).clamp(0, positiveMultipliers.length - 1);
      final multiplier = positiveMultipliers[multiplierIndex];
      final increaseAmount = stars * multiplier;
      newRating = currentData.currentRating + increaseAmount;
      
      // streakCountの更新: マイナスの時に星3以上を取得すると必ず+1になる
      if (currentStreakCount < 0) {
        newStreakCount = 1;
      } else {
        // プラスの時はさらに増やす（6以上にはならない）
        newStreakCount = (currentStreakCount + 1).clamp(-10, 5);
      }
    }
    
    final newRatingData = RatingData(
      currentRating: newRating,
      consecutiveUp: 0, // 旧システムの互換性のため保持
      consecutiveDown: 0, // 旧システムの互換性のため保持
      lastUpdated: DateTime.now(),
    );
    
    print('ストリークカウントベース計算: 星$stars, 現在streak: $currentStreakCount, 新streak: $newStreakCount, レート変化: ${currentData.currentRating} -> $newRating');
    
    return {
      'ratingData': newRatingData,
      'streakCount': newStreakCount,
    };
  }
  
  // 旧しいレーティング計算（互換性のため保持）
  RatingData calculateNewRating(RatingData currentData, int stars) {
    if (stars < 1 || stars > 5) {
      throw ArgumentError('星の評価は1-5の範囲で指定してください');
    }
    
    int newRating = currentData.currentRating;
    int newConsecutiveUp = currentData.consecutiveUp;
    int newConsecutiveDown = currentData.consecutiveDown;
    
    if (stars <= 2) {
      // ネガティブロジック（星1-2）
      newConsecutiveUp = 0; // 上昇連続をリセット
      newConsecutiveDown = currentData.consecutiveDown + 1;
      
      // 下降幅を計算（最大10回目の57まで）
      final dropIndex = (newConsecutiveDown - 1).clamp(0, negativeDropAmounts.length - 1);
      final dropAmount = negativeDropAmounts[dropIndex];
      
      newRating = (currentData.currentRating - dropAmount).clamp(0, double.infinity).toInt();
      
    } else {
      // ポジティブロジック（星3-5）
      newConsecutiveDown = 0; // 下降連続をリセット
      newConsecutiveUp = currentData.consecutiveUp + 1;
      
      // 上昇幅を計算（最大5回目の16まで）
      final multiplierIndex = (newConsecutiveUp - 1).clamp(0, positiveMultipliers.length - 1);
      final multiplier = positiveMultipliers[multiplierIndex];
      final increaseAmount = stars * multiplier;
      
      newRating = currentData.currentRating + increaseAmount;
    }
    
    return RatingData(
      currentRating: newRating,
      consecutiveUp: newConsecutiveUp,
      consecutiveDown: newConsecutiveDown,
      lastUpdated: DateTime.now(),
    );
  }

  // レーティングデータをFirestoreに保存
  Future<void> _saveRatingData(RatingData data, String userId) async {
    try {
      await _db.collection('userRatings').doc(userId).set(data.toMap());
      print('レーティングデータ保存成功: $userId, Rating: ${data.currentRating}');
      
      // UserProfileServiceのレーティングも同期更新
      try {
        if (userId == _userId) {
          // 自分のレーティング更新
          await _userProfileService.updateRating(data.currentRating);
          print('UserProfileレーティング同期成功: ${data.currentRating}');
        } else {
          // 相手のレーティング更新
          await updateProfile(userId, data.currentRating);
          print('相手のUserProfileレーティング同期成功: $userId -> ${data.currentRating}');
        }
      } catch (e) {
        print('UserProfileレーティング同期エラー: $e');
        // 同期エラーでもメインの処理は続行
      }
    } catch (e) {
      print('レーティングデータ保存エラー: $e');
      rethrow;
    }
  }

  // 他のユーザーのプロフィールレーティングを更新
  Future<void> updateProfile(String userId, int rating) async {
    try {
      await _db.collection('userProfiles').doc(userId).set({
        'rating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('プロフィールレーティング更新エラー: $e');
      rethrow;
    }
  }

  // 複数ユーザーのレーティングを一括取得
  Future<Map<String, RatingData>> getBulkRatingData(List<String> userIds) async {
    final Map<String, RatingData> results = {};
    
    try {
      final docs = await _db.collection('userRatings')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();
      
      for (final doc in docs.docs) {
        results[doc.id] = RatingData.fromMap(doc.data());
      }
      
      // 存在しないユーザーにはデフォルト値を設定
      for (final userId in userIds) {
        if (!results.containsKey(userId)) {
          results[userId] = RatingData(
            currentRating: defaultRating,
            consecutiveUp: 0,
            consecutiveDown: 0,
            lastUpdated: DateTime.now(),
          );
        }
      }
      
      return results;
    } catch (e) {
      print('一括レーティングデータ取得エラー: $e');
      
      // エラー時はすべてデフォルト値を返す
      for (final userId in userIds) {
        results[userId] = RatingData(
          currentRating: defaultRating,
          consecutiveUp: 0,
          consecutiveDown: 0,
          lastUpdated: DateTime.now(),
        );
      }
      
      return results;
    }
  }

  // レーティング範囲内のユーザーを検索
  Future<List<String>> findUsersInRatingRange(int centerRating, int range) async {
    try {
      final minRating = centerRating - range;
      final maxRating = centerRating + range;
      
      final querySnapshot = await _db.collection('userRatings')
          .where('currentRating', isGreaterThanOrEqualTo: minRating)
          .where('currentRating', isLessThanOrEqualTo: maxRating)
          .get();
      
      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('レーティング範囲検索エラー: $e');
      return [];
    }
  }

  // レーティング統計を取得
  Future<Map<String, dynamic>> getRatingStats([String? userId]) async {
    final targetUserId = userId ?? _userId;
    if (targetUserId == null) return {};
    
    final data = await getRatingData(targetUserId);
    
    return {
      'currentRating': data.currentRating,
      'consecutiveUp': data.consecutiveUp,
      'consecutiveDown': data.consecutiveDown,
      'lastUpdated': data.lastUpdated,
      'isAboveDefault': data.currentRating > defaultRating,
      'ratingDifference': data.currentRating - defaultRating,
    };
  }

  // 【TEMPORARY DEBUG FUNCTION】- 特定のユーザーのレーティングを1に設定
  // 使用後は必ず削除してください
  Future<bool> debugSetUserRatingToOne(String targetEmail) async {
    try {
      print('=== DEBUG: レーティング1設定開始 ===');
      print('対象メール: $targetEmail');
      
      // 1. userProfilesコレクションでメールアドレスから該当ユーザーを検索
      final querySnapshot = await _db.collection('userProfiles')
          .where('email', isEqualTo: targetEmail)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        // メールアドレスでの検索で見つからない場合、Firebase Authで検索を試みる
        print('userProfilesでメールが見つかりません。Firebase Auth経由で検索中...');
        
        // Firebase Authではメールアドレスで直接検索できないため、
        // 全てのuserProfilesを取得してFirebase Authのemailと照合する必要がある
        // これは効率が悪いので、まずは手動でUIDを特定することを推奨
        
        print('❌ ユーザーが見つかりません: $targetEmail');
        print('💡 手動でUIDを特定してdebugSetUserRatingToOneByUid()を使用してください');
        return false;
      }
      
      // 2. 見つかったユーザーのUIDを取得
      final userDoc = querySnapshot.docs.first;
      final userId = userDoc.id;
      final currentData = userDoc.data() as Map<String, dynamic>;
      
      print('✅ ユーザー発見: $userId');
      print('現在のプロフィール: ${currentData['nickname'] ?? '未設定'}');
      
      // 3. 現在のレーティングを確認
      final currentRatingData = await getRatingData(userId);
      print('現在のレーティング: ${currentRatingData.currentRating}');
      
      // 4. レーティングを1に設定
      final newRatingData = RatingData(
        currentRating: 1,
        consecutiveUp: 0,
        consecutiveDown: 0,
        lastUpdated: DateTime.now(),
      );
      
      // 5. データベースに保存
      await _saveRatingData(newRatingData, userId);
      
      print('✅ レーティング更新完了: ${currentRatingData.currentRating} → 1');
      print('=== DEBUG: レーティング1設定完了 ===');
      
      return true;
    } catch (e) {
      print('❌ DEBUG: レーティング設定エラー: $e');
      return false;
    }
  }

  // 【TEMPORARY DEBUG FUNCTION】- UIDを直接指定してレーティングを1に設定
  // より確実な方法。使用後は必ず削除してください
  Future<bool> debugSetUserRatingToOneByUid(String userId) async {
    try {
      print('=== DEBUG: UID指定レーティング1設定開始 ===');
      print('対象UID: $userId');
      
      // 1. ユーザーの存在確認
      final userDoc = await _db.collection('userProfiles').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ ユーザーが見つかりません: $userId');
        return false;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      print('✅ ユーザー確認: ${userData['nickname'] ?? '未設定'} (${userData['email'] ?? 'メール未設定'})');
      
      // 2. 現在のレーティングを確認
      final currentRatingData = await getRatingData(userId);
      print('現在のレーティング: ${currentRatingData.currentRating}');
      
      // 3. レーティングを1に設定
      final newRatingData = RatingData(
        currentRating: 1,
        consecutiveUp: 0,
        consecutiveDown: 0,
        lastUpdated: DateTime.now(),
      );
      
      // 4. データベースに保存
      await _saveRatingData(newRatingData, userId);
      
      print('✅ レーティング更新完了: ${currentRatingData.currentRating} → 1');
      print('=== DEBUG: UID指定レーティング1設定完了 ===');
      
      return true;
    } catch (e) {
      print('❌ DEBUG: UID指定レーティング設定エラー: $e');
      return false;
    }
  }

  // 【TEMPORARY DEBUG FUNCTION】- 全ユーザーのメールアドレスとUIDを表示
  // serveman520@gmail.comのUIDを特定するのに使用。使用後は必ず削除してください
  Future<void> debugListAllUsersWithEmail() async {
    try {
      print('=== DEBUG: 全ユーザーリスト表示開始 ===');
      
      final querySnapshot = await _db.collection('userProfiles').get();
      
      print('総ユーザー数: ${querySnapshot.docs.length}');
      print('--- ユーザーリスト ---');
      
      for (final doc in querySnapshot.docs) {
        final userData = doc.data();
        final uid = doc.id;
        final email = userData['email'] ?? 'メール未設定';
        final nickname = userData['nickname'] ?? '未設定';
        
        print('UID: $uid');
        print('Email: $email');
        print('Nickname: $nickname');
        print('---');
        
        // 特定のメールアドレスを強調表示
        if (email == 'serveman520@gmail.com') {
          print('🎯 TARGET FOUND! UID: $uid');
          print('🎯 TARGET EMAIL: $email');
          print('🎯 TARGET NICKNAME: $nickname');
        }
      }
      
      print('=== DEBUG: 全ユーザーリスト表示完了 ===');
    } catch (e) {
      print('❌ DEBUG: ユーザーリスト取得エラー: $e');
    }
  }
  
  // デバッグ用: レーティングを直接設定
  Future<void> setRating(int newRating) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('ユーザーが認証されていません');
      }
      
      // userRatingsコレクションに直接設定
      final ratingData = RatingData(
        currentRating: newRating,
        consecutiveUp: 0,
        consecutiveDown: 0,
        lastUpdated: DateTime.now(),
      );
      
      await _db.collection('userRatings').doc(userId).set(ratingData.toMap());
      
      // userProfilesコレクションも同期
      await _db.collection('userProfiles').doc(userId).set({
        'rating': newRating,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('レーティングを$newRatingに直接設定しました');
    } catch (e) {
      print('レーティング直接設定エラー: $e');
      rethrow;
    }
  }
}