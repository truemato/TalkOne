import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'block_service.dart';
import 'localization_service.dart';

/// 通報理由のカテゴリー（改善版 - 6種類）
enum ReportCategory {
  harassment,          // ハラスメント
  inappropriateSpeech, // 不適切な発言
  spam,               // 迷惑行為
  discrimination,     // 差別・誹謗中傷
  impersonation,      // なりすまし
  other,              // その他
}

/// 通報カテゴリーの多言語対応表記
extension ReportCategoryExtension on ReportCategory {
  String get displayName {
    final localization = LocalizationService();
    switch (this) {
      case ReportCategory.harassment:
        return localization.translate('report_category_harassment');
      case ReportCategory.inappropriateSpeech:
        return localization.translate('report_category_inappropriate_speech');
      case ReportCategory.spam:
        return localization.translate('report_category_spam');
      case ReportCategory.discrimination:
        return localization.translate('report_category_discrimination');
      case ReportCategory.impersonation:
        return localization.translate('report_category_impersonation');
      case ReportCategory.other:
        return localization.translate('report_category_other');
    }
  }

  String get description {
    final localization = LocalizationService();
    switch (this) {
      case ReportCategory.harassment:
        return localization.translate('report_category_harassment_desc');
      case ReportCategory.inappropriateSpeech:
        return localization.translate('report_category_inappropriate_speech_desc');
      case ReportCategory.spam:
        return localization.translate('report_category_spam_desc');
      case ReportCategory.discrimination:
        return localization.translate('report_category_discrimination_desc');
      case ReportCategory.impersonation:
        return localization.translate('report_category_impersonation_desc');
      case ReportCategory.other:
        return localization.translate('report_category_other_desc');
    }
  }
}

/// 通報サービス
class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BlockService _blockService = BlockService();

  /// 現在のユーザーID取得
  String? get _currentUserId => _auth.currentUser?.uid;

  /// ユーザーを通報する
  Future<bool> reportUser({
    required String reportedUserId,
    required String callId,
    required ReportCategory category,
    String? details,
    bool autoBlock = true,
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('ユーザーが認証されていません');
      }

      if (_currentUserId == reportedUserId) {
        throw Exception('自分自身を通報することはできません');
      }

      // 通報データを作成
      final reportData = {
        'reporterId': _currentUserId,
        'reportedUserId': reportedUserId,
        'callId': callId,
        'category': category.name,
        'categoryDisplayName': category.displayName,
        'details': details ?? '',
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewing, resolved
        'autoBlocked': autoBlock,
      };

      // 通報を保存
      final reportRef = await _firestore.collection('reports').add(reportData);
      
      print('通報を送信しました: ${reportRef.id}');

      // 自動ブロックが有効な場合
      if (autoBlock) {
        await _blockService.blockUser(reportedUserId);
        print('通報したユーザーを自動的にブロックしました');
      }

      // 管理者への通知（将来的にCloud Functionsで実装）
      await _notifyAdmins(reportData);

      return true;
    } catch (e) {
      print('通報エラー: $e');
      return false;
    }
  }

  /// 通話中の不適切な行為を通報
  Future<bool> reportCall({
    required String partnerId,
    required String callId,
    required ReportCategory category,
    String? details,
    int? timestamp, // 通話開始からの秒数
  }) async {
    try {
      print('[ReportService] 通話通報開始: reporter=$_currentUserId, reported=$partnerId, category=${category.name}');
      
      if (_currentUserId == null) {
        throw Exception('ユーザーが認証されていません');
      }

      // 通報データを作成
      final reportData = {
        'reporterId': _currentUserId,
        'reportedUserId': partnerId,
        'callId': callId,
        'category': category.name,
        'categoryDisplayName': category.displayName,
        'details': details ?? '',
        'timestamp': timestamp,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': 'call_report',
      };

      // 通報を保存
      print('[ReportService] 通報データをFirestoreに保存中...');
      final reportRef = await _firestore.collection('reports').add(reportData);
      print('[ReportService] 通報データ保存完了: ${reportRef.id}');
      
      // 即座にブロック
      print('[ReportService] ブロック処理を開始...');
      final blockSuccess = await _blockService.blockUser(partnerId);
      
      if (blockSuccess) {
        print('[ReportService] ✓ 通話を通報し、相手をブロックしました: $partnerId');
      } else {
        print('[ReportService] ✗ 通報は成功しましたが、ブロック処理に失敗しました');
      }
      
      return blockSuccess;
    } catch (e) {
      print('[ReportService] 通話通報エラー: $e');
      return false;
    }
  }

  /// 管理者に通知（将来的にCloud Functionsで実装）
  Future<void> _notifyAdmins(Map<String, dynamic> reportData) async {
    // TODO: Cloud Functionsを使用してメール通知やSlack通知を実装
    // 現在は管理者用のコレクションに通知を追加
    try {
      await _firestore.collection('adminNotifications').add({
        'type': 'new_report',
        'reportData': reportData,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('管理者通知エラー: $e');
    }
  }

  /// 特定のユーザーが通報されているかチェック
  Future<bool> isUserReported(String userId) async {
    try {
      final reports = await _firestore
          .collection('reports')
          .where('reportedUserId', isEqualTo: userId)
          .where('reporterId', isEqualTo: _currentUserId)
          .limit(1)
          .get();
      
      return reports.docs.isNotEmpty;
    } catch (e) {
      print('通報確認エラー: $e');
      return false;
    }
  }

  /// ユーザーの通報履歴を取得
  Future<List<Map<String, dynamic>>> getUserReportHistory(String userId) async {
    try {
      final reports = await _firestore
          .collection('reports')
          .where('reportedUserId', isEqualTo: userId)
          .orderBy('reportedAt', descending: true)
          .get();
      
      return reports.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('通報履歴取得エラー: $e');
      return [];
    }
  }

  /// 通報回数を取得
  Future<int> getReportCount(String userId) async {
    try {
      final reports = await _firestore
          .collection('reports')
          .where('reportedUserId', isEqualTo: userId)
          .get();
      
      return reports.docs.length;
    } catch (e) {
      print('通報回数取得エラー: $e');
      return 0;
    }
  }
}