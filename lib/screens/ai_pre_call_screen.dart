import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'zundamon_chat_screen.dart';

/// AI（ずんだもん）専用プリコール画面
/// レート850以下のユーザーがAIとマッチングしたときに表示される
class AiPreCallScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final bool isVideoCall;

  const AiPreCallScreen({
    super.key,
    required this.callId,
    required this.channelName,
    this.isVideoCall = false,
  });

  @override
  State<AiPreCallScreen> createState() => _AiPreCallScreenState();
}

class _AiPreCallScreenState extends State<AiPreCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _transitionTimer;
  
  // ずんだもんの固定情報
  final String _zundamonIcon = 'aseets/icons/Guy 1.svg'; // ずんだもん用アイコン
  final String _zundamonName = 'ずんだもん';
  final int _zundamonThemeIndex = 2; // 緑系テーマ
  
  // テーマカラー（AppThemePalette準拠）
  final List<Color> _themeColors = [
    const Color(0xFF5A64ED), // 青紫
    const Color(0xFFE6D283), // 金色
    const Color(0xFFA482E5), // 紫
    const Color(0xFF83C8E6), // 青
    const Color(0xFFF0941F), // オレンジ
  ];

  @override
  void initState() {
    super.initState();
    
    // パルスアニメーション設定
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // 3秒後に自動でAI通話画面に遷移
    _transitionTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToZundamonChat();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transitionTimer?.cancel();
    super.dispose();
  }

  void _navigateToZundamonChat() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ZundamonChatScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: const Color(0xFF81C784), // ずんだもんカラー（薄緑）
      body: SafeArea(
        child: Stack(
          children: [
            // 背景グラデーション
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF81C784),
                    const Color(0xFF66BB6A).withOpacity(0.8),
                  ],
                ),
              ),
            ),
            
            // メインコンテンツ
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // AI練習モード表示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI練習モード',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: screenHeight * 0.05),
                  
                  // ずんだもんアバター（パルスアニメーション付き）
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: SvgPicture.asset(
                              _zundamonIcon,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: screenHeight * 0.04),
                  
                  // ずんだもん名前
                  Text(
                    _zundamonName,
                    style: GoogleFonts.notoSans(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // AI表記
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.smart_toy,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI アシスタント',
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: screenHeight * 0.06),
                  
                  // 励ましメッセージ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: const Color(0xFF81C784),
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ボクと一緒にがんばるのだ〜！',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2E7D32),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ずんだパワーで元気いっぱいにするのだ！',
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: screenHeight * 0.06),
                  
                  // カウントダウン表示
                  StreamBuilder<int>(
                    stream: Stream.periodic(
                      const Duration(seconds: 1),
                      (i) => 3 - i,
                    ).take(4),
                    builder: (context, snapshot) {
                      final countdown = snapshot.data ?? 3;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          countdown.toString(),
                          style: GoogleFonts.catamaran(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    '音声チャット開始まで...',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            // 手動スキップボタン（右上）
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _navigateToZundamonChat,
                child: Row(
                  children: [
                    Text(
                      'スキップ',
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}