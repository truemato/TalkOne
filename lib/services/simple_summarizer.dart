// lib/services/simple_summarizer.dart
import 'package:firebase_ai/firebase_ai.dart';

class SimpleSummarizer {
  // シンプルなテキスト要約を生成（JSON不要）
  static Future<Map<String, dynamic>> generateSimpleSummary(
    List<({String from, String text})> messages,
    Duration conversationDuration,
  ) async {
    try {
      // 基本情報を収集
      final userMessages = messages
          .where((m) => m.from == 'me' || m.from == 'user')
          .toList();
      final aiMessages = messages
          .where((m) => m.from == 'ai')
          .toList();
      
      if (messages.isEmpty) {
        return {
          'summary': '会話がありませんでした',
          'topics': [],
          'mood': 'neutral',
          'userMessageCount': 0,
        };
      }
      
      // ユーザーメッセージから詳細情報を抽出
      final topics = <String>[];
      final keyPoints = <String>[];
      final personalInfo = <String>[];
      
      // ユーザーのメッセージのみを分析
      final userTexts = userMessages.map((m) => m.text).toList();
      final allUserText = userTexts.join(' ');
      
      // 個人情報の抽出パターン
      final patterns = {
        '名前': RegExp(r'私は(.{1,10})(です|と申します|といいます)'),
        '年齢': RegExp(r'(\d{1,3})歳'),
        '職業': RegExp(r'(会社員|学生|主婦|エンジニア|医者|教師|自営業)'),
        '場所': RegExp(r'(東京|大阪|名古屋|福岡|北海道|[^\s]{1,5}(県|市|区))'),
        '趣味': RegExp(r'趣味は(.{1,20})(です|だ|で)'),
      };
      
      // パターンマッチングで情報抽出
      patterns.forEach((key, pattern) {
        final match = pattern.firstMatch(allUserText);
        if (match != null) {
          final info = match.group(0) ?? '';
          personalInfo.add('$key: $info');
        }
      });
      
      // 詳細なトピック抽出
      final topicKeywords = {
        '天気・気候': ['天気', '気温', '雨', '晴れ', '暑い', '寒い', '台風'],
        '食事・グルメ': ['食べ', '料理', '美味しい', 'レストラン', '朝食', '昼食', '夕食'],
        '仕事・キャリア': ['仕事', '会社', '職場', '転職', '給料', 'プロジェクト'],
        '健康・体調': ['体調', '病気', '健康', '運動', '睡眠', '疲れ'],
        '趣味・娯楽': ['趣味', '映画', '音楽', 'ゲーム', '読書', 'スポーツ'],
        '家族・人間関係': ['家族', '友達', '恋人', '結婚', '子供', '両親'],
        '学習・教育': ['勉強', '学校', '大学', '資格', '英語', 'プログラミング'],
        '買い物・消費': ['買い物', '購入', '値段', '安い', '高い', 'セール'],
      };
      
      topicKeywords.forEach((topic, keywords) {
        for (final keyword in keywords) {
          if (allUserText.contains(keyword)) {
            if (!topics.contains(topic)) {
              topics.add(topic);
            }
            break;
          }
        }
      });
      
      // 具体的な発言を抽出（重要そうなもの）
      for (final text in userTexts) {
        if (text.length > 20 && text.length < 100) {
          // 質問文
          if (text.contains('？') || text.contains('?')) {
            keyPoints.add('質問: $text');
          }
          // 意見・感想
          else if (text.contains('思う') || text.contains('感じ')) {
            keyPoints.add('意見: $text');
          }
          // 希望・要望
          else if (text.contains('したい') || text.contains('ほしい')) {
            keyPoints.add('希望: $text');
          }
        }
      }
      
      if (topics.isEmpty) topics.add('一般的な会話');
      if (keyPoints.length > 5) {
        keyPoints.length = 5; // 最大5個まで
      }
      
      // ムード判定（シンプル版）
      String mood = 'neutral';
      final positiveWords = ['ありがとう', '嬉しい', '楽しい', '素敵', '良い'];
      final negativeWords = ['すみません', '困った', '難しい', '問題', '心配'];
      
      int positiveCount = 0;
      int negativeCount = 0;
      
      for (final word in positiveWords) {
        if (allUserText.contains(word)) positiveCount++;
      }
      for (final word in negativeWords) {
        if (allUserText.contains(word)) negativeCount++;
      }
      
      if (positiveCount > negativeCount) mood = 'positive';
      if (negativeCount > positiveCount) mood = 'negative';
      
      // Geminiを使った簡単な要約（フォールバック付き）
      String summary = '';
      try {
        final model = FirebaseAI.googleAI().generativeModel(
          model: 'gemini-1.5-flash',
        );
        
        final conversation = messages
            .take(10) // 最初の10メッセージのみ
            .map((m) => '${m.from == "me" ? "ユーザー" : "AI"}: ${m.text}')
            .join('\n');
        
        final response = await model.generateContent([
          Content.text('以下の会話を1文で要約してください（50文字以内）:\n\n$conversation')
        ]);
        
        summary = response.text ?? '';
        // 長すぎる場合はカット
        if (summary.length > 100) {
          summary = '${summary.substring(0, 97)}...';
        }
      } catch (e) {
        print('Gemini要約エラー: $e');
      }
      
      // Geminiが失敗した場合のフォールバック
      if (summary.isEmpty) {
        summary = '${userMessages.length}回の発言がある${conversationDuration.inMinutes}分間の会話';
      }
      
      return {
        'summary': summary,
        'topics': topics,
        'mood': mood,
        'userMessageCount': userMessages.length,
        'aiMessageCount': aiMessages.length,
        'duration': '${conversationDuration.inMinutes}分${conversationDuration.inSeconds % 60}秒',
        'keyPoints': keyPoints,
        'personalInfo': personalInfo,
        'userTraits': _analyzeUserTraits(userMessages),
      };
    } catch (e) {
      print('SimpleSummarizer エラー: $e');
      return {
        'summary': '要約エラー',
        'topics': ['エラー'],
        'mood': 'neutral',
        'userMessageCount': 0,
        'error': e.toString(),
      };
    }
  }
  
  // ユーザーの特徴を分析
  static List<String> _analyzeUserTraits(List<({String from, String text})> userMessages) {
    final traits = <String>[];
    final allText = userMessages.map((m) => m.text).join(' ');
    
    // 話し方の特徴
    if (allText.contains('です') || allText.contains('ます')) {
      traits.add('丁寧な話し方');
    }
    if (allText.contains('！') || allText.contains('!')) {
      traits.add('感情表現が豊か');
    }
    if (RegExp(r'[？?]').allMatches(allText).length > 3) {
      traits.add('質問が多い');
    }
    if (allText.contains('ありがとう') || allText.contains('すみません')) {
      traits.add('礼儀正しい');
    }
    
    // メッセージの長さ（ゼロ除算エラー対策）
    if (userMessages.isNotEmpty) {
      final avgLength = userMessages.fold(0, (sum, m) => sum + m.text.length) ~/ userMessages.length;
      if (avgLength > 50) {
        traits.add('詳細に説明する傾向');
      } else if (avgLength < 20) {
        traits.add('簡潔な返答');
      }
    }
    
    return traits;
  }
}