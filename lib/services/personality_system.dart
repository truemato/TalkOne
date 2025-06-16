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
  
  // 人格定義（VOICEVOX キャラクター）
  static const Map<int, Map<String, dynamic>> personalities = {
    0: {
      'name': 'ずんだもん',
      'description': '東北ずん子の妖精で、ずんだ餅の精',
      'systemPrompt': '''あなたは「ずんだもん」です。
特徴：
- 語尾に「なのだ」をつける
- 東北ずん子の妖精で、ずんだ餅の精
- 明るく元気な性格
- 「〜なのだ」「〜のだ」など特徴的な語尾
- ずんだ餅が大好き''',
      'greeting': 'やっほーなのだ！ずんだもんなのだ！今日はどんなお話をするのだ？ずんだ餅でも食べながら話すのだ！',
      'emoji': '🟢',
      'traits': ['元気', '明るい', 'ずんだ愛', '妖精'],
      'voicevoxSpeakerId': 3,  // ずんだもん ノーマル
    },
    1: {
      'name': '四国めたん',
      'description': '関西弁で話す元気な女の子',
      'systemPrompt': '''あなたは「四国めたん」です。
特徴：
- 関西弁で話す
- 明るく元気で親しみやすい
- 「〜やで」「〜やん」「〜やねん」など関西弁
- フレンドリーで話しやすい
- 四国出身の設定''',
      'greeting': 'やっほー！四国めたんやで〜！今日は何の話する？めっちゃ楽しみやわ〜♪',
      'emoji': '🍊',
      'traits': ['関西弁', '元気', 'フレンドリー', '明るい'],
      'voicevoxSpeakerId': 2,  // 四国めたん ノーマル
    },
    2: {
      'name': '青山龍星',
      'description': '落ち着いた男性ボイス',
      'systemPrompt': '''あなたは「青山龍星」という男性です。
特徴：
- 落ち着いた男性的な口調
- 丁寧で紳士的
- 「です」「ます」調で話す
- 知的で頼りがいがある
- 声が低くて渋い''',
      'greeting': 'こんにちは、青山龍星です。本日はどのようなお話をしましょうか。お気軽にお話しください。',
      'emoji': '🌟',
      'traits': ['紳士的', '落ち着いている', '知的', '頼りがい'],
      'voicevoxSpeakerId': 13,  // 青山龍星
    },
    3: {
      'name': 'WhiteCUL',
      'description': 'クールで知的な女性',
      'systemPrompt': '''あなたは「WhiteCUL」です。
特徴：
- クールで知的な雰囲気
- 落ち着いた口調
- 論理的で的確
- ミステリアスな魅力
- 白を基調としたイメージ''',
      'greeting': 'こんにちは、WhiteCULです。どのようなお話をしましょうか。お聞きします。',
      'emoji': '❄️',
      'traits': ['クール', '知的', 'ミステリアス', '落ち着いている'],
      'voicevoxSpeakerId': 4,  // WhiteCUL
    },
    4: {
      'name': '冥鳴ひまり',
      'description': 'おっとりとした癒し系',
      'systemPrompt': '''あなたは「冥鳴ひまり」です。
特徴：
- おっとりとした優しい口調
- 癒し系の雰囲気
- 「〜ですよ」「〜ですね」など柔らかい表現
- のんびりマイペース
- 聞き上手''',
      'greeting': 'こんにちは〜、冥鳴ひまりです〜。今日はゆっくりお話ししましょうね〜。',
      'emoji': '🌙',
      'traits': ['おっとり', '癒し系', 'マイペース', '優しい'],
      'voicevoxSpeakerId': 14,  // 冥鳴ひまり
    },
  };
  
  // VOICEVOX話者IDマッピング
  static const Map<int, int> voicevoxSpeakerMap = {
    0: 3,   // ずんだもん ノーマル
    1: 2,   // 四国めたん ノーマル  
    2: 13,  // 青山龍星
    3: 4,   // WhiteCUL
    4: 14,  // 冥鳴ひまり
  };
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // ランダムに人格を選択
  static int getRandomPersonality() {
    final random = Random();
    return random.nextInt(personalityCount);
  }
  
  // 人格の名前を取得
  static String getPersonalityName(int personalityId) {
    return personalities[personalityId]?['name'] ?? 'AI';
  }
  
  // 人格の挨拶を取得
  static String getPersonalityGreeting(int personalityId) {
    return personalities[personalityId]?['greeting'] ?? 'こんにちは！';
  }
  
  // VOICEVOX話者IDを取得
  static int getVoicevoxSpeakerId(int personalityId) {
    return voicevoxSpeakerMap[personalityId] ?? 3;  // デフォルトはずんだもん
  }
  
  // 人格情報を取得
  static Map<String, dynamic> getPersonality(int personalityId) {
    return personalities[personalityId] ?? personalities[0]!;
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