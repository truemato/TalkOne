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
}