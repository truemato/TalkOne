import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'content_filter_service.dart';

/// 通報の種類
enum ReportType {
  harassment,         // 嫌がらせ・誹謗中傷
  inappropriate,      // 不適切なコンテンツ
  personalInfo,       // 個人情報の漏洩
  spam,              // スパム・迷惑行為
  violence,          // 暴力的な内容
  adult,             // 成人向けコンテンツ
  hate,              // ヘイトスピーチ
  other,             // その他
}

/// 通報の状態
enum ReportStatus {
  pending,           // 対応待ち
  investigating,     // 調査中
  resolved,          // 解決済み
  dismissed,         // 却下
}

/// 処理結果の種類
enum ActionType {
  warning,           // 警告
  temporaryBan,      // 一時停止
  permanentBan,      // 永久停止
  contentRemoval,    // コンテンツ削除
  noAction,          // 処理なし
}

/// 通報データモデル
class Report {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String? callId;
  final ReportType type;
  final String reason;
  final String details;
  final DateTime timestamp;
  final ReportStatus status;
  final String? adminNotes;
  final ActionType? actionTaken;
  final DateTime? resolvedAt;

  Report({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    this.callId,
    required this.type,
    required this.reason,
    required this.details,
    required this.timestamp,
    required this.status,
    this.adminNotes,
    this.actionTaken,
    this.resolvedAt,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reportedUserId: data['reportedUserId'] ?? '',
      callId: data['callId'],
      type: ReportType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => ReportType.other,
      ),
      reason: data['reason'] ?? '',
      details: data['details'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ReportStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => ReportStatus.pending,
      ),
      adminNotes: data['adminNotes'],
      actionTaken: data['actionTaken'] != null
          ? ActionType.values.firstWhere(
              (e) => e.toString().split('.').last == data['actionTaken'],
              orElse: () => ActionType.noAction,
            )
          : null,
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'callId': callId,
      'type': type.toString().split('.').last,
      'reason': reason,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.toString().split('.').last,
      'adminNotes': adminNotes,
      'actionTaken': actionTaken?.toString().split('.').last,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }
}

