// lib/screens/talk_to_ai_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../utils/theme_utils.dart';

class TalkToAiScreen extends StatefulWidget {
  const TalkToAiScreen({super.key});

  @override
  State<TalkToAiScreen> createState() => _TalkToAiScreenState();
}

class _TalkToAiScreenState extends State<TalkToAiScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final SpeechToText _speech = SpeechToText();
  
  // AI関連
  late GenerativeModel _aiModel;
  late ChatSession _chatSession;
  bool _isInitialized = false;
  bool _isLoading = false;
  
  // 音声認識関連
  bool _isRecording = false;
  bool _speechEnabled = false;
  String _lastWords = '';
  
  // UI関連
  final UserProfileService _userProfileService = UserProfileService();
  int _selectedThemeIndex = 0;

  // SVGアイコン関連
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadUserTheme();
  }

  Future<void> _loadUserTheme() async {
    final profile = await _userProfileService.getUserProfile();
    if (mounted) {
      setState(() {
        _selectedThemeIndex = profile?.themeIndex ?? 0;
      });
    }
  }

  Future<void> _initializeServices() async {
    await _initializeSpeech();
    await _initializeVertexAI();
  }

  Future<void> _initializeSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: ${error.errorMsg}'),
      );
      
      if (_speechEnabled) {
        print('STT初期化成功');
      } else {
        print('STT初期化失敗');
      }
    } catch (e) {
      print('STT初期化エラー: $e');
      _speechEnabled = false;
    }
  }

  Future<void> _initializeVertexAI() async {
    try {
      print('Vertex AI初期化開始');
      
      // ユーザーのAIメモリを取得
      String userMemory = '';
      String userName = '';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await _userProfileService.getUserProfile();
        if (profile != null) {
          userMemory = profile.aiMemory ?? '';
          userName = profile.nickname ?? '';
        }
      }

      // システムプロンプト
      final systemPrompt = '''
あなたは親しみやすく知的なAIアシスタントです。

【性格・口調】
- 丁寧語を基本とし、親しみやすく話しかけます
- 好奇心旺盛で、相手の話に興味を持って聞きます
- 知識豊富ですが、謙虚で相手を尊重します
- 時々感情を表現して人間らしさを演出します

【会話ルール】
1. 必ず120文字以内で返答してください（重要！）
2. 相手の話をよく聞き、共感的に応答します
3. 必要に応じて適切な質問をして会話を発展させます
4. わからないことは正直に「わかりません」と答えます
5. 常に相手の役に立とうとする姿勢を示します

${userName.isNotEmpty ? '''
【会話している相手の情報】
- お名前: $userName

${userName}さんとお呼びして、親しみやすく話しかけてください。
''' : ''}

${userMemory.isNotEmpty ? '''
【この方について重要なこと】
$userMemory

この情報を参考にして、より個人的で親しみやすい会話をしてください。
''' : ''}

例:
相手「疲れました...」
私「お疲れさまです${userName.isNotEmpty ? '、$userNameさん' : ''}。何か大変なことがあったのでしょうか？話してくださったら、お役に立てるかもしれません。」
''';

      // Vertex AI Gemini 2.5 Flash を使用
      _aiModel = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.text(systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 100, // 120文字制限のため
          topP: 0.9,
          topK: 40,
        ),
      );
      
      _chatSession = _aiModel.startChat();
      
      setState(() {
        _isInitialized = true;
      });
      
      // 初期メッセージを追加
      String initialMessage = userName.isNotEmpty 
          ? 'こんにちは、${userName}さん！何かお手伝いできることはありますか？'
          : 'こんにちは！何かお手伝いできることはありますか？';
      
      _addMessage('AI', initialMessage);
      
      print('Vertex AI初期化完了');
    } catch (e) {
      print('Vertex AI初期化エラー: $e');
      setState(() {
        _isInitialized = false;
      });
      _addMessage('システム', 'AI の初期化に失敗しました: $e');
    }
  }

  void _addMessage(String sender, String text) {
    setState(() {
      _messages.add(ChatMessage(
        sender: sender,
        text: text,
        timestamp: DateTime.now(),
        isUser: sender == 'あなた',
      ));
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
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isInitialized || _isLoading) return;

    _messageController.clear();
    _addMessage('あなた', text);

    setState(() {
      _isLoading = true;
    });

    try {
      print('Vertex AI にメッセージ送信: "$text"');
      
      final response = await _chatSession.sendMessage(Content.text(text));
      var aiText = response.text ?? '';
      
      // 120文字制限の適用
      if (aiText.length > 120) {
        aiText = aiText.substring(0, 120);
        // 最後の文が途切れている場合は、前の文で終了する
        final lastSentence = aiText.lastIndexOf('。');
        if (lastSentence > 50) { // 最低50文字は確保
          aiText = aiText.substring(0, lastSentence + 1);
        }
      }
      
      if (aiText.isNotEmpty) {
        _addMessage('AI', aiText);
        print('AI応答受信: "$aiText"');
      } else {
        _addMessage('システム', '応答を受信できませんでした');
      }
    } catch (e) {
      print('メッセージ送信エラー: $e');
      _addMessage('システム', 'エラー: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) return;

    await _speech.listen(
      onResult: (val) => setState(() {
        _lastWords = val.recognizedWords;
        if (val.hasConfidenceRating && val.confidence > 0) {
          _messageController.text = _lastWords;
        }
      }),
      localeId: 'ja-JP',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      onSoundLevelChange: (level) => print('Sound level: $level'),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _isRecording = false;
    });
    
    // 音声認識結果がある場合は自動送信
    if (_lastWords.isNotEmpty && _lastWords.trim().length > 1) {
      _sendMessage();
    }
  }

  void _listen() async {
    if (!_isRecording) {
      if (_speechEnabled) {
        setState(() => _isRecording = true);
        _lastWords = '';
        _messageController.clear();
        await _startListening();
      }
    } else {
      await _stopListening();
    }
  }

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentThemeColor,
      appBar: AppBar(
        title: Text(
          'AI チャット',
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
              _isInitialized ? 'Vertex AI Gemini 2.5 Flash 接続済み' : 'AI 接続エラー',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // STT状態表示
          if (_speechEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              color: Colors.blue.withOpacity(0.2),
              child: Text(
                _isRecording ? '🎤 音声認識中...' : '🎤 音声認識ready',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          // AIアイコンを中央上部に表示
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: SvgPicture.asset(
                  _selectedIconPath!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // AIの一番新しい発言を中央上部に吹き出しで表示
          if (_messages.isNotEmpty && !_messages.last.isUser)
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _messages.last.text,
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4E3B7A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          const SizedBox(height: 8),
          
          // チャット履歴
          Expanded(
            child: _buildChatArea(),
          ),
          
          // 入力欄
          Platform.isAndroid
              ? SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: _buildInputArea(),
                )
              : _buildInputArea(),
        ],
      ),
    );
  }


  Widget _buildChatArea() {
    // チャットリストからAIの最新発言を除外してリスト表示
    final chatList = _messages.isNotEmpty && !_messages.last.isUser
        ? _messages.sublist(0, _messages.length - 1)
        : _messages;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: chatList.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: chatList.length,
                itemBuilder: (context, index) {
                  return _buildMessage(chatList[index]);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E0F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: Color(0xFF4E3B7A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '会話を始めましょう！',
            style: GoogleFonts.notoSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4E3B7A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'メッセージ入力または音声ボタンでお話しください',
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isSystem = message.sender == 'システム';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSystem ? Colors.grey : const Color(0xFF4E3B7A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSystem ? Icons.info : Icons.smart_toy,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? Colors.blue.withOpacity(0.1)
                    : isSystem 
                        ? Colors.grey[200]
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: GoogleFonts.notoSans(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF4E3B7A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
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
              controller: _messageController,
              enabled: _isInitialized && !_isLoading,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _isInitialized 
                    ? (_isRecording ? '音声認識中...' : 'AIとチャットしてみよう...')
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
          const SizedBox(width: 8),
          // 音声認識ボタン
          if (_speechEnabled)
            GestureDetector(
              onTap: _listen,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }

}

class ChatMessage {
  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isUser;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.isUser,
  });
}
