import 'package:flutter/material.dart';
import '../services/evaluation_service.dart';
import 'matching_screen.dart';
import 'home_screen.dart';

class RematchOrHomeScreen extends StatefulWidget {
  final double userRating;
  final bool isDummyMatch;

  const RematchOrHomeScreen({
    super.key,
    required this.userRating,
    this.isDummyMatch = false,
  });

  @override
  State<RematchOrHomeScreen> createState() => _RematchOrHomeScreenState();
}

class _RematchOrHomeScreenState extends State<RematchOrHomeScreen> {
  final EvaluationService _evaluationService = EvaluationService();
  bool _shouldRecommendAI = false;

  @override
  void initState() {
    super.initState();
    _checkAIRecommendation();
  }

  Future<void> _checkAIRecommendation() async {
    final shouldRecommendAI = await _evaluationService.shouldMatchWithAI(widget.userRating);
    setState(() {
      _shouldRecommendAI = shouldRecommendAI;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 画面サイズを取得
    final screenSize = MediaQuery.of(context).size;
    final sw = screenSize.width;
    final sh = screenSize.height;

    // 元デザインのベースサイズ
    const baseWidth = 393.0;
    const baseHeight = 852.0;

    // ボタン幅は「165px / 393px」の比率で算出
    final buttonWidth = sw * (165.0 / baseWidth);

    // 「もう一度マッチング」ボタンの高さは 103px / 852px
    final rematchButtonHeight = sh * (103.0 / baseHeight);
    // 「ホームに戻る」ボタンの高さは 78px / 852px
    final homeButtonHeight = sh * (78.0 / baseHeight);

    // 縦位置の比率
    // 「もう一度マッチング」ボタンの top は 232px / 852px
    final rematchButtonTop = sh * (232.0 / baseHeight);
    // 「ホームに戻る」ボタンの top は 426px / 852px
    final homeButtonTop = sh * (426.0 / baseHeight);

    return Scaffold(
      backgroundColor: const Color(0xFFE2E0F9),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // ──────────────────────────────
              //  0) レーティング表示とAI推奨メッセージ
              // ──────────────────────────────
              Positioned(
                top: sh * 0.1,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      'あなたのレート: ${widget.userRating.toInt()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_shouldRecommendAI && !widget.isDummyMatch)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.lightbulb,
                              color: Colors.orange,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'AI練習モードがおすすめです！\n会話スキルを向上させましょう',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ──────────────────────────────
              //  1) 「もう一度マッチング」ボタン
              // ──────────────────────────────
              Positioned(
                top: rematchButtonTop,
                left: (sw - buttonWidth) / 2, // 横中央に配置
                child: SizedBox(
                  width: buttonWidth,
                  height: rematchButtonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MatchingScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC2CEF7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'もう一度\nマッチング',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Catamaran',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),

              // ──────────────────────────────
              //  1.5) AI練習ボタン（推奨時のみ表示）
              // ──────────────────────────────
              if (_shouldRecommendAI)
                Positioned(
                  top: rematchButtonTop + rematchButtonHeight + 20,
                  left: (sw - buttonWidth) / 2,
                  child: SizedBox(
                    width: buttonWidth,
                    height: rematchButtonHeight * 0.8,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MatchingScreen(forceAIMatch: true),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'AI練習\nモード',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontFamily: 'Catamaran',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),

              // ──────────────────────────────
              //  2) 「ホームに戻る」ボタン
              // ──────────────────────────────
              Positioned(
                top: homeButtonTop + (_shouldRecommendAI ? 80 : 0),
                left: (sw - buttonWidth) / 2,
                child: SizedBox(
                  width: buttonWidth,
                  height: homeButtonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => HomeScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC2CEF7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ホームに戻る',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Catamaran',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),

              // ──────────────────────────────
              //  3) 下部ロゴ
              // ──────────────────────────────
              Positioned(
                bottom: sh * 0.04,
                left: 0,
                right: 0,
                child: const Text(
                  'TalkOne',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontSize: 64,
                    fontFamily: 'Catamaran',
                    fontWeight: FontWeight.w800,
                    letterSpacing: -4.48,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}