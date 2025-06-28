// AI機能無効化のためTalk to AI画面全体をコメントアウト
/*
// lib/screens/talk_to_ai_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;

void main() {
  runApp(const TalkToAiScreenApp());
}

class TalkToAiScreenApp extends StatelessWidget {
  const TalkToAiScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 18, 32, 47),
      ),
      home: const TalkToAiScreen(),
    );
  }
}

class TalkToAiScreen extends StatefulWidget {
  const TalkToAiScreen({super.key});

  @override
  State<TalkToAiScreen> createState() => _TalkToAiScreenState();
}

class _TalkToAiScreenState extends State<TalkToAiScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isRecording = false;

  // SVGアイコン関連
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  final List<String> _svgIcons = [
    'aseets/icons/Guy 1.svg',
    'aseets/icons/Guy 2.svg',
    'aseets/icons/Guy 3.svg',
    'aseets/icons/Guy 4.svg',
    'aseets/icons/Woman 1.svg',
    'aseets/icons/Woman 2.svg',
    'aseets/icons/Woman 3.svg',
    'aseets/icons/Woman 4.svg',
    'aseets/icons/Woman 5.svg',
  ];

  @override
  void initState() {
    super.initState();
    // 初期メッセージを追加
    _messages.add(ChatMessage(
      text: 'こんにちは！何かお手伝いできることはありますか？',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5A64ED),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // AIアイコンを中央上部に表示
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    style: GoogleFonts.catamaran(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4E3B7A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildChatArea(),
            ),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'AI アシスタント',
              style: GoogleFonts.catamaran(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'オンライン',
                  style: GoogleFonts.catamaran(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
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
            decoration: BoxDecoration(
              color: const Color(0xFFE2E0F9),
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
            style: GoogleFonts.catamaran(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4E3B7A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '音声ボタンを押して話しかけてください',
            style: GoogleFonts.catamaran(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
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
                color: const Color(0xFF4E3B7A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
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
                color: message.isUser ? Colors.grey[200] : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: GoogleFonts.catamaran(
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
              decoration: BoxDecoration(
                color: const Color(0xFF4E3B7A),
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
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'メッセージを入力...',
                  hintStyle: GoogleFonts.catamaran(
                    color: Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF4E3B7A)),
                    onPressed: _handleSendMessage,
                  ),
                ),
                style: GoogleFonts.catamaran(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTapDown: (_) => setState(() => _isRecording = true),
            onTapUp: (_) => setState(() => _isRecording = false),
            onTapCancel: () => setState(() => _isRecording = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : const Color(0xFF4E3B7A),
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

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
    });
  }

  // アイコン選択ダイアログ
  void _showIconSelectDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('アイコンを選択'),
          content: SizedBox(
            width: 300,
            height: 200,
            child: GridView.count(
              crossAxisCount: 3,
              children: _svgIcons.map((iconPath) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(iconPath),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SvgPicture.asset(iconPath),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (selected != null) {
      setState(() {
        _selectedIconPath = selected;
      });
    }
  }
}

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
*/
