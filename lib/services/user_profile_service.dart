import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  final String? nickname;
  final String? gender;
  final DateTime? birthday;
  final String? comment; // みんなに一言（20文字制限）
  final String? aiMemory;
  final String? iconPath;
  final int themeIndex;
  final int rating;
  final int streakCount; // -10から+5までのストリークカウント
  final bool useVoicevox; // VOICEVOX使用設定（true: VOICEVOX, false: Flutter TTS）
  final int aiPersonalityId; // AIペルソナID（0-4）

  UserProfile({
    this.nickname,
    this.gender,
    this.birthday,
    this.comment,
    this.aiMemory,
    this.iconPath,
    this.themeIndex = 0,
    this.rating = 1000,
    this.streakCount = 0,
    this.useVoicevox = false,
    this.aiPersonalityId = 1, // デフォルトはずんだもん
  });

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'gender': gender,
      'birthday': birthday?.millisecondsSinceEpoch,
      'comment': comment,
      'aiMemory': aiMemory,
      'iconPath': iconPath,
      'themeIndex': themeIndex,
      'rating': rating,
      'streakCount': streakCount,
      'useVoicevox': useVoicevox,
      'aiPersonalityId': aiPersonalityId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      nickname: map['nickname'],
      gender: map['gender'],
      birthday: map['birthday'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['birthday'])
          : null,
      comment: map['comment'],
      aiMemory: map['aiMemory'],
      iconPath: map['iconPath'],
      themeIndex: map['themeIndex'] ?? 0,
      rating: map['rating'] ?? 1000,
      streakCount: map['streakCount'] ?? 0,
      useVoicevox: map['useVoicevox'] ?? false,
      aiPersonalityId: map['aiPersonalityId'] ?? 1,
    );
  }

  UserProfile copyWith({
    String? nickname,
    String? gender,
    DateTime? birthday,
    String? comment,
    String? aiMemory,
    String? iconPath,
    int? themeIndex,
    int? rating,
    int? streakCount,
    bool? useVoicevox,
    int? aiPersonalityId,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      comment: comment ?? this.comment,
      aiMemory: aiMemory ?? this.aiMemory,
      iconPath: iconPath ?? this.iconPath,
      themeIndex: themeIndex ?? this.themeIndex,
      rating: rating ?? this.rating,
      streakCount: streakCount ?? this.streakCount,
      useVoicevox: useVoicevox ?? this.useVoicevox,
      aiPersonalityId: aiPersonalityId ?? this.aiPersonalityId,
    );
  }
}

