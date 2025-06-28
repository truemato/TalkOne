// lib/screens/evaluation_screen.dart

import 'package:flutter/material.dart';
import '../services/evaluation_service.dart';
import 'rematch_or_home_screen.dart';

class EvaluationScreen extends StatelessWidget {
  final String callId;
  final String partnerId;
  final bool isDummyMatch;

  const EvaluationScreen({
    super.key,
    required this.callId,
    required this.partnerId,
    this.isDummyMatch = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 18, 32, 47),
      body: EvaluationContent(
        callId: callId,
        partnerId: partnerId,
        isDummyMatch: isDummyMatch,
      ),
    );
  }
}

class EvaluationContent extends StatefulWidget {
  final String callId;
  final String partnerId;
  final bool isDummyMatch;

  const EvaluationContent({
    super.key,
    required this.callId,
    required this.partnerId,
    this.isDummyMatch = false,
  });

  @override
  State<EvaluationContent> createState() => _EvaluationContentState();
}

class _EvaluationContentState extends State<EvaluationContent> {
  int _selectedRating = 0; // 0～5 の評価を保持
  bool _isSubmitting = false; // 送信中フラグ
  final EvaluationService _evaluationService = EvaluationService();

  @override
  void initState() {
    super.initState();
    // AI通話の場合は自動で評価を送信してrematch画面に移動
    if (widget.isDummyMatch) {
      _autoSubmitAIEvaluation();
    }
  }

  Future<void> _autoSubmitAIEvaluation() async {
    try {
      // AI通話の場合は自動で星3評価を送信（自分に+1ポイント）
      await _evaluationService.submitEvaluation(
        callId: widget.callId,
        partnerId: widget.partnerId,
        rating: 3, // 星3で+1ポイント
        comment: 'AI練習完了',
        isDummyMatch: true,
      );

      // 自動でrematch画面に移動
      if (mounted) {
        // 現在のユーザーレーティングを取得
        final userRating = await _evaluationService.getUserRating();
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RematchOrHomeScreen(
              userRating: userRating,
              isDummyMatch: true,
            ),
          ),
        );
      }
    } catch (e) {
      print('AI評価自動送信エラー: $e');
      // エラーの場合は通常の評価画面を表示
    }
  }

  @override
  Widget build(BuildContext context) {
    // AI通話の場合は読み込み画面を表示
    if (widget.isDummyMatch) {
      return const Scaffold(
        backgroundColor: Color(0xFFE2E0F9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'AI練習完了\nレーティングを更新中...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final sw = screenSize.width;
    final sh = screenSize.height;

    // 元デザイン比率（ベース: 393×852）
    const baseWidth = 393.0;
    const baseHeight = 852.0;

    // 「相手のアイコン」用の円の直径: 226px ÷ 393px
    final avatarDiameter = sw * (226.0 / baseWidth);
    // アイコンを画面上部から下げる高さ: 133px ÷ 852px
    final avatarTop = sh * (133.0 / baseHeight);

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          height: sh,
          color: const Color(0xFFE2E0F9), // 元デザインのライトパープル
          child: Stack(
            children: [
              // ──────────────────────────────
              //  1) 相手のアイコン（外円＋内円＋インポートボタン）
              // ──────────────────────────────
              Positioned(
                top: avatarTop,
                left: (sw - avatarDiameter) / 2,
                child: SizedBox(
                  width: avatarDiameter,
                  height: avatarDiameter,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 外側の大きい円 (薄パープル)
                      Container(
                        width: avatarDiameter,
                        height: avatarDiameter,
                        decoration: const BoxDecoration(
                          color: Color(0x7FFFA9A9), // 半透明薄赤寄せ
                          borderRadius: BorderRadius.all(Radius.circular(43)),
                        ),
                      ),
                      // 少し小さい内側の円 (グレー)
                      Container(
                        width: avatarDiameter * 0.736, // 166.22 / 226 くらい
                        height: avatarDiameter * 0.736,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD9D9D9),
                          shape: BoxShape.circle,
                        ),
                        child: widget.isDummyMatch
                            ? const Icon(
                                Icons.smart_toy,
                                size: 60,
                                color: Colors.grey,
                              )
                            : const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              ),
                      ),
                      // ダミーマッチの場合はカメラアイコンを非表示
                      if (!widget.isDummyMatch)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              // TODO: ここでアバター画像をインポートする処理を実装
                            },
                            child: Container(
                              width: avatarDiameter * 0.2,
                              height: avatarDiameter * 0.2,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC1BEE2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ──────────────────────────────
              //  2) 評価（５段階スターアイコン）
              // ──────────────────────────────
              Positioned(
                top: avatarTop + avatarDiameter + 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: _isSubmitting ? null : () {
                        setState(() {
                          _selectedRating = index + 1;
                        });
                      },
                      icon: Icon(
                        // 選択済みなら塗りつぶし星、未選択は枠線星
                        index < _selectedRating
                            ? Icons.star
                            : Icons.star_border,
                        size: fortyFourPercentOf(sw),
                        color: _isSubmitting ? Colors.grey : Colors.amber,
                      ),
                      splashRadius: fortyPercentOf(sw),
                    );
                  }),
                ),
              ),

              // ──────────────────────────────
              //  3) 「通話相手を評価してください」テキスト
              // ──────────────────────────────
              Positioned(
                top:
                    avatarTop +
                    avatarDiameter +
                    24 +
                    fortyFourPercentOf(sw) +
                    16,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    widget.isDummyMatch 
                        ? 'AI練習相手を評価してください'
                        : '通話相手を評価してください',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 24,
                      fontFamily: 'Catamaran',
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.68,
                    ),
                  ),
                ),
              ),

              // ──────────────────────────────
              //  4) 評価を送信するボタン
              // ──────────────────────────────
              Positioned(
                top:
                    avatarTop +
                    avatarDiameter +
                    24 +
                    fortyFourPercentOf(sw) +
                    16 +
                    48,
                left: (sw * 0.2),
                right: (sw * 0.2),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedRating > 0 && !_isSubmitting
                        ? _submitEvaluation
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedRating > 0 && !_isSubmitting
                          ? const Color(0xFFC2CEF7)
                          : Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 2,
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text(
                            '送信する',
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
              //  5) 画面下部に「TalkOne」ロゴ
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

  // 評価送信処理
  Future<void> _submitEvaluation() async {
    if (_selectedRating <= 0 || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _evaluationService.submitEvaluation(
        callId: widget.callId,
        partnerId: widget.partnerId,
        rating: _selectedRating,
        isDummyMatch: widget.isDummyMatch,
      );

      if (mounted) {
        // 評価送信完了後、次の画面に遷移
        final userRating = await _evaluationService.getUserRating();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RematchOrHomeScreen(
              userRating: userRating,
              isDummyMatch: widget.isDummyMatch,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('評価の送信に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// 画面幅 sw に対し、スターアイコンサイズを約 44% に調整
  double fortyFourPercentOf(double sw) => sw * 0.088; // 約 34px 相当

  /// スプラッシュなどでアイコンのスプラッシュ半径に使う
  double fortyPercentOf(double sw) => sw * 0.04; // 約 15px 相当
}