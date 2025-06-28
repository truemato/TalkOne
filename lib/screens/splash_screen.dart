// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 画面サイズを取得
    final screenSize = MediaQuery.of(context).size;
    // 元コードでのデザイン用ベースサイズ：幅 393px、高さ 852px
    const baseWidth = 393.0;
    const baseHeight = 852.0;

    // 「TalkOne」テキストの縦位置（baseHeight に対する比率）
    const talkOneTopRatio = 263.0 / baseHeight;
    // 本文テキストの縦位置（baseHeight に対する比率）
    const bodyTextTopRatio = 513.0 / baseHeight;

    // 文字の横幅制限用に、元コードで 304px ／ 393px ≒ 0.774 の比率を使う
    final bodyTextWidth = screenSize.width * (304.0 / baseWidth);

    return Scaffold(
      // 画面全体の背景色を指定
      backgroundColor: const Color(0xFFE2E0F9),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // 1) 「TalkOne」テキスト
              Positioned(
                top: screenSize.height * talkOneTopRatio,
                left: 0,
                right: 0,
                child: const Center(
                  child: Text(
                    'TalkOne',
                    textAlign: TextAlign.center,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    maxLines: 1,
                    style: TextStyle(
                      color: Color(0xFF6C6C6C),
                      fontSize: 64,
                      fontFamily: 'Caveat',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // 2) 説明文テキスト
              Positioned(
                top: screenSize.height * bodyTextTopRatio,
                left: (screenSize.width - bodyTextWidth) / 2,
                width: bodyTextWidth,
                child: const Text(
                  'AIと人の対話を通じて、自信を持って話せるコミュニケーションスキルを身につけましょう。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF594C4C),
                    fontSize: 20,
                    fontFamily: 'Castoro Titling',
                    fontWeight: FontWeight.w400,
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
