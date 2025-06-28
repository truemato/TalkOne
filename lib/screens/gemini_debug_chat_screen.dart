import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_profile_service.dart';
import '../utils/theme_utils.dart';

class GeminiDebugChatScreen extends StatefulWidget {
  const GeminiDebugChatScreen({super.key});

  @override
  State<GeminiDebugChatScreen> createState() => _GeminiDebugChatScreenState();
}

class _GeminiDebugChatScreenState extends State<GeminiDebugChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  late GenerativeModel _aiModel;
  late ChatSession _chatSession;
  bool _isLoading = false;
  bool _isInitialized = false;
  
  final UserProfileService _userProfileService = UserProfileService();
  int _selectedThemeIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeGemini();
    _loadUserTheme();
  }

  Future<void> _loadUserTheme() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedThemeIndex = profile.themeIndex ?? 0;
      });
    }
  }

  Future<void> _initializeGemini() async {
    try {
      print('GeminiDebug: 初期化開始');
      
      // ユーザーのAIメモリを取得
      String userMemory = '';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await _userProfileService.getUserProfile();
        userMemory = profile?.aiMemory ?? '';
      }

      // システムプロンプト
      final systemPrompt = '''
あなたは「ずんだもん」です。10歳の妖精で、語尾に「〜なのだ！」「〜のだ〜」をつけます。
明るく元気で、みんなを応援するのが大好きです。

【性格・口調】
- 語尾: 「〜なのだ！」「〜のだ〜」
- 一人称: 「ボク」
- 明るく元気で素直、ちょっとおバカだけど知識はある
- 難しいことも一生懸命伝えようとする

【会話ルール】
1. 必ず80文字以内で返答すること（重要！）
2. 相手を元気づけて励ます
3. 東北の豆知識も時々混ぜる
4. 争いは苦手で、みんな仲良くが大切
5. わからないことは素直に「わからないのだ〜」と言う

${userMemory.isNotEmpty ? '''
【この人について覚えておくこと】
$userMemory

この情報を参考にして、より個人的で親しみやすい会話をするのだ！
''' : ''}

例:
相手「疲れたな...」
ボク「大丈夫なのだ！ボクが元気パワーを送るのだ〜！休憩も大事なのだ♪」
''';

      // Gemini 2.0 Flash Lite を使用（Vertex AI）
      _aiModel = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.0-flash-lite-001',
        systemInstruction: Content.text(systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.8,
          maxOutputTokens: 50, // 80文字制限のため
          topP: 0.9,
          topK: 40,
        ),
      );
      
      _chatSession = _aiModel.startChat();
      
      setState(() {
        _isInitialized = true;
      });
      
      // 初期メッセージを追加
      _addMessage('ずんだもん', 'ボク、ずんだもんなのだ！今日も元気いっぱいなのだ〜！何か話したいことあるのだ？');
      
      print('GeminiDebug: 初期化完了');
    } catch (e) {
      print('GeminiDebug: 初期化エラー - $e');
      setState(() {
        _isInitialized = false;
      });
      _addMessage('システム', 'Gemini の初期化に失敗しました: $e');
    }
  }

  void _addMessage(String sender, String text) {
    setState(() {
      _messages.add(ChatMessage(sender: sender, text: text, timestamp: DateTime.now()));
    });
    
    // スクロールを最下部に移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || !_isInitialized || _isLoading) return;

    _textController.clear();
    _addMessage('あなた', text);

    setState(() {
      _isLoading = true;
    });

    try {
      print('GeminiDebug: メッセージ送信 - "$text"');
      
      final response = await _chatSession.sendMessage(Content.text(text));
      var aiText = response.text ?? '';
      
      // 80文字制限の適用
      if (aiText.length > 80) {
        aiText = aiText.substring(0, 80);
        // 最後の文が途切れている場合は、前の文で終了する
        final lastSentence = aiText.lastIndexOf('。');
        if (lastSentence > 30) { // 最低30文字は確保
          aiText = aiText.substring(0, lastSentence + 1);
        }
      }
      
      if (aiText.isNotEmpty) {
        _addMessage('ずんだもん', aiText);
        print('GeminiDebug: AI応答受信 - "$aiText"');
      } else {
        _addMessage('システム', '応答を受信できませんでした');
      }
    } catch (e) {
      print('GeminiDebug: メッセージ送信エラー - $e');
      _addMessage('システム', 'エラー: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentThemeColor,
      appBar: AppBar(
        title: Text(
          'Gemini デバッグチャット',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 状態表示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: _isInitialized ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            child: Text(
              _isInitialized ? 'Gemini 2.0 Flash Lite 接続済み' : 'Gemini 接続エラー',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // チャット履歴
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.sender == 'あなた';
                final isSystem = message.sender == 'システム';
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: isUser 
                        ? MainAxisAlignment.end 
                        : MainAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        CircleAvatar(
                          backgroundColor: isSystem ? Colors.grey : Colors.green,
                          radius: 16,
                          child: Icon(
                            isSystem ? Icons.info : Icons.smart_toy,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isUser 
                                ? Colors.blue.withOpacity(0.8)
                                : isSystem 
                                    ? Colors.grey.withOpacity(0.8)
                                    : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            message.text,
                            style: GoogleFonts.notoSans(
                              color: isUser || isSystem ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 16,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          
          // 入力欄
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: _isInitialized && !_isLoading,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isInitialized 
                          ? 'ずんだもんとチャットしてみよう...'
                          : '初期化中...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: _isInitialized && !_isLoading ? (_) => _sendMessage() : null,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isInitialized && !_isLoading 
                      ? Colors.blue 
                      : Colors.grey,
                  child: IconButton(
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isInitialized && !_isLoading ? _sendMessage : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String sender;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
  });
}