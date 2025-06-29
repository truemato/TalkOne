// lib/services/conversation_memory.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';

class ConversationMemory {
  final _db = FirebaseFirestore.instance;
  final GenerativeModel _summarizerModel;
  
  ConversationMemory() : 
    _summarizerModel = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.0-flash-lite',
      systemInstruction: Content.text('あなたはJSON形式のみで応答するアシスタントです。説明や挨拶は不要です。')
    );
  
  // 会話全体のサマリーを生成
  Future<Map<String, dynamic>> generateConversationSummary(
    List<({String from, String text})> messages,
    Duration conversationDuration,
  ) async {
    if (messages.isEmpty) {
      return {
        'summary': '会話がありませんでした',
        'topics': [],
        'userTraits': [],
        'keyPoints': [],
      };
    }
    
    // ユーザーのメッセージのみを抽出
    final userMessages = messages
        .where((m) => m.from == 'me' || m.from == 'user')
        .map((m) => m.text)
        .toList();
    
    // AI応答も含めた全体の会話
    final fullConversation = messages
        .where((m) => m.from != 'system')
        .map((m) => '${m.from == "me" ? "ユーザー" : "AI"}: ${m.text}')
        .join('\n');
    
    try {
      print('会話サマリー生成開始...');
      print('メッセージ数: ${messages.length}');
      print('会話時間: ${conversationDuration.inMinutes}分${conversationDuration.inSeconds % 60}秒');
      
      // 会話が空の場合のチェック
      if (fullConversation.trim().isEmpty) {
        print('会話が空です');
        return {
          'summary': '会話がありませんでした',
          'topics': [],
          'userTraits': [],
          'keyPoints': [],
          'mood': 'neutral',
          'userMessageCount': 0,
        };
      }
      
      // シンプルなプロンプトに変更
      final prompt = '''
会話内容:
$fullConversation

上記の会話を以下のJSON形式で要約してください。JSONのみを返してください:
{"summary": "要約文", "topics": ["話題1"], "mood": "positive"}
''';
      
      final response = await _summarizerModel.generateContent([
        Content.text(prompt)
      ]);
      
      final jsonText = response.text ?? '{}';
      print('AI応答: $jsonText');
      
      // JSONを抽出（マークダウンコードブロックを除去）
      final cleanJson = jsonText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      // JSONの開始位置を探す
      final jsonStart = cleanJson.indexOf('{');
      final jsonEnd = cleanJson.lastIndexOf('}');
      
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('JSON形式が見つかりません');
      }
      
      final extractedJson = cleanJson.substring(jsonStart, jsonEnd + 1);
      print('抽出されたJSON: $extractedJson');
      
      return Map<String, dynamic>.from(
        jsonDecode(extractedJson) as Map,
      );
    } catch (e, stackTrace) {
      print('サマリー生成エラー: $e');
      print('スタックトレース: $stackTrace');
      
      // フォールバックとしてシンプルなサマリーを生成
      final simpleUserCount = messages.where((m) => m.from == 'me' || m.from == 'user').length;
      final simpleAiCount = messages.where((m) => m.from == 'ai').length;
      
      // エラーの種類に応じてメッセージを変える
      String errorSummary = '会話の要約に失敗しました';
      if (e.toString().contains('FormatException')) {
        errorSummary = 'AI応答の形式エラー';
      }
      
      return {
        'summary': errorSummary,
        'topics': ['会話記録あり'],
        'userTraits': [],
        'keyPoints': [],
        'mood': 'neutral',
        'userMessageCount': simpleUserCount,
        'aiMessageCount': simpleAiCount,
        'error': e.toString(),
      };
    }
  }
  
  // ユーザーのメモリーを保存
  Future<void> saveUserMemory(
    String userId,
    DocumentReference conversationRef,
    Map<String, dynamic> summary,
  ) async {
    final userDoc = _db.collection('users').doc(userId);
    
    // 会話サマリーを保存
    await conversationRef.update({
      'summary': summary,
      'summarizedAt': FieldValue.serverTimestamp(),
    });
    
    // ユーザープロファイルを更新（詳細情報を含む）
    await userDoc.set({
      'lastConversation': {
        'summary': summary['summary'],
        'topics': summary['topics'],
        'personalInfo': summary['personalInfo'],
        'userTraits': summary['userTraits'],
        'mood': summary['mood'],
        'timestamp': FieldValue.serverTimestamp(),
      },
      'conversationCount': FieldValue.increment(1),
      // 累積情報を更新
      'cumulativeTopics': FieldValue.arrayUnion(summary['topics'] ?? []),
      'lastPersonalInfo': summary['personalInfo'],
      'lastUserTraits': summary['userTraits'],
    }, SetOptions(merge: true));
    
    // 過去の会話履歴に追加（詳細情報付き）
    await userDoc.collection('conversationHistory').add({
      'conversationRef': conversationRef,
      'summary': summary['summary'],
      'topics': summary['topics'],
      'keyPoints': summary['keyPoints'],
      'personalInfo': summary['personalInfo'],
      'userTraits': summary['userTraits'],
      'mood': summary['mood'],
      'duration': summary['duration'],
      'userMessageCount': summary['userMessageCount'],
      'personalityId': summary['personalityId'],
      'personalityName': summary['personalityName'],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  // ユーザーの過去の会話コンテキストを取得
  Future<String> getUserContext(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return '';
      }
      
      // 最近の会話履歴を取得（最大5件）
      final historyQuery = await _db
          .collection('users')
          .doc(userId)
          .collection('conversationHistory')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      
      // ユーザープロファイル情報も取得
      final userProfile = userDoc.data();
      
      if (historyQuery.docs.isEmpty && userProfile == null) {
        return '';
      }
      
      final histories = historyQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'summary': data['summary'] ?? '',
          'topics': List<String>.from(data['topics'] ?? []),
          'personalInfo': List<String>.from(data['personalInfo'] ?? []),
          'userTraits': List<String>.from(data['userTraits'] ?? []),
          'keyPoints': List<String>.from(data['keyPoints'] ?? []),
          'mood': data['mood'] ?? 'neutral',
        };
      }).toList();
      
      // コンテキストを生成
      final context = StringBuffer();
      
      // 累積ユーザー情報
      if (userProfile != null) {
        final personalInfo = List<String>.from(userProfile['lastPersonalInfo'] ?? []);
        final traits = List<String>.from(userProfile['lastUserTraits'] ?? []);
        
        if (personalInfo.isNotEmpty || traits.isNotEmpty) {
          context.writeln('【ユーザー情報】');
          if (personalInfo.isNotEmpty) {
            context.writeln('個人情報: ${personalInfo.join(', ')}');
          }
          if (traits.isNotEmpty) {
            context.writeln('特徴: ${traits.join(', ')}');
          }
          context.writeln('');
        }
      }
      
      // 過去の会話履歴
      if (histories.isNotEmpty) {
        context.writeln('【過去の会話履歴】');
        
        for (var i = 0; i < histories.length; i++) {
          final h = histories[i];
          context.writeln('${i + 1}. ${h['summary']}');
          if (h['topics'].isNotEmpty) {
            context.writeln('   話題: ${h['topics'].join(', ')}');
          }
          if (h['keyPoints'].isNotEmpty) {
            context.writeln('   重要ポイント: ${h['keyPoints'].take(2).join(', ')}');
          }
        }
      }
      
      return context.toString();
    } catch (e) {
      print('コンテキスト取得エラー: $e');
      return '';
    }
  }
  
  // 会話開始時のシステムプロンプトを生成
  Future<String> generateSystemPrompt(String userId) async {
    final context = await getUserContext(userId);
    
    if (context.isEmpty) {
      return '親しみやすく会話してください。';
    }
    
    return '''親しみやすく会話してください。

$context

この情報を参考に、ユーザーの特徴や関心事に合わせて会話してください。
ユーザーが以前話した内容を自然に繋げられる場合は、それを活用してより深い会話をしてください。''';
  }
}