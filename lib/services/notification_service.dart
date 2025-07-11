import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 通知の種類
enum NotificationType {
  reportResponse,  // 通報対応結果
  general,        // 一般通知
  warning,        // 警告
  account,        // アカウント関連
}

/// 通知データモデル
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => NotificationType.general,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// 通知管理サービス
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 通知一覧をストリーム取得
  Stream<List<AppNotification>> getNotificationsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50) // パフォーマンス向上のため制限
          .snapshots()
          .map((snapshot) => 
            snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList()
          );
    } catch (e) {
      print('通知ストリーム取得エラー: $e');
      // フォールバック: orderByなしでクエリ
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .snapshots()
          .map((snapshot) {
            final notifications = snapshot.docs
                .map((doc) => AppNotification.fromFirestore(doc))
                .toList();
            // クライアント側でソート
            notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return notifications;
          });
    }
  }

  /// 未読通知数を取得
  Stream<int> getUnreadCountStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 通知を既読にマーク
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      return true;
    } catch (e) {
      print('通知既読マークエラー: $e');
      return false;
    }
  }

  /// 全ての通知を既読にマーク
  Future<bool> markAllAsRead() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('全通知既読マークエラー: $e');
      return false;
    }
  }

  /// 通知を削除
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
      return true;
    } catch (e) {
      print('通知削除エラー: $e');
      return false;
    }
  }

  /// 通報対応結果通知を送信（管理者用）
  Future<bool> sendReportResponseNotification({
    required String userId,
    required String reportId,
    required String response,
    required String actionTaken,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': NotificationType.reportResponse.toString().split('.').last,
        'title': '通報対応結果',
        'message': response,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': {
          'reportId': reportId,
          'actionTaken': actionTaken,
        },
      });
      return true;
    } catch (e) {
      print('通報対応通知送信エラー: $e');
      return false;
    }
  }

  /// 一般通知を送信
  Future<bool> sendGeneralNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': NotificationType.general.toString().split('.').last,
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': metadata,
      });
      return true;
    } catch (e) {
      print('一般通知送信エラー: $e');
      return false;
    }
  }

  /// 警告通知を送信
  Future<bool> sendWarningNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': NotificationType.warning.toString().split('.').last,
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': metadata,
      });
      return true;
    } catch (e) {
      print('警告通知送信エラー: $e');
      return false;
    }
  }
}