class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? get _userId => _auth.currentUser?.uid;
  
  // デバッグ用: 現在のユーザーIDを取得
  String? get currentUserId => _userId;
  
  // プロフィールを取得
  Future<UserProfile?> getUserProfile() async {
    if (_userId == null) return null;
    
    try {
      final doc = await _db.collection('userProfiles').doc(_userId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('プロフィール取得エラー: $e');
      return null;
    }
  }

  // 特定のユーザーのプロフィールを取得
  Future<UserProfile?> getUserProfileById(String userId) async {
    try {
      final doc = await _db.collection('userProfiles').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('プロフィール取得エラー (userId: $userId): $e');
      return null;
    }
  }

  // プロフィールを保存
  Future<bool> saveUserProfile(UserProfile profile) async {
    if (_userId == null) return false;
    
    try {
      await _db.collection('userProfiles').doc(_userId).set(
        profile.toMap(),
        SetOptions(merge: true),
      );
      print('プロフィール保存成功');
      return true;
    } catch (e) {
      print('プロフィール保存エラー: $e');
      return false;
    }
  }

  // プロフィール全体を更新（複数フィールド一括更新）
  Future<void> updateProfile({
    String? nickname,
    String? gender,
    DateTime? birthday,
    String? comment,
    String? aiMemory,
    String? iconPath,
    int? themeIndex,
    bool? useVoicevox,
    int? aiPersonalityId,
  }) async {
    if (_userId == null) {
      throw Exception('ユーザーが認証されていません');
    }
    
    try {
      final Map<String, dynamic> updateData = {};
      
      if (nickname != null) updateData['nickname'] = nickname;
      if (gender != null) updateData['gender'] = gender;
      if (birthday != null) updateData['birthday'] = birthday.millisecondsSinceEpoch;
      if (comment != null) updateData['comment'] = comment;
      if (aiMemory != null) updateData['aiMemory'] = aiMemory;
      if (iconPath != null) updateData['iconPath'] = iconPath;
      if (themeIndex != null) updateData['themeIndex'] = themeIndex;
      if (useVoicevox != null) updateData['useVoicevox'] = useVoicevox;
      if (aiPersonalityId != null) updateData['aiPersonalityId'] = aiPersonalityId;
      
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _db.collection('userProfiles').doc(_userId).set(
        updateData,
        SetOptions(merge: true),
      );
      
      print('プロフィール一括更新成功');
    } catch (e) {
      print('プロフィール一括更新エラー: $e');
      rethrow;
    }
  }

  // 個別フィールドを更新
  Future<bool> updateNickname(String nickname) async {
    if (_userId == null) return false;
    
    try {
      await _db.collection('userProfiles').doc(_userId).set({
        'nickname': nickname,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('ニックネーム更新成功: $nickname');
      return true;
    } catch (e) {
      print('ニックネーム更新エラー: $e');
      return false;
    }
  }

  Future<bool> updateGender(String gender) async {
    if (_userId == null) return false;
    
    try {
      await _db.collection('userProfiles').doc(_userId).set({
        'gender': gender,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('性別更新成功: $gender');
      return true;
    } catch (e) {
      print('性別更新エラー: $e');
      return false;
    }
  }

  Future<bool> updateBirthday(DateTime birthday) async {
    if (_userId == null) return false;
    
    try {
      await _db.collection('userProfiles').doc(_userId).set({
        'birthday': birthday.millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('誕生日更新成功: $birthday');
      return true;
    } catch (e) {
      print('誕生日更新エラー: $e');
      return false;
    }
  }

  Future<bool> updateAiMemory(String aiMemory) async {
    if (_userId == null) return false;
    
    try {
      await _db.collection('userProfiles').doc(_userId).set({
        'aiMemory': aiMemory,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('AI記憶更新成功: $aiMemory');
      return true;
    } catch (e) {
      print('AI記憶更新エラー: $e');
      return false;
    }
  }

  Future<bool> updateIconPath(String iconPath) async {
    if (_userId == null) return false;
    
    try {
      await _db.collection('userProfiles').doc(_userId).set({
        'iconPath': iconPath,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('アイコン更新成功: $iconPath');
      return true;
    } catch (e) {
      print('アイコン更新エラー: $e');
      return false;
    }
  }

  Future<bool> updateThemeIndex(int themeIndex) async {
    if (_userId == null) return false;
    
    try {
      await _db.collection('userProfiles').doc(_userId).set({
        'themeIndex': themeIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('テーマ更新成功: $themeIndex');
      return true;
    } catch (e) {
      print('テーマ更新エラー: $e');
      return false;
    }
  }

  // プロフィールの変更を監視
  Stream<UserProfile?> watchUserProfile() {
    if (_userId == null) {
      return Stream.value(null);
    }
    
    return _db.collection('userProfiles').doc(_userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // 匿名認証でユーザーを作成
  Future<bool> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
      print('匿名認証成功');
      return true;
    } catch (e) {
      print('匿名認証エラー: $e');
      return false;
    }
  }

  // 現在のユーザーIDを取得
  String? getCurrentUserId() {
    return _userId;
  }
  
  // レーティングを更新
  Future<bool> updateRating(int rating) async {
    if (_userId == null) return false;
    
    try {
      await _db.collection('userProfiles').doc(_userId).set({
        'rating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('レーティング更新成功: $rating');
      return true;
    } catch (e) {
      print('レーティング更新エラー: $e');
      return false;
    }
  }
  
  // ストリークカウントを更新するメソッド（旧システム、互換性のため保持）
  Future<bool> updateStreakCount(String userId, int receivedStars) async {
    try {
      // 現在のストリークカウントを取得
      final profile = await getUserProfileById(userId);
      int currentStreak = profile?.streakCount ?? 0;
      
      // ストリークカウントを更新（星3以上で+1、星2以下で-1）
      int newStreak;
      if (receivedStars >= 3) {
        newStreak = (currentStreak + 1).clamp(-10, 5);
      } else {
        newStreak = (currentStreak - 1).clamp(-10, 5);
      }
      
      // Firebaseに更新
      await _db.collection('userProfiles').doc(userId).set({
        'streakCount': newStreak,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('ストリークカウント更新成功: $userId -> $currentStreak to $newStreak (星$receivedStars)');
      return true;
    } catch (e) {
      print('ストリークカウント更新エラー: $e');
      return false;
    }
  }
  
  // ストリークカウントを直接設定するメソッド（新システム用）
  Future<bool> updateStreakCountDirect(String userId, int newStreakCount) async {
    try {
      await _db.collection('userProfiles').doc(userId).set({
        'streakCount': newStreakCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('ストリークカウント直接更新成功: $userId -> $newStreakCount');
      return true;
    } catch (e) {
      print('ストリークカウント直接更新エラー: $e');
      return false;
    }
  }

  // AIアシスタント名を取得
  String getAIAssistantName(int personalityId) {
    final personalityNames = [
      '春日部つむぎ',      // 0
      'ずんだもん',        // 1
      '四国めたん',        // 2
      '春日部つむぎ',      // 3（設定画面の「雨晴はう」は「春日部つむぎ」に対応）
      '青山龍星',          // 4
      '冥鳴ひまり',        // 5
    ];
    
    if (personalityId >= 0 && personalityId < personalityNames.length) {
      return personalityNames[personalityId];
    }
    return 'ずんだもん'; // デフォルト
  }

  // 現在設定されているAIアシスタント名を取得
  Future<String> getCurrentAIAssistantName() async {
    final profile = await getUserProfile();
    final personalityId = profile?.aiPersonalityId ?? 1;
    return getAIAssistantName(personalityId);
  }
}