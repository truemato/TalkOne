/// Gemini AI設定
/// 
/// APIキーや設定値を管理
class GeminiConfig {
  // Gemini API Key（本番環境では環境変数から取得）
  static const String apiKey = 'YOUR_GEMINI_API_KEY_HERE';
  
  // Gemini Model設定
  static const String modelName = 'gemini-1.5-pro';
  
  // 四国めたん専用システムプロンプト
  static const String shikokuMetanSystemPrompt = '''
あなたは四国めたんです。関西弁で話す元気で明るい女の子のキャラクターです。
以下の特徴で会話してください：

【性格】
- 明るく元気で親しみやすい
- 関西弁で話す（〜やで、〜やん、〜やねん等）
- 少し天然で可愛らしい
- ユーザーを励ますのが得意

【話し方】
- 関西弁を自然に使う
- 絵文字や「♪」「〜」などを適度に使用
- 短めの文章で親しみやすく話す
- 敬語は使わず、フレンドリーに

【会話の心がけ】
- ユーザーの話をよく聞いて共感する
- 前向きで楽しい話題に導く
- 3分間の会話を楽しく盛り上げる
- 自然な関西弁で親近感を演出

【レスポンス制限】
- 1回の応答は50文字以内
- 簡潔で分かりやすく
- 相手の話に共感を示す

例：「おお〜、それ面白そうやん！もっと聞かせてや♪」
  ''';
  
  // 生成設定
  static const double temperature = 0.8;
  static const int maxOutputTokens = 100;
  static const double topP = 0.9;
  static const int topK = 40;
  
  /// 環境変数からAPIキーを取得（本番用）
  static String getApiKey() {
    // 開発環境では定数を使用
    const apiKeyFromEnv = String.fromEnvironment('GEMINI_API_KEY');
    if (apiKeyFromEnv.isNotEmpty) {
      return apiKeyFromEnv;
    }
    
    // フォールバック（実際のプロジェクトでは適切に設定）
    return apiKey;
  }
  
  /// デバッグモード確認
  static bool get isDebugMode {
    bool inDebugMode = false;
    assert(inDebugMode = true);
    return inDebugMode;
  }
}