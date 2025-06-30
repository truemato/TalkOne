import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'zundamon_chat_screen.dart';

/// AI性格別プレコール画面
/// 5つのAI性格（ずんだもん、春日部つむぎ、四国めたん、青山龍星、冥鳴ひまり）に対応
class AiPersonalityPreCallScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final bool isVideoCall;
  final int personalityId; // 0: ずんだもん, 1: 春日部つむぎ, 2: 四国めたん, 3: 青山龍星, 4: 冥鳴ひまり

  const AiPersonalityPreCallScreen({
    super.key,
    required this.callId,
    required this.channelName,
    this.isVideoCall = false,
    required this.personalityId,
  });

  @override
  State<AiPersonalityPreCallScreen> createState() => _AiPersonalityPreCallScreenState();
}

class _AiPersonalityPreCallScreenState extends State<AiPersonalityPreCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _transitionTimer;
  
  // AI性格データ
  late Map<String, dynamic> _personalityData;
  
  @override
  void initState() {
    super.initState();
    _loadPersonalityData();
    
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
        _navigateToAiChat();
      }
    });
  }

  void _loadPersonalityData() {
    final personalities = [
      {
        'name': 'ずんだもん',
        'icon': 'aseets/icons/Guy 1.svg',
        'backgroundColor': const Color(0xFF81C784), // 薄緑
        'gradientColor': const Color(0xFF66BB6A),
        'message': 'ボクと一緒にがんばるのだ〜！',
        'subMessage': 'ずんだパワーで元気いっぱいにするのだ！',
        'iconColor': const Color(0xFF2E7D32),
      },
      {
        'name': '春日部つむぎ',
        'icon': 'aseets/icons/Woman 2.svg',
        'backgroundColor': const Color(0xFF64B5F6), // 知的な青
        'gradientColor': const Color(0xFF42A5F5),
        'message': '一緒に学びを深めていきましょう',
        'subMessage': '知識と経験を共有して成長しましょう',
        'iconColor': const Color(0xFF1565C0),
      },
      {
        'name': '四国めたん',
        'icon': 'aseets/icons/Woman 3.svg',
        'backgroundColor': const Color(0xFFFFB74D), // 明るい橙
        'gradientColor': const Color(0xFFFF9800),
        'message': '楽しく話しましょう！',
        'subMessage': 'エネルギッシュに会話を盛り上げます',
        'iconColor': const Color(0xFFE65100),
      },
      {
        'name': '青山龍星',
        'icon': 'aseets/icons/Guy 2.svg',
        'backgroundColor': const Color(0xFF7986CB), // 力強い青紫
        'gradientColor': const Color(0xFF5C6BC0),
        'message': '共に高みを目指そう',
        'subMessage': '情熱を持って対話に臨みます',
        'iconColor': const Color(0xFF283593),
      },
      {
        'name': '冥鳴ひまり',
        'icon': 'aseets/icons/Woman 4.svg',
        'backgroundColor': const Color(0xFFBA68C8), // ミステリアス紫
        'gradientColor': const Color(0xFFAB47BC),
        'message': '静かな時間を共有しましょう',
        'subMessage': '深い思索と洞察の世界へ',
        'iconColor': const Color(0xFF4A148C),
      },
    ];
    
    _personalityData = personalities[widget.personalityId];
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transitionTimer?.cancel();
    super.dispose();
  }

  void _navigateToAiChat() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ZundamonChatScreen(
          personalityId: widget.personalityId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: _personalityData['backgroundColor'],
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
                    _personalityData['backgroundColor'],
                    (_personalityData['gradientColor'] as Color).withOpacity(0.8),
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
                  
                  // AIアバター（パルスアニメーション付き）
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
                              _personalityData['icon'],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: screenHeight * 0.04),
                  
                  // AI名前
                  Text(
                    _personalityData['name'],
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
                  
                  // 個性別メッセージ
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
                          color: _personalityData['backgroundColor'],
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _personalityData['message'],
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _personalityData['iconColor'],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _personalityData['subMessage'],
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
                onPressed: _navigateToAiChat,
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