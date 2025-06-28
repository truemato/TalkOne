// lib/screens/pre_call_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/evaluation_service.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import 'voice_call_simulation_screen.dart';
import '../config/app_config.dart';

// 吹き出しの三角ポインターを描くお絵描きクラス！
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// テキストを入れる可愛い吹き出しウィジェット！
class SpeechBubble extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final EdgeInsets padding;
  final Size pointerSize;

  const SpeechBubble({
    required this.text,
    this.backgroundColor = const Color(0xFFF8F1F1),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.pointerSize = const Size(20, 10),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 角丸長方形部分
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontFamily: 'Cascadia Mono',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // 下向き三角形ポインター
        CustomPaint(
          size: pointerSize,
          painter: _TrianglePainter(backgroundColor),
        ),
      ],
    );
  }
}

class PreCallScreen extends StatefulWidget {
  final String callId;
  final String partnerId;
  final String channelName;
  final bool isVideoCall;
  final bool enableAIFilter;
  final bool privacyMode;

  const PreCallScreen({
    super.key,
    required this.callId,
    required this.partnerId,
    required this.channelName,
    this.isVideoCall = false,
    this.enableAIFilter = false,
    this.privacyMode = false,
  });

  @override
  State<PreCallScreen> createState() => _PreCallScreenState();
}

class _PreCallScreenState extends State<PreCallScreen>
    with TickerProviderStateMixin {
  final EvaluationService _evaluationService = EvaluationService();
  
  // 1. Pulse animation for outer circle
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // 2. Bubble fade + slide
  late final AnimationController _bubbleController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeBubbleAnim;

  // 3. Rate count-up
  late final AnimationController _countController;
  late final Animation<int> _countAnim;

  // 4. Online count fade + count-up
  late final AnimationController _onlineController;
  late final Animation<double> _onlineFadeAnim;
  late final Animation<int> _onlineCountAnim;

  double _partnerRating = 100.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPartnerRating();
    _initAnimations();
  }

  Future<void> _loadPartnerRating() async {
    try {
      final rating = await _evaluationService.getUserRating(widget.partnerId);
      setState(() {
        _partnerRating = rating;
        _isLoading = false;
      });
      
      // レーティング取得後にカウントアップアニメーション開始
      _countAnim = IntTween(begin: 0, end: rating.toInt()).animate(
        CurvedAnimation(parent: _countController, curve: Curves.easeOutCubic),
      );
      _countController.forward();
    } catch (e) {
      print('パートナーレーティング取得エラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initAnimations() {
    // 外側の円がふわふわアニメーションするやつ！
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 吹き出しがふわっとフェードインしながらスライドしてくるアニメーション！
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.easeOut),
    );
    _fadeBubbleAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bubbleController, curve: Curves.easeIn));
    
    // ちょっと遅れて吹き出しアニメーション開始！
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _bubbleController.forward();
    });

    // RATEの数字カウントアップアニメーション！
    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // オンラインユーザー数がフェードインしながらカウントアップするアニメーション！
    _onlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _onlineFadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _onlineController, curve: Curves.easeIn));
    _onlineCountAnim = IntTween(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _onlineController, curve: Curves.easeOutCubic),
    );
    _onlineController.forward();

    // 3秒後に自動で通話画面に遷移
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToCall();
      }
    });
  }

  void _navigateToCall() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AppConfig.useAgoraSimulation
            ? VoiceCallSimulationScreen(
                channelName: widget.channelName,
                callId: widget.callId,
                partnerId: widget.partnerId,
              )
            : widget.isVideoCall
                ? VideoCallScreen(
                    channelName: widget.channelName,
                    callId: widget.callId,
                    partnerId: widget.partnerId,
                    enableAIFilter: widget.enableAIFilter,
                    privacyMode: widget.privacyMode,
                  )
                : VoiceCallScreen(
                    channelName: widget.channelName,
                    callId: widget.callId,
                    partnerId: widget.partnerId,
                  ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bubbleController.dispose();
    _countController.dispose();
    _onlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double outerCircleSize = screenSize.width * 0.5;
    final double innerCircleSize = outerCircleSize * 0.85;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 18, 32, 47),
      body: Container(
        color: const Color(0xFFE2E0F9),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. TalkOne のタイトル
                const Text(
                  'TalkOne',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF4E3B7A),
                    fontSize: 96,
                    fontFamily: 'Caveat',
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 48),

                // 2. 丸アイコン部分（外円＋内円）＋吹き出し
                SizedBox(
                  width: outerCircleSize,
                  height: outerCircleSize + 40,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // 2-1. 吹き出し (フェードイン＋スライドイン)
                      SlideTransition(
                        position: _slideAnim,
                        child: FadeTransition(
                          opacity: _fadeBubbleAnim,
                          child: Positioned(
                            top: -50,
                            child: SpeechBubble(
                              text: widget.partnerId.startsWith('ai_') || widget.partnerId.startsWith('dummy_') 
                                  ? 'AI練習パートナーだよ！'
                                  : 'よろしくお願いします！',
                              backgroundColor: const Color(0xFFF8F1F1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 2-2. 外側の大きい円 (薄紫) with pulse
                      Positioned(
                        top: 40,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnim.value,
                              child: child,
                            );
                          },
                          child: Container(
                            width: outerCircleSize,
                            height: outerCircleSize,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC1BEE2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      // 2-3. 内側の円 (グレー) + アイコン
                      Positioned(
                        top: 40 + (outerCircleSize - innerCircleSize) / 2,
                        left: (outerCircleSize - innerCircleSize) / 2,
                        child: Container(
                          width: innerCircleSize,
                          height: innerCircleSize,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD9D9D9),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              widget.partnerId.startsWith('ai_') || widget.partnerId.startsWith('dummy_')
                                  ? Icons.smart_toy
                                  : Icons.person,
                              size: 60,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // 3. 相手のRATE / カウントアップ
                Column(
                  children: [
                    Text(
                      widget.partnerId.startsWith('ai_') || widget.partnerId.startsWith('dummy_')
                          ? 'AI PARTNER'
                          : 'PARTNER RATE',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 24,
                        fontFamily: 'Catamaran',
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.68,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      AnimatedBuilder(
                        animation: _countController,
                        builder: (context, child) {
                          return Text(
                            '${_countAnim.value}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 64,
                              fontFamily: 'Noto Sans',
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2.56,
                            ),
                          );
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 64),

                // 4. オンラインのユーザー数 (フェードイン＋カウントアップ)
                FadeTransition(
                  opacity: _onlineFadeAnim,
                  child: AnimatedBuilder(
                    animation: _onlineCountAnim,
                    builder: (context, child) {
                      return Text(
                        'オンラインのユーザー：${_onlineCountAnim.value}人',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontFamily: 'Catamaran',
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.40,
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 5. 開始までのカウントダウン表示
                const Text(
                  '間もなく通話を開始します...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF4E3B7A),
                    fontSize: 18,
                    fontFamily: 'Catamaran',
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}