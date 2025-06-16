import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/shikoku_metan_chat_service.dart';
import '../services/conversation_data_service.dart';

/// 四国めたん専用リアルタイム音声チャット画面
/// 
/// STT → Gemini → VOICEVOX四国めたんの完全音声会話
class ShikokuMetanChatScreen extends StatefulWidget {
  const ShikokuMetanChatScreen({Key? key}) : super(key: key);

  @override
  State<ShikokuMetanChatScreen> createState() => _ShikokuMetanChatScreenState();
}

class _ShikokuMetanChatScreenState extends State<ShikokuMetanChatScreen>
    with TickerProviderStateMixin {
  late ShikokuMetanChatService _chatService;
  late ConversationDataService _conversationService;
  
  String _sessionId = '';
  String _userId = '';
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isProcessing = false;
  
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  // アニメーション
  late AnimationController _waveAnimationController;
  late AnimationController _metanAnimationController;
  late Animation<double> _waveAnimation;
  late Animation<double> _metanScaleAnimation;
  
  // UI状態
  String _statusText = '初期化中...';
  Color _statusColor = Colors.grey;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChat();
  }
  
  void _initializeAnimations() {
    _waveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _metanAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _metanScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _metanAnimationController,
      curve: Curves.elasticOut,
    ));
  }
  
  Future<void> _initializeChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _updateStatus('ユーザー認証が必要です', Colors.red);
        return;
      }
      
      _userId = user.uid;
      _chatService = ShikokuMetanChatService();
      _conversationService = ConversationDataService();
      
      // セッション開始
      _sessionId = await _conversationService.startConversationSession(
        partnerId: 'ai_shikoku_metan',
        type: ConversationType.ai,
        isAIPartner: true,
      );
      
      // チャットサービス初期化
      final success = await _chatService.initialize(
        sessionId: _sessionId,
        userId: _userId,
      );
      
      if (success) {
        _setupStreamListeners();
        await _chatService.startGreeting();
        _updateStatus('四国めたんと話せるで〜♪', Colors.green);
        setState(() => _isInitialized = true);
      } else {
        _updateStatus('初期化に失敗しました', Colors.red);
      }
      
    } catch (e) {
      print('チャット初期化エラー: $e');
      _updateStatus('初期化エラー: $e', Colors.red);
    }
  }
  
  void _setupStreamListeners() {
    // ユーザーテキストストリーム
    _chatService.userTextStream.listen((userText) {
      _addMessage(ChatMessage(
        text: userText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    
    // AI応答ストリーム
    _chatService.aiResponseStream.listen((aiResponse) {
      _addMessage(ChatMessage(
        text: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _triggerMetanAnimation();
    });
    
    // 音声認識状態ストリーム
    _chatService.listeningStateStream.listen((isListening) {
      setState(() => _isListening = isListening);
      if (isListening) {
        _waveAnimationController.repeat();
        _updateStatus('聞いてるで〜', Colors.blue);
      } else {
        _waveAnimationController.stop();
      }
    });
    
    // 処理状態ストリーム
    _chatService.processingStateStream.listen((isProcessing) {
      setState(() => _isProcessing = isProcessing);
      if (isProcessing) {
        _updateStatus('考え中やで〜', Colors.orange);
      } else if (_isInitialized) {
        _updateStatus('話しかけてや♪', Colors.green);
      }
    });
  }
  
  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }
  
  void _scrollToBottom() {
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
  
  void _triggerMetanAnimation() {
    _metanAnimationController.forward().then((_) {
      _metanAnimationController.reverse();
    });
  }
  
  void _updateStatus(String text, Color color) {
    setState(() {
      _statusText = text;
      _statusColor = color;
    });
  }
  
  Future<void> _startListening() async {
    if (!_isInitialized || _isListening || _isProcessing) return;
    
    await _chatService.startListening();
  }
  
  Future<void> _stopListening() async {
    if (!_isListening) return;
    
    await _chatService.stopListening();
  }
  
  Future<void> _endChat() async {
    try {
      await _chatService.dispose();
      
      await _conversationService.endConversationSession(
        sessionId: _sessionId,
        actualDurationSeconds: _calculateSessionDuration(),
        endReason: ConversationEndReason.userLeft,
      );
      
      // ホーム画面まで戻る
      Navigator.of(context).popUntil((route) => route.isFirst);
      
    } catch (e) {
      print('チャット終了エラー: $e');
    }
  }
  
  int _calculateSessionDuration() {
    // セッション開始時刻からの経過時間を計算
    return DateTime.now().difference(DateTime.now()).inSeconds;
  }
  
  @override
  void dispose() {
    _waveAnimationController.dispose();
    _metanAnimationController.dispose();
    _scrollController.dispose();
    _chatService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          '四国めたんとおしゃべり',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _endChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // 四国めたんアバター部分
          _buildMetanAvatar(),
          
          // ステータス表示
          _buildStatusBar(),
          
          // 会話履歴
          Expanded(
            child: _buildChatHistory(),
          ),
          
          // 音声入力ボタン
          _buildVoiceInputButton(),
        ],
      ),
    );
  }
  
  Widget _buildMetanAvatar() {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A90E2), Color(0xFF7FB3D5)],
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _metanScaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _metanScaleAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.face,
                  size: 80,
                  color: Color(0xFF4A90E2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: _statusColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.mic_off,
            color: _statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _statusText,
            style: TextStyle(
              color: _statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          if (_isProcessing) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildChatHistory() {
    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '四国めたんが話しかけてくれるのを待ってるで〜',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: 
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF4A90E2),
              child: const Icon(
                Icons.face,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFF4A90E2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(
                Icons.person,
                size: 20,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildVoiceInputButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: GestureDetector(
        onTapDown: (_) => _startListening(),
        onTapUp: (_) => _stopListening(),
        onTapCancel: () => _stopListening(),
        child: AnimatedBuilder(
          animation: _waveAnimation,
          builder: (context, child) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening 
                    ? const Color(0xFF4A90E2)
                    : Colors.grey[400],
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.4),
                          blurRadius: 20 * _waveAnimation.value,
                          spreadRadius: 10 * _waveAnimation.value,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                size: 40,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// チャットメッセージクラス
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}