import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';

/// コンテンツフィルタリングの結果
enum FilterResult {
  safe,           // 安全
  warning,        // 警告レベル
  blocked,        // ブロック
  severe,         // 重篤な違反
}

/// フィルタリング詳細結果
class ContentFilterResult {
  final FilterResult result;
  final String reason;
  final double confidence;
  final List<String> categories;

  ContentFilterResult({
    required this.result,
    required this.reason,
    required this.confidence,
    required this.categories,
  });
}

/// 不適切コンテンツフィルタリングサービス
class ContentFilterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// テキストコンテンツをフィルタリング
  Future<ContentFilterResult> filterText(String text) async {
    try {
      // 基本的なキーワードフィルタリング
      final basicResult = _basicKeywordFilter(text);
      if (basicResult.result != FilterResult.safe) {
        await _logFilterResult(text, basicResult);
        return basicResult;
      }

      // AIによる高度フィルタリング
      final aiResult = await _aiContentFilter(text);
      await _logFilterResult(text, aiResult);
      
      return aiResult;
    } catch (e) {
      print('コンテンツフィルタリングエラー: $e');
      // エラー時は安全側に倒してフィルタリング
      return ContentFilterResult(
        result: FilterResult.warning,
        reason: 'フィルタリングエラーが発生しました',
        confidence: 0.5,
        categories: ['error'],
      );
    }
  }

  /// 基本的なキーワードベースフィルタリング
  ContentFilterResult _basicKeywordFilter(String text) {
    final normalizedText = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    
    // 重篤な違反キーワード
    final severeKeywords = [
      'kill', 'die', 'death', 'suicide', 'murder',
      '殺', '死', '自殺', '殺人', '暴力',
      '薬物', 'ドラッグ', '麻薬',
    ];
    
    // ブロック対象キーワード
    final blockedKeywords = [
      'sex', 'porn', 'nude', 'naked',
      'セックス', 'エッチ', 'えっち', 'アダルト',
      '住所', '電話番号', 'line', 'ライン',
      'money', 'お金', '金', 'ビットコイン',
    ];
    
    // 警告キーワード
    final warningKeywords = [
      'stupid', 'idiot', 'hate', 'ugly',
      'バカ', 'あほ', '馬鹿', 'クズ', 'ブス',
      '嫌い', 'うざい', 'きもい',
    ];

    for (final keyword in severeKeywords) {
      if (normalizedText.contains(keyword)) {
        return ContentFilterResult(
          result: FilterResult.severe,
          reason: '重篤な不適切コンテンツが検出されました',
          confidence: 1.0,
          categories: ['violence', 'self_harm'],
        );
      }
    }

    for (final keyword in blockedKeywords) {
      if (normalizedText.contains(keyword)) {
        return ContentFilterResult(
          result: FilterResult.blocked,
          reason: '不適切なコンテンツが検出されました',
          confidence: 0.9,
          categories: ['adult', 'personal_info'],
        );
      }
    }

    for (final keyword in warningKeywords) {
      if (normalizedText.contains(keyword)) {
        return ContentFilterResult(
          result: FilterResult.warning,
          reason: '不適切な表現が含まれています',
          confidence: 0.7,
          categories: ['harassment'],
        );
      }
    }

    return ContentFilterResult(
      result: FilterResult.safe,
      reason: '問題ありません',
      confidence: 0.8,
      categories: [],
    );
  }

  /// AIによる高度なコンテンツフィルタリング
  Future<ContentFilterResult> _aiContentFilter(String text) async {
    try {
      final prompt = '''
以下のテキストが不適切なコンテンツを含んでいるかを判定してください。

判定基準：
1. 暴力的な内容
2. 性的な内容
3. 個人情報（住所、電話番号、SNSアカウント等）
4. ヘイトスピーチ・差別的発言
5. 自傷・自殺に関する内容
6. 薬物・違法行為
7. 嫌がらせ・誹謗中傷

テキスト: "$text"

以下の形式で回答してください：
結果: [SAFE/WARNING/BLOCKED/SEVERE]
理由: [具体的な理由]
信頼度: [0.0-1.0]
カテゴリ: [該当するカテゴリをカンマ区切り]
''';

      final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.0-flash-exp');
      final response = await model.generateContent([Content.text(prompt)]);
      
      if (response.text != null) {
        return _parseAIResponse(response.text!);
      }
      
      return ContentFilterResult(
        result: FilterResult.safe,
        reason: 'AI判定完了',
        confidence: 0.8,
        categories: [],
      );
    } catch (e) {
      print('AI フィルタリングエラー: $e');
      return ContentFilterResult(
        result: FilterResult.safe,
        reason: 'AI判定スキップ',
        confidence: 0.5,
        categories: [],
      );
    }
  }

  /// AI応答をパース
  ContentFilterResult _parseAIResponse(String response) {
    try {
      final lines = response.split('\n');
      FilterResult result = FilterResult.safe;
      String reason = '問題ありません';
      double confidence = 0.8;
      List<String> categories = [];

      for (final line in lines) {
        if (line.startsWith('結果:')) {
          final resultStr = line.substring(3).trim();
          switch (resultStr) {
            case 'WARNING':
              result = FilterResult.warning;
              break;
            case 'BLOCKED':
              result = FilterResult.blocked;
              break;
            case 'SEVERE':
              result = FilterResult.severe;
              break;
            default:
              result = FilterResult.safe;
          }
        } else if (line.startsWith('理由:')) {
          reason = line.substring(3).trim();
        } else if (line.startsWith('信頼度:')) {
          final confidenceStr = line.substring(4).trim();
          confidence = double.tryParse(confidenceStr) ?? 0.8;
        } else if (line.startsWith('カテゴリ:')) {
          final categoryStr = line.substring(5).trim();
          categories = categoryStr.split(',').map((e) => e.trim()).toList();
        }
      }

      return ContentFilterResult(
        result: result,
        reason: reason,
        confidence: confidence,
        categories: categories,
      );
    } catch (e) {
      print('AI応答パースエラー: $e');
      return ContentFilterResult(
        result: FilterResult.warning,
        reason: 'AI応答の解析に失敗しました',
        confidence: 0.5,
        categories: ['parse_error'],
      );
    }
  }

  /// フィルタリング結果をログに記録
  Future<void> _logFilterResult(String text, ContentFilterResult result) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('contentFilterLogs').add({
        'userId': userId,
        'text': text,
        'result': result.result.toString(),
        'reason': result.reason,
        'confidence': result.confidence,
        'categories': result.categories,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 重篤な違反の場合は管理者通知
      if (result.result == FilterResult.severe) {
        await _sendAdminAlert(userId, text, result);
      }
    } catch (e) {
      print('フィルターログ記録エラー: $e');
    }
  }

  /// 管理者アラート送信
  Future<void> _sendAdminAlert(String userId, String text, ContentFilterResult result) async {
    try {
      await _firestore.collection('adminAlerts').add({
        'type': 'severe_content_violation',
        'userId': userId,
        'text': text,
        'filterResult': {
          'result': result.result.toString(),
          'reason': result.reason,
          'confidence': result.confidence,
          'categories': result.categories,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'resolved': false,
      });
    } catch (e) {
      print('管理者アラート送信エラー: $e');
    }
  }

  /// ユーザーの違反履歴を取得
  Future<List<Map<String, dynamic>>> getUserViolationHistory(String userId) async {
    try {
      final query = await _firestore
          .collection('contentFilterLogs')
          .where('userId', isEqualTo: userId)
          .where('result', whereIn: ['blocked', 'severe'])
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('違反履歴取得エラー: $e');
      return [];
    }
  }

  /// ユーザーの警告回数を取得
  Future<int> getUserWarningCount(String userId, {Duration? period}) async {
    try {
      DateTime? startTime;
      if (period != null) {
        startTime = DateTime.now().subtract(period);
      }

      Query query = _firestore
          .collection('contentFilterLogs')
          .where('userId', isEqualTo: userId)
          .where('result', whereIn: ['warning', 'blocked', 'severe']);

      if (startTime != null) {
        query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(startTime));
      }

      final result = await query.get();
      return result.docs.length;
    } catch (e) {
      print('警告回数取得エラー: $e');
      return 0;
    }
  }

  /// コンテンツフィルタリングの統計を取得
  Future<Map<String, dynamic>> getFilteringStats() async {
    try {
      final oneDay = DateTime.now().subtract(const Duration(days: 1));
      final oneWeek = DateTime.now().subtract(const Duration(days: 7));

      final todayQuery = await _firestore
          .collection('contentFilterLogs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneDay))
          .get();

      final weekQuery = await _firestore
          .collection('contentFilterLogs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneWeek))
          .get();

      final todayBlocked = todayQuery.docs.where((doc) => 
        ['blocked', 'severe'].contains(doc.data()['result'])).length;
      
      final weekBlocked = weekQuery.docs.where((doc) => 
        ['blocked', 'severe'].contains(doc.data()['result'])).length;

      return {
        'todayTotal': todayQuery.docs.length,
        'todayBlocked': todayBlocked,
        'weekTotal': weekQuery.docs.length,
        'weekBlocked': weekBlocked,
      };
    } catch (e) {
      print('統計取得エラー: $e');
      return {
        'todayTotal': 0,
        'todayBlocked': 0,
        'weekTotal': 0,
        'weekBlocked': 0,
      };
    }
  }
}