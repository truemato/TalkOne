import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  
  static const String _lastVersionKey = 'last_app_version';
  
  /// アプリ起動時にバージョンチェックを実行
  Future<void> checkVersionOnStartup() async {
    if (_userId == null) return;
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = packageInfo.buildNumber;
      final fullVersion = '$currentVersion+$currentBuildNumber';
      
      final prefs = await SharedPreferences.getInstance();
      final lastVersion = prefs.getString(_lastVersionKey);
      
      print('バージョンチェック: 現在=$fullVersion, 前回=$lastVersion');
      
      // 初回起動または新バージョンの場合
      if (lastVersion == null) {
        print('初回起動: バージョン$fullVersionを記録');
        await prefs.setString(_lastVersionKey, fullVersion);
        return;
      }
      
      if (lastVersion != fullVersion) {
        print('新バージョン検出: $lastVersion → $fullVersion');
        
        // バージョンアップ通知を作成
        await _createVersionUpdateNotification(
          fromVersion: lastVersion,
          toVersion: fullVersion,
        );
        
        // 新バージョンを記録
        await prefs.setString(_lastVersionKey, fullVersion);
      }
    } catch (e) {
      print('バージョンチェックエラー: $e');
    }
  }
  
  /// バージョンアップ通知を作成
  Future<void> _createVersionUpdateNotification({
    required String fromVersion,
    required String toVersion,
  }) async {
    if (_userId == null) return;
    
    try {
      // 通知データを作成
      final notificationData = {
        'userId': _userId,
        'type': 'version_update',
        'title': 'アップデート完了',
        'message': 'TalkOne $toVersionにアップデートしました！',
        'fromVersion': fromVersion,
        'toVersion': toVersion,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': {
          'updateType': 'version_upgrade',
          'platform': 'testflight',
        }
      };
      
      // Firestoreに保存
      await _firestore
          .collection('notifications')
          .add(notificationData);
      
      print('バージョンアップ通知作成完了: $fromVersion → $toVersion');
    } catch (e) {
      print('バージョンアップ通知作成エラー: $e');
    }
  }
  
  /// ユーザーの通知リストを取得
  Stream<List<VersionNotification>> getUserNotifications() {
    if (_userId == null) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VersionNotification.fromFirestore(doc))
            .toList());
  }
  
  /// 通知を既読にマーク
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('通知既読エラー: $e');
    }
  }
  
  /// 未読通知数を取得
  Future<int> getUnreadCount() async {
    if (_userId == null) return 0;
    
    try {
      final result = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      return result.docs.length;
    } catch (e) {
      print('未読数取得エラー: $e');
      return 0;
    }
  }
  
  /// テスト用: 手動でバージョンアップ通知を作成
  Future<void> createTestVersionNotification() async {
    await _createVersionUpdateNotification(
      fromVersion: '0.8.0+8',
      toVersion: '0.9.0+9',
    );
  }
}

/// 通知データクラス
class VersionNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? fromVersion;
  final String? toVersion;
  final DateTime? createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  
  VersionNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.fromVersion,
    this.toVersion,
    this.createdAt,
    required this.isRead,
    this.metadata,
  });
  
  factory VersionNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VersionNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      fromVersion: data['fromVersion'],
      toVersion: data['toVersion'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }
  
  /// 相対時間表示用
  String get relativeTime {
    if (createdAt == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(createdAt!);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }
  
  /// バージョンアップかどうか
  bool get isVersionUpdate => type == 'version_update';
}