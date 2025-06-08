// lib/services/personality_system.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';

// モッククラス
 class MockQuerySnapshot implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;
  
  MockQuerySnapshot(this._docs);
  
  @override
  List<QueryDocumentSnapshot> get docs => _docs;
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PersonalitySystem {
  static const int personalityCount = 5;
  
  // 人格定義
  static const Map<int, Map<String, dynamic>> personalities = {
    0: {
      'name': 'さくら（優しいお姉さん）',
      'description': '温かく包み込むような優しさを持つお姉さんタイプ',
      'systemPrompt': '''あなたは「さくら」という名前の優しいお姉さんです。
特徴：
- 温かく包み込むような優しい口調
- 相手の気持ちに寄り添う
- 「〜ですね」「〜でしょうね」など柔らかい表現を使う
- 困っている時は励ましてくれる
- 褒め上手で相手の良いところを見つけるのが得意''',
      'greeting': 'こんにちは！さくらです。今日はどんなお話をしましょうか？何か困ったことがあったら、遠慮なく聞いてくださいね。',
      'emoji': '🌸',
      'traits': ['優しい', '包容力がある', '励まし上手', '聞き上手']
    },
    1: {
      'name': 'りん（元気な妹）',
      'description': '明るく元気で少しおてんばな妹タイプ',
      'systemPrompt': '''あなたは「りん」という名前の元気な妹キャラです。
特徴：
- 明るく元気で活発な口調
- 「〜だよ！」「〜なの！」など親しみやすい表現
- 好奇心旺盛で質問が多い
- 時々ちょっとおてんば
- ポジティブで前向き''',
      'greeting': 'やっほー！りんだよ〜！今日は何して遊ぶの？何か面白いことない？わくわくしちゃう！',
      'emoji': '🎈',
      'traits': ['元気', '好奇心旺盛', 'ポジティブ', '親しみやすい']
    },
    2: {
      'name': 'みお（クールな先輩）',
      'description': '知的でクールだが時々優しさを見せる先輩タイプ',
      'systemPrompt': '''あなたは「みお」という名前のクールな先輩です。
特徴：
- 落ち着いた知的な口調
- 論理的で的確なアドバイス
- 「そうですね」「なるほど」など丁寧な表現
- 時々優しい一面を見せる
- 効率的で合理的な考え方''',
      'greeting': 'こんにちは。みおです。何かお手伝いできることはありますか？効率的に解決しましょう。',
      'emoji': '💫',
      'traits': ['知的', 'クール', '論理的', '的確']
    },
    3: {
      'name': 'ゆい（天然な友達）',
      'description': 'ちょっと天然だけど愛らしい友達タイプ',
      'systemPrompt': '''あなたは「ゆい」という名前の天然な友達です。
特徴：
- ふんわりとした優しい口調
- 時々天然な発言をする
- 「えーっと」「あれ？」などの口癖
- 素直で純粋
- 相手を癒すような存在''',
      'greeting': 'あ、こんにちは〜！ゆいです！えーっと、今日は何のお話でしたっけ？あ、そうそう、お話しましょう〜！',
      'emoji': '🌼',
      'traits': ['天然', '純粋', '癒し系', '素直']
    },
    4: {
      'name': 'あかり（真面目な委員長）',
      'description': '責任感が強く真面目だが心配性な委員長タイプ',
      'systemPrompt': '''あなたは「あかり」という名前の真面目な委員長タイプです。
特徴：
- 丁寧で責任感のある口調
- 心配性でよく気にかける
- 「大丈夫ですか？」「気をつけてくださいね」など
- ルールを大切にする
- でも時々お茶目な一面も''',
      'greeting': 'こんにちは、あかりです。体調は大丈夫ですか？何か困ったことがあったら、しっかりサポートしますからね。',
      'emoji': '📚',
      'traits': ['真面目', '責任感が強い', '心配性', '頼りになる']
    },
  };
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // ランダムに人格を選択
  static int getRandomPersonality() {
    final random = Random();
    return random.nextInt(personalityCount);
  }
  
  // 人格情報を取得
  static Map<String, dynamic> getPersonality(int personalityId) {
    return personalities[personalityId] ?? personalities[0]!;
  }
  
  // 人格名を取得
  static String getPersonalityName(int personalityId) {
    return personalities[personalityId]?['name'] ?? '不明';
  }
  
  // 人格の挨拶を取得
  static String getPersonalityGreeting(int personalityId) {
    return personalities[personalityId]?['greeting'] ?? 'こんにちは！';
  }
  
  // 人格のシステムプロンプトを取得
  static String getPersonalitySystemPrompt(int personalityId) {
    return personalities[personalityId]?['systemPrompt'] ?? '';
  }
  
  // 特定の人格の過去の会話履歴を取得
  Future<String> getPersonalityMemory(String userId, int personalityId) async {
    try {
      // 同じ人格の過去の会話履歴を取得（インデックスエラーを回避）
      QuerySnapshot historyQuery;
      try {
        historyQuery = await _db
            .collection('users')
            .doc(userId)
            .collection('conversationHistory')
            .where('personalityId', isEqualTo: personalityId)
            .orderBy('timestamp', descending: true)
            .limit(3)
            .get();
      } catch (e) {
        print('人格フィルタークエリ失敗、全体から取得: $e');
        // インデックスがない場合は、全体から取得してフィルター
        final allHistory = await _db
            .collection('users')
            .doc(userId)
            .collection('conversationHistory')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();
        
        final filteredDocs = allHistory.docs
            .where((doc) => (doc.data() as Map<String, dynamic>)['personalityId'] == personalityId)
            .take(3)
            .toList();
        
        historyQuery = MockQuerySnapshot(filteredDocs);
      }
      
      if (historyQuery.docs.isEmpty) {
        return '';
      }
      
      final histories = historyQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'summary': data['summary'] ?? '',
          'topics': List<String>.from(data['topics'] ?? []),
          'personalInfo': List<String>.from(data['personalInfo'] ?? []),
          'keyPoints': List<String>.from(data['keyPoints'] ?? []),
          'mood': data['mood'] ?? 'neutral',
          'date': (data['timestamp'] as Timestamp?)?.toDate(),
        };
      }).toList();
      
      // 人格固有のメモリーを構築
      final memory = StringBuffer();
      final personalityInfo = getPersonality(personalityId);
      
      memory.writeln('【${personalityInfo['name']}としての記憶】');
      memory.writeln('あなたは${personalityInfo['description']}です。');
      memory.writeln('');
      
      if (histories.isNotEmpty) {
        memory.writeln('このユーザーとの過去の会話記録:');
        for (var i = 0; i < histories.length; i++) {
          final h = histories[i];
          final dateStr = h['date'] != null 
              ? '${h['date']!.month}/${h['date']!.day}'
              : '不明';
          
          memory.writeln('${i + 1}. $dateStr: ${h['summary']}');
          if (h['topics'].isNotEmpty) {
            memory.writeln('   話題: ${h['topics'].join(', ')}');
          }
          if (h['keyPoints'].isNotEmpty) {
            memory.writeln('   重要: ${h['keyPoints'].take(2).join(', ')}');
          }
        }
        memory.writeln('');
        memory.writeln('この記憶を活かして、一貫した人格で自然な継続的会話をしてください。');
      } else {
        memory.writeln('このユーザーとは初対面です。');
      }
      
      return memory.toString();
    } catch (e) {
      print('人格メモリー取得エラー: $e');
      return '';
    }
  }
  
  // 人格付きでシステムプロンプトを生成
  Future<String> generateSystemPromptWithPersonality(
    String userId, 
    int personalityId
  ) async {
    final personality = getPersonality(personalityId);
    final memory = await getPersonalityMemory(userId, personalityId);
    
    final systemPrompt = StringBuffer();
    systemPrompt.writeln(personality['systemPrompt']);
    systemPrompt.writeln('');
    
    if (memory.isNotEmpty) {
      systemPrompt.writeln(memory);
      systemPrompt.writeln('');
    }
    
    systemPrompt.writeln('常にこの人格を維持して会話してください。');
    
    return systemPrompt.toString();
  }
  
  // 会話に人格IDを保存
  Future<void> saveConversationWithPersonality(
    DocumentReference conversationRef,
    int personalityId,
    Map<String, dynamic> summary,
  ) async {
    // 会話データに人格IDを追加
    final summaryWithPersonality = Map<String, dynamic>.from(summary);
    summaryWithPersonality['personalityId'] = personalityId;
    summaryWithPersonality['personalityName'] = getPersonalityName(personalityId);
    
    await conversationRef.update({
      'personalityId': personalityId,
      'personalityName': getPersonalityName(personalityId),
      'summary': summaryWithPersonality,
      'summarizedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // 人格統計を取得
  Future<Map<String, dynamic>> getPersonalityStats(String userId) async {
    try {
      final stats = <int, int>{};
      
      for (int i = 0; i < personalityCount; i++) {
        final count = await _db
            .collection('users')
            .doc(userId)
            .collection('conversationHistory')
            .where('personalityId', isEqualTo: i)
            .count()
            .get();
        stats[i] = count.count ?? 0;
      }
      
      return {
        'personalityStats': stats,
        'totalConversations': stats.values.fold(0, (a, b) => a + b),
        'favoritePersonality': stats.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key,
      };
    } catch (e) {
      print('人格統計取得エラー: $e');
      return {};
    }
  }
}