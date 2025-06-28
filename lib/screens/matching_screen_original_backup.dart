import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

void main() => runApp(const MatchingScreenApp());

class MatchingScreenApp extends StatelessWidget {
  const MatchingScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 18, 32, 47),
      ),
      home: const MatchingScreen(),
    );
  }
}

class RateCounter extends StatefulWidget {
  final int targetRate;
  const RateCounter({
    super.key,
    this.targetRate = 429,
  });

  @override
  State<RateCounter> createState() => _RateCounterState();
}

class _RateCounterState extends State<RateCounter>
    with TickerProviderStateMixin {
  late AnimationController _rateController;
  late Animation<int> _rateAnimation;

  @override
  void initState() {
    super.initState();
    _rateController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _rateAnimation = IntTween(
      begin: 0,
      end: widget.targetRate,
    ).animate(CurvedAnimation(
      parent: _rateController,
      curve: Curves.easeOut,
    ));

    _rateController.forward();
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'RATE',
            style: GoogleFonts.catamaran(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _rateAnimation,
            builder: (context, child) => Text(
              '${_rateAnimation.value}',
              style: GoogleFonts.notoSans(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1E1E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  late Timer _timer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final contentWidth = min(screenSize.width, 600.0);
    final contentHeight = screenSize.height;

    return Scaffold(
      body: Stack(
        children: [
          // 背景の川のLottieアニメーション
          Positioned.fill(
            child: Lottie.asset(
              'aseets/animations/background_animation(river).json',
              fit: BoxFit.cover,
              repeat: true,
              alignment: Alignment.center,
            ),
          ),
          // メインコンテンツ
          SafeArea(
            child: Center(
              child: SizedBox(
                width: contentWidth,
                height: contentHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40), // 上部のスペース（固定40px）
                    _buildTitle(),
                    SizedBox(height: contentHeight * 0.08), // タイトルとレートの間（8%）
                    const RateCounter(),
                    SizedBox(
                        height: contentHeight * 0.15), // レートとオンラインユーザーの間（15%）
                    _buildOnlineUsers(),
                    SizedBox(
                        height: contentHeight * 0.04), // オンラインユーザーとマッチング中の間（4%）
                    _buildMatchingText(),
                    SizedBox(
                        height: contentHeight * 0.06), // マッチング中とキャンセルボタンの間（6%）
                    _buildCancelButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Talk One',
      style: GoogleFonts.caveat(
        fontSize: 60,
        color: const Color(0xFF4E3B7A),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildOnlineUsers() {
    return Text(
      'オンラインのユーザー ：10人',
      style: GoogleFonts.catamaran(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }

  Widget _buildMatchingText() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'マッチング中',
          style: GoogleFonts.catamaran(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        for (var i = 0; i < 3; i++) ...[
          Text(
            '.',
            style: GoogleFonts.catamaran(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: (i < _dotCount) ? Colors.white : Colors.transparent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCancelButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC2CEF7),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      ),
      child: Text(
        'キャンセル',
        style: GoogleFonts.catamaran(
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