/// 強化された通報・ブロックサービス
class EnhancedReportingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final ContentFilterService _contentFilterService = ContentFilterService();

  /// 通報を送信
  Future<bool> submitReport({
    required String reportedUserId,
    required ReportType type,
    required String reason,
    required String details,
    String? callId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // 重複通報チェック（同じユーザーからの24時間以内の重複通報を防ぐ）
      final duplicateCheck = await _checkDuplicateReport(userId, reportedUserId);
      if (duplicateCheck) {
        throw Exception('このユーザーに対する通報は24時間以内に既に送信されています');
      }

      // コンテンツフィルタリングで通報内容をチェック
      final filterResult = await _contentFilterService.filterText(details);
      if (filterResult.result == FilterResult.blocked || 
          filterResult.result == FilterResult.severe) {
        throw Exception('通報内容に不適切な表現が含まれています');
      }

      final report = Report(
        id: '',
        reporterId: userId,
        reportedUserId: reportedUserId,
        callId: callId,
        type: type,
        reason: reason,
        details: details,
        timestamp: DateTime.now(),
        status: ReportStatus.pending,
      );

      // Firestoreに保存
      final docRef = await _firestore.collection('reports').add(report.toFirestore());

      // 管理者に緊急通知（重篤な内容の場合）
      if (type == ReportType.violence || type == ReportType.hate) {
        await _sendUrgentAdminNotification(docRef.id, report);
      }

      // 24時間以内の対応を約束する通知をユーザーに送信
      await _notificationService.sendGeneralNotification(
        userId: userId,
        title: '通報を受け付けました',
        message: '通報内容を確認し、24時間以内にサポートチームから対応結果をお知らせします。',
        metadata: {'reportId': docRef.id},
      );

      return true;
    } catch (e) {
      print('通報送信エラー: $e');
      return false;
    }
  }

  /// 重複通報チェック
  Future<bool> _checkDuplicateReport(String reporterId, String reportedUserId) async {
    final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));
    
    final query = await _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: reporterId)
        .where('reportedUserId', isEqualTo: reportedUserId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(oneDayAgo))
        .get();

    return query.docs.isNotEmpty;
  }

  /// 緊急管理者通知
  Future<void> _sendUrgentAdminNotification(String reportId, Report report) async {
    await _firestore.collection('urgentAdminNotifications').add({
      'type': 'urgent_report',
      'reportId': reportId,
      'reportType': report.type.toString().split('.').last,
      'reason': report.reason,
      'timestamp': FieldValue.serverTimestamp(),
      'priority': 'high',
      'resolved': false,
    });
  }

  /// ユーザーをブロック
  Future<bool> blockUser(String blockedUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      await _firestore.collection('blocks').add({
        'blockerId': userId,
        'blockedUserId': blockedUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('ブロックエラー: $e');
      return false;
    }
  }

  /// ユーザーのブロック解除
  Future<bool> unblockUser(String blockedUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final query = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: userId)
          .where('blockedUserId', isEqualTo: blockedUserId)
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      print('ブロック解除エラー: $e');
      return false;
    }
  }

  /// ブロックリストを取得
  Future<List<String>> getBlockedUsers() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final query = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: userId)
          .get();

      return query.docs
          .map((doc) => doc.data()['blockedUserId'] as String)
          .toList();
    } catch (e) {
      print('ブロックリスト取得エラー: $e');
      return [];
    }
  }

  /// ユーザーがブロックされているかチェック
  Future<bool> isUserBlocked(String otherUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      // 自分が相手をブロックしているか
      final blockedByMe = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: userId)
          .where('blockedUserId', isEqualTo: otherUserId)
          .get();

      // 相手が自分をブロックしているか
      final blockedByThem = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: otherUserId)
          .where('blockedUserId', isEqualTo: userId)
          .get();

      return blockedByMe.docs.isNotEmpty || blockedByThem.docs.isNotEmpty;
    } catch (e) {
      print('ブロック状態確認エラー: $e');
      return false;
    }
  }

  /// 通報履歴を取得
  Future<List<Report>> getUserReportHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final query = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return query.docs.map((doc) => Report.fromFirestore(doc)).toList();
    } catch (e) {
      print('通報履歴取得エラー: $e');
      return [];
    }
  }

  /// 管理者用：通報を処理
  Future<bool> processReport({
    required String reportId,
    required ReportStatus status,
    required ActionType actionTaken,
    String? adminNotes,
  }) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': status.toString().split('.').last,
        'actionTaken': actionTaken.toString().split('.').last,
        'adminNotes': adminNotes,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // 通報者に結果を通知
      final report = await _firestore.collection('reports').doc(reportId).get();
      if (report.exists) {
        final reportData = report.data() as Map<String, dynamic>;
        final reporterId = reportData['reporterId'];
        
        await _notificationService.sendReportResponseNotification(
          userId: reporterId,
          reportId: reportId,
          response: _getActionMessage(actionTaken),
          actionTaken: actionTaken.toString().split('.').last,
        );
      }

      return true;
    } catch (e) {
      print('通報処理エラー: $e');
      return false;
    }
  }

  /// アクションメッセージを取得
  String _getActionMessage(ActionType actionType) {
    switch (actionType) {
      case ActionType.warning:
        return '通報内容を確認し、対象ユーザーに警告を行いました。';
      case ActionType.temporaryBan:
        return '通報内容を確認し、対象ユーザーを一時停止いたしました。';
      case ActionType.permanentBan:
        return '通報内容を確認し、対象ユーザーを永久停止いたしました。';
      case ActionType.contentRemoval:
        return '通報内容を確認し、不適切なコンテンツを削除いたしました。';
      case ActionType.noAction:
        return '通報内容を確認いたしましたが、規約違反には該当しませんでした。';
    }
  }

  /// 通報統計を取得
  Future<Map<String, dynamic>> getReportStats() async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

      final todayReports = await _firestore
          .collection('reports')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .get();

      final weekReports = await _firestore
          .collection('reports')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneWeekAgo))
          .get();

      final pendingReports = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .get();

      return {
        'todayReports': todayReports.docs.length,
        'weekReports': weekReports.docs.length,
        'pendingReports': pendingReports.docs.length,
      };
    } catch (e) {
      print('通報統計取得エラー: $e');
      return {
        'todayReports': 0,
        'weekReports': 0,
        'pendingReports': 0,
      };
    }
  }
}