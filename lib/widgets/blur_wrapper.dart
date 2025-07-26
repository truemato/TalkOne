import 'dart:ui';
import 'package:flutter/material.dart';

/// 画面全体に強めのガウスぼかしを適用するラッパーウィジェット
class BlurWrapper extends StatelessWidget {
  final Widget child;
  final double sigmaX;
  final double sigmaY;
  
  const BlurWrapper({
    super.key,
    required this.child,
    this.sigmaX = 50.0, // 超強力なザリザリぼかし値
    this.sigmaY = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 元のコンテンツ
        child,
        // ぼかしレイヤー
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
            child: Container(
              color: Colors.black.withOpacity(0.3), // 強い黒のオーバーレイでザリザリ感
            ),
          ),
        ),
      ],
    );
  }
}

/// 特定のウィジェットにぼかしを適用するラッパー
class PartialBlurWrapper extends StatelessWidget {
  final Widget child;
  final double sigmaX;
  final double sigmaY;
  final Color overlayColor;
  
  const PartialBlurWrapper({
    super.key,
    required this.child,
    this.sigmaX = 50.0,
    this.sigmaY = 50.0,
    this.overlayColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          color: overlayColor,
          child: child,
        ),
      ),
    );
  }
}