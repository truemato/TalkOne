import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'block_service.dart';

/// 通報理由のカテゴリー
enum ReportCategory {
  harassment,          // ハラスメント・嫌がらせ
  inappropriateContent, // 不適切なコンテンツ
  spam,               // スパム
  impersonation,      // なりすまし
  violence,           // 暴力的な内容
  hateSpeech,         // ヘイトスピーチ
  sexualContent,      // 性的なコンテンツ
  other,              // その他
}

/// 通報カテゴリーの日本語表記
extension ReportCategoryExtension on ReportCategory {
  String get displayName {
    switch (this) {
      case ReportCategory.harassment:
        return 'ハラスメント・嫌がらせ';
      case ReportCategory.inappropriateContent:
        return '不適切なコンテンツ';
      case ReportCategory.spam:
        return 'スパム・迷惑行為';
      case ReportCategory.impersonation:
        return 'なりすまし';
      case ReportCategory.violence:
        return '暴力的な内容';
      case ReportCategory.hateSpeech:
        return 'ヘイトスピーチ・差別';
      case ReportCategory.sexualContent:
        return '性的なコンテンツ';
      case ReportCategory.other:
        return 'その他';
    }
  }

  String get description {
    switch (this) {
      case ReportCategory.harassment:
        return '脅迫、いじめ、個人攻撃など';
      case ReportCategory.inappropriateContent:
        return 'アプリの利用規約に違反する内容';
      case ReportCategory.spam:
        return '繰り返しの迷惑メッセージ、広告など';
      case ReportCategory.impersonation:
        return '他人になりすました行為';
      case ReportCategory.violence:
        return '暴力を助長する内容、自傷行為など';
      case ReportCategory.hateSpeech:
        return '人種、宗教、性別などに基づく差別';
      case ReportCategory.sexualContent:
        return '露骨な性的コンテンツ、セクハラなど';
      case ReportCategory.other:
        return '上記以外の問題';
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
      await _firestore.collection('reports').add(reportData);
      
      // 即座にブロック
      await _blockService.blockUser(partnerId);
      
      print('通話を通報し、相手をブロックしました');
      return true;
    } catch (e) {
      print('通話通報エラー: $e');
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