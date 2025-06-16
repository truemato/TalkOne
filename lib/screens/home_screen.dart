// lib/screens/home_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'matching_screen.dart';
import 'voicevox_test_screen.dart';
import 'shikoku_metan_chat_screen.dart';

// Constants
class AppStrings {
  static const title = 'TalkOne';
  static const greeting = 'やっほー、調子はどう？';
  static const rateLabel = 'RATE';
}

class AppColors {
  static const backgroundMain = Color.fromARGB(255, 18, 32, 47);
  static const backgroundContent = Color(0xFFE2E0F9);
  static const accentOuterCircle = Color(0xFFC1BEE2);
  static const accentInnerCircle = Color(0xFFD9D9D9);
  static const bubbleBackground = Color(0xFFF8F1F1);
  static const buttonBackground = Color(0xFF8BD88B);
  static const buttonIcon = Color(0xFFF3F8B4);
  static const titleText = Color(0xFF4E3B7A);
  static const textPrimary = Color(0xFF1E1E1E);
}

class AppSizes {
  static const maxContentWidth = 600.0;
  static const bubbleBorderRadius = 16.0;
  static const bubblePaddingHorizontal = 12.0;
  static const bubblePaddingVertical = 8.0;
  static const pointerWidth = 20.0;
  static const pointerHeight = 10.0;
  static const buttonShadowBlur = 8.0;
  static const buttonShadowSpread = 1.0;
  static const buttonShadowOffsetY = 4.0;
}

// Triangle Painter for speech bubble pointer
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0)
          ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Reusable SpeechBubble widget
class SpeechBubble extends StatelessWidget {
  final String text;
  final double fontSize;

  const SpeechBubble({required this.text, required this.fontSize, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.bubblePaddingHorizontal,
            vertical: AppSizes.bubblePaddingVertical,
          ),
          decoration: BoxDecoration(
            color: AppColors.bubbleBackground,
            borderRadius: BorderRadius.circular(AppSizes.bubbleBorderRadius),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(AppSizes.pointerWidth, AppSizes.pointerHeight),
          painter: _TrianglePainter(AppColors.bubbleBackground),
        ),
      ],
    );
  }
}

// Title widget
class TitleText extends StatelessWidget {
  final double fontSize;

  const TitleText({required this.fontSize, super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.title,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.titleText,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// Avatar with speech bubble and pulse animation
class AvatarWithBubble extends StatelessWidget {
  final double outerSize;
  final double innerSize;
  final double bubbleFontSize;
  final Animation<double> pulseAnim;
  final Animation<Offset> slideAnim;
  final Animation<double> fadeAnim;

  const AvatarWithBubble({
    required this.outerSize,
    required this.innerSize,
    required this.bubbleFontSize,
    required this.pulseAnim,
    required this.slideAnim,
    required this.fadeAnim,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: outerSize,
      height: outerSize + outerSize * 0.2,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            right: outerSize * 0.1,
            child: SlideTransition(
              position: slideAnim,
              child: FadeTransition(
                opacity: fadeAnim,
                child: SpeechBubble(
                  text: AppStrings.greeting,
                  fontSize: bubbleFontSize,
                ),
              ),
            ),
          ),
          Positioned(
            top: outerSize * 0.08,
            child: AnimatedBuilder(
              animation: pulseAnim,
              builder:
                  (context, child) =>
                      Transform.scale(scale: pulseAnim.value, child: child),
              child: Container(
                width: outerSize,
                height: outerSize,
                decoration: const BoxDecoration(
                  color: AppColors.accentOuterCircle,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            top: outerSize * 0.08 + (outerSize - innerSize) / 2,
            left: (outerSize - innerSize) / 2,
            child: Container(
              width: innerSize,
              height: innerSize,
              decoration: const BoxDecoration(
                color: AppColors.accentInnerCircle,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Rate counter widget
class RateCounter extends StatelessWidget {
  final Animation<int> countAnim;
  final double labelFontSize;
  final double valueFontSize;

  const RateCounter({
    required this.countAnim,
    required this.labelFontSize,
    required this.valueFontSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          AppStrings.rateLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: labelFontSize,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: countAnim,
          builder:
              (context, child) => Text(
                '${countAnim.value}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
        ),
      ],
    );
  }
}

// Chat action button widget
class ChatActionButton extends StatelessWidget {
  final double size;
  final Animation<double> scaleAnim;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  const ChatActionButton({
    required this.size,
    required this.scaleAnim,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scaleAnim,
      child: GestureDetector(
        onTapDown: (_) => onTapDown(),
        onTapUp: (_) => onTapUp(),
        onTapCancel: () => onTapCancel(),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.buttonBackground,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: AppSizes.buttonShadowBlur,
                spreadRadius: AppSizes.buttonShadowSpread,
                offset: Offset(0, AppSizes.buttonShadowOffsetY),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.chat_bubble,
              size: size * 0.3,
              color: AppColors.buttonIcon,
            ),
          ),
        ),
      ),
    );
  }
}

// Main HomeScreen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bubbleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _buttonController;
  late Animation<double> _buttonScaleAnimation;
  late AnimationController _rateController;
  late Animation<int> _rateAnimation;
  
  double _userRating = 1000.0;  // ユーザーレート

  @override
  void initState() {
    super.initState();
    
    _loadUserRating();

    // パルスアニメーションの設定
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 吹き出しアニメーションの設定
    _bubbleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bubbleController, curve: Curves.easeIn));

    // ボタンアニメーションの設定
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    // レートアニメーションの設定
    _rateController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _rateAnimation = IntTween(
      begin: 0,
      end: _userRating.toInt(),
    ).animate(CurvedAnimation(
      parent: _rateController,
      curve: Curves.easeOut,
    ));

    // アニメーションの開始
    _bubbleController.forward();
    _rateController.forward();
  }
  
  Future<void> _loadUserRating() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final rating = doc.data()?['rating']?.toDouble() ?? 1000.0;
          setState(() {
            _userRating = rating;
          });
          
          // レートアニメーションを更新
          _rateAnimation = IntTween(
            begin: 0,
            end: _userRating.toInt(),
          ).animate(CurvedAnimation(
            parent: _rateController,
            curve: Curves.easeOut,
          ));
          
          // アニメーションを再開始
          _rateController.reset();
          _rateController.forward();
        }
      }
    } catch (e) {
      print('ユーザーレート取得エラー: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bubbleController.dispose();
    _buttonController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _onButtonPressed() {
    _buttonController.forward().then((_) {
      _buttonController.reverse();
    });
    
    // マッチング画面に遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MatchingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundContent,
      body: SafeArea(child: Center(child: _buildContent(context))),
    );
  }

  Widget _buildAvatarWithBubble(double outerSize, double innerSize, double fontSize) {
    return SizedBox(
      width: outerSize,
      height: outerSize + outerSize * 0.2,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            right: outerSize * 0.1,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SpeechBubble(
                  text: AppStrings.greeting,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
          Positioned(
            top: outerSize * 0.08,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              ),
              child: Container(
                width: outerSize,
                height: outerSize,
                decoration: const BoxDecoration(
                  color: AppColors.accentOuterCircle,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            top: outerSize * 0.08 + (outerSize - innerSize) / 2,
            left: (outerSize - innerSize) / 2,
            child: Container(
              width: innerSize,
              height: innerSize,
              decoration: const BoxDecoration(
                color: AppColors.accentInnerCircle,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final contentWidth = min(screenSize.width, 600.0);
    final outerSize = contentWidth * 0.6;
    final innerSize = outerSize * 0.7;
    final buttonSize = contentWidth * 0.25;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // タイトル
        Text(
          AppStrings.title,
          style: TextStyle(
            fontSize: contentWidth * 0.15,
            fontWeight: FontWeight.bold,
            color: AppColors.titleText,
          ),
        ),
        
        SizedBox(height: screenSize.height * 0.05),
        
        // レートカウンター
        Column(
          children: [
            Text(
              AppStrings.rateLabel,
              style: TextStyle(
                fontSize: contentWidth * 0.06,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _rateAnimation,
              builder: (context, child) => Text(
                '${_rateAnimation.value}',
                style: TextStyle(
                  fontSize: contentWidth * 0.12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: screenSize.height * 0.05),
        
        // アバターと吹き出し
        _buildAvatarWithBubble(outerSize, innerSize, contentWidth * 0.04),
        
        SizedBox(height: screenSize.height * 0.05 - 40),
        
        // ボタンエリア
        Column(
          children: [
            // ビデオ通話ボタン（平たいボタン）
            Container(
              width: contentWidth * 0.7,
              height: 50,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MatchingScreen(isVideoCall: true),
                    ),
                  );
                },
                icon: const Icon(Icons.videocam, size: 24),
                label: const Text(
                  'ビデオ通話',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[300],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                  shadowColor: Colors.black26,
                ),
              ),
            ),
            
            // メインチャットボタン（音声通話）
            ScaleTransition(
              scale: _buttonScaleAnimation,
              child: GestureDetector(
                onTapDown: (_) => _buttonController.forward(),
                onTapUp: (_) {
                  _buttonController.reverse();
                  _onButtonPressed();
                },
                onTapCancel: () => _buttonController.reverse(),
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: const BoxDecoration(
                    color: AppColors.buttonBackground,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: AppSizes.buttonShadowBlur,
                        spreadRadius: AppSizes.buttonShadowSpread,
                        offset: Offset(0, AppSizes.buttonShadowOffsetY),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.chat_bubble,
                      size: buttonSize * 0.3,
                      color: AppColors.buttonIcon,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: screenSize.height * 0.03),
        
        // ナビゲーションボタン群
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // AI練習ボタン
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MatchingScreen(forceAIMatch: true),
                  ),
                );
              },
              icon: const Icon(Icons.smart_toy, size: 20),
              label: const Text('AI練習'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[200],
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            
            // 四国めたんチャットボタン
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ShikokuMetanChatScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.face, size: 20),
              label: const Text('四国めたん'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            
            // VOICEVOXテストボタン
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VoiceVoxTestScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.record_voice_over, size: 20),
              label: const Text('VOICEVOX'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE1BEE7),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}