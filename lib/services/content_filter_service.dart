import 'package:cloud_firestore/cloud_firestore.dart';

class ContentFilterService {
  static final ContentFilterService _instance = ContentFilterService._internal();
  factory ContentFilterService() => _instance;
  ContentFilterService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 日本語と英語の不適切な単語リスト（基本的なもの）
  final List<String> _profanityList = [
    // 日本語の不適切な表現
    '死ね', '殺す', 'バカ', 'アホ', 'クソ', 'ブス', 'デブ', 
    'キモい', 'ウザい', 'ゴミ', 'クズ', '消えろ', 'きもい',
    'うざい', 'しね', 'ころす', 'ばか', 'あほ', 'くそ',
    'うんち', 'うんこ', 'ウンチ', 'ウンコ', 'うんk',
    '池沼', 'いけぬま', 'ガイジ', 'がいじ', 'キチガイ', 'きちがい',
    '知恵遅れ', 'ちえおくれ', '障害者', 'しょうがいしゃ', 'カタワ', 'かたわ',
    '土人', 'どじん', 'チョン', 'ちょん', 'シナ', 'しな',
    '朝鮮人', 'ちょうせんじん', '韓国人', '中国人', '外人', 'がいじん',
    'ニガー', 'にがー', 'イエロー', 'いえろー', 
    '部落', 'ぶらく', '同和', 'どうわ', 'エタ', 'えた', 'ヒニン', 'ひにん',
    '在日', 'ざいにち', 'Bチク', 'bちく', '朝鮮', 'ちょうせん',
    'メクラ', 'めくら', 'ツンボ', 'つんぼ', 'オシ', 'おし',
    'ビッチ', 'びっち', 'ヤリマン', 'やりまん', '売春婦', 'ばいしゅんふ',
    '手押し', 'ておし', 'テオシ',
    
    // 英語の不適切な表現
    'fuck', 'shit', 'damn', 'hell', 'bitch', 'ass', 'dick',
    'pussy', 'cock', 'bastard', 'idiot', 'stupid', 'moron',
    'cunt', 'racist', 'rasist', 'nazi', 'nachi',
    'faggot', 'retard', 'dumb', 'rape', 'raping', 'rapist',
    'nigger', 'nigga', 'chink', 'gook', 'jap', 'kike',
    'spic', 'wetback', 'towelhead', 'camel jockey', 'sand nigger',
    'white trash', 'cracker', 'honky', 'yellow', 'oriental',
    'midget', 'dwarf', 'cripple', 'gimp', 'lunatic', 'psycho',
    'whore', 'slut', 'prostitute', 'hooker', 'escort', 'thot',
    'blind', 'deaf', 'mute', 'spastic', 'mongoloid', 'imbecile',
    'savage', 'barbarian', 'primitive', 'tribal', 'heathen',
    'communist', 'commie', 'fascist', 'nazi', 'hitler', 'stalin',
    'isis', 'jihad', 'infidel', 'kafir', 'goyim',
    
    // 性的な内容
    'セックス', 'sex', 'porn', 'エロ', 'えろ', 'ポルノ',
    '野獣', '淫夢', '4545', '1919', '女装', 'アナル', 'あなる',
    'anal', '尻穴', 'けつあな', 'ケツアナ',
    'まんこ', 'マンコ', 'ちんぽ', 'チンポ', 'ちんかす', 'チンカス',
    '恥丘', '恥垢', '性器', 'マラ', 'まら', '巨乳', 'フェラ', 'ふぇら',
    'うんぽこ', 'ウンポコ', 'penis', 'vagina', 'fellatio',
    
    // 暴力的な内容
    '暴力', '虐待', '自殺', 'violence', 'abuse', 'suicide',
    '殺害', '殺人', 'さつじん', '爆弾', 'ばくだん', 'テロ', 'てろ',
    '麻薬', 'まやく', '覚醒剤', 'かくせいざい', '大麻', 'たいま',
    'ヘロイン', 'へろいん', 'コカイン', 'こかいん', '薬物', 'やくぶつ',
    'murder', 'kill', 'bomb', 'terrorist', 'terrorism', 'torture',
    'kidnap', 'assault', 'death threat', 'shooting', 'stabbing',
    'drugs', 'cocaine', 'heroin', 'meth', 'marijuana', 'weed',
    'crack', 'ecstasy', 'lsd', 'mdma', 'dealer', 'trafficking',
    
    // 差別的な内容（LGBT差別用語）
    'ゲイ', 'レズ', 'ホモ', 'オカマ', 'gay', 'lesbian', 'homo',
    'GAY', 'おかま', 'おなべ', 'オナベ', 'ニューハーフ', 
    'トランス', 'レズビアン', 'faggot', 'fag', 'dyke',
    'tranny', 'shemale', 'ネカマ', 'オトコノコ', 'おとこのこ',
    'ホモ', 'HOMO', 'homo',
    
    // ハラスメント
    'セクハラ', 'パワハラ', 'いじめ', 'harassment', 'bully',
    
    // 外部サービス誘導防止（個人情報保護・プライバシー保護）
    'line', 'LINE', 'ライン', 'らいん', 
    'twitter', 'TWITTER', 'ツイッター', 'つい', 'ツイ',
    'facebook', 'FACEBOOK', 'フェイスブック', 'ふぇいすぶっく', 'fb', 'FB',
    'instagram', 'INSTAGRAM', 'インスタ', 'いんすた', 'インスタグラム',
    'tiktok', 'TIKTOK', 'ティックトック', 'てぃっくとっく',
    'discord', 'DISCORD', 'ディスコード', 'でぃすこーど',
    'skype', 'SKYPE', 'スカイプ', 'すかいぷ',
    'telegram', 'TELEGRAM', 'テレグラム', 'てれぐらむ',
    'whatsapp', 'WHATSAPP', 'ワッツアップ', 'わっつあっぷ',
    'snapchat', 'SNAPCHAT', 'スナップチャット', 'すなっぷちゃっと',
    'youtube', 'YOUTUBE', 'ユーチューブ', 'ゆーちゅーぶ', 'ようつべ',
    'gmail', 'GMAIL', 'ジーメール', 'じーめーる',
    'yahoo', 'YAHOO', 'ヤフー', 'やふー',
    'zoom', 'ZOOM', 'ズーム', 'ずーむ',
    'teams', 'TEAMS', 'チームズ', 'ちーむず',
    'slack', 'SLACK', 'スラック', 'すらっく',
  ];

  // メッセージレート制限（1分間に10メッセージまで）
  final Map<String, List<DateTime>> _messageTimestamps = {};
  final int _maxMessagesPerMinute = 10;

  /// テキストをフィルタリング
  String filterText(String text) {
    if (text.isEmpty) return text;
    
    String filtered = text;
    
    // 不適切な単語を***に置換
    for (String word in _profanityList) {
      // 大文字小文字を区別せずに置換
      RegExp regex = RegExp(word, caseSensitive: false);
      filtered = filtered.replaceAll(regex, '*' * word.length);
    }
    
    // 過度な記号の繰り返しを制限（3回まで）
    filtered = filtered.replaceAllMapped(
      RegExp(r'([!?！？。、,.])\1{3,}'),
      (match) => match.group(1)! * 3,
    );
    
    // 過度な改行を制限（2回まで）
    filtered = filtered.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return filtered;
  }

  /// テキストに不適切な内容が含まれているかチェック
  bool containsInappropriateContent(String text) {
    if (text.isEmpty) return false;
    
    String lowerText = text.toLowerCase();
    
    for (String word in _profanityList) {
      if (lowerText.contains(word.toLowerCase())) {
        return true;
      }
    }
    
    // URLやメールアドレス、@マークの検出（個人情報保護・外部誘導防止）
    RegExp urlRegex = RegExp(
      r'https?://[^\s]+|www\.[^\s]+|\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b|@',
      caseSensitive: false,
    );
    if (urlRegex.hasMatch(text)) {
      return true;
    }
    
    // 電話番号の検出（個人情報保護）
    RegExp phoneRegex = RegExp(
      r'(\+?\d{1,4}[\s-]?)?\(?\d{1,4}\)?[\s-]?\d{1,4}[\s-]?\d{1,4}',
    );
    if (phoneRegex.hasMatch(text)) {
      return true;
    }
    
    return false;
  }

  /// メッセージレート制限チェック
  bool isRateLimited(String userId) {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    
    // ユーザーのタイムスタンプリストを取得または作成
    if (!_messageTimestamps.containsKey(userId)) {
      _messageTimestamps[userId] = [];
    }
    
    // 1分以内のメッセージをフィルタリング
    _messageTimestamps[userId] = _messageTimestamps[userId]!
        .where((timestamp) => timestamp.isAfter(oneMinuteAgo))
        .toList();
    
    // レート制限チェック
    if (_messageTimestamps[userId]!.length >= _maxMessagesPerMinute) {
      return true;
    }
    
    // 新しいタイムスタンプを追加
    _messageTimestamps[userId]!.add(now);
    return false;
  }

  /// プロフィール内容をフィルタリング
  Map<String, dynamic> filterProfile(Map<String, dynamic> profile) {
    Map<String, dynamic> filtered = Map.from(profile);
    
    // ニックネームをフィルタリング
    if (filtered['nickname'] != null) {
      filtered['nickname'] = filterText(filtered['nickname']);
      
      // 不適切な内容が含まれている場合はデフォルト値に
      if (containsInappropriateContent(filtered['nickname'])) {
        filtered['nickname'] = 'ユーザー';
      }
    }
    
    // コメントをフィルタリング
    if (filtered['comment'] != null) {
      filtered['comment'] = filterText(filtered['comment']);
      
      // 不適切な内容が含まれている場合は空に
      if (containsInappropriateContent(filtered['comment'])) {
        filtered['comment'] = '';
      }
    }
    
    // AIメモリーをフィルタリング
    if (filtered['aiMemory'] != null) {
      filtered['aiMemory'] = filterText(filtered['aiMemory']);
      
      // 不適切な内容が含まれている場合は空に
      if (containsInappropriateContent(filtered['aiMemory'])) {
        filtered['aiMemory'] = '';
      }
    }
    
    return filtered;
  }

  /// 不適切なコンテンツを報告
  Future<void> reportInappropriateContent({
    required String reporterId,
    required String reportedUserId,
    required String contentType,
    required String content,
    String? reason,
  }) async {
    try {
      await _firestore.collection('content_reports').add({
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'contentType': contentType,
        'content': content,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'reviewedAt': null,
        'reviewedBy': null,
        'action': null,
      });
    } catch (e) {
      print('Error reporting content: $e');
    }
  }

  /// フィルタリング辞書を更新（管理者用）
  Future<void> updateProfanityList(List<String> newWords) async {
    try {
      // Firestoreから最新の禁止ワードリストを取得
      final doc = await _firestore.collection('settings').doc('profanity_filter').get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['words'] != null) {
          _profanityList.clear();
          _profanityList.addAll(List<String>.from(data['words']));
        }
      }
      
      // 新しい単語を追加
      if (newWords.isNotEmpty) {
        _profanityList.addAll(newWords);
        
        // Firestoreに保存
        await _firestore.collection('settings').doc('profanity_filter').set({
          'words': _profanityList,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating profanity list: $e');
    }
  }

  /// コンテンツの安全性スコアを計算（0-100、100が最も安全）
  int calculateSafetyScore(String text) {
    if (text.isEmpty) return 100;
    
    int score = 100;
    
    // 不適切な単語の数に応じてスコアを減少
    String lowerText = text.toLowerCase();
    for (String word in _profanityList) {
      if (lowerText.contains(word.toLowerCase())) {
        score -= 20;
      }
    }
    
    // URLやメールアドレスが含まれている場合
    RegExp urlRegex = RegExp(
      r'https?://[^\s]+|www\.[^\s]+|\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
      caseSensitive: false,
    );
    if (urlRegex.hasMatch(text)) {
      score -= 30;
    }
    
    // 電話番号が含まれている場合
    RegExp phoneRegex = RegExp(
      r'(\+?\d{1,4}[\s-]?)?\(?\d{1,4}\)?[\s-]?\d{1,4}[\s-]?\d{1,4}',
    );
    if (phoneRegex.hasMatch(text)) {
      score -= 30;
    }
    
    // 過度な大文字の使用
    int upperCount = text.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (text.length > 10 && upperCount / text.length > 0.5) {
      score -= 10;
    }
    
    // 過度な記号の使用
    int symbolCount = text.replaceAll(RegExp(r'[a-zA-Z0-9\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF\s]'), '').length;
    if (text.length > 10 && symbolCount / text.length > 0.3) {
      score -= 10;
    }
    
    return score.clamp(0, 100);
  }
}