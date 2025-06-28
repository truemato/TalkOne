// lib/screens/matching_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/call_matching_service.dart';
import '../services/evaluation_service.dart';
import '../services/ai_filter_service.dart';
import 'pre_call_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchingScreen extends StatefulWidget {
  final bool forceAIMatch;
  final bool isVideoCall;
  final bool enableAIFilter;
  final bool privacyMode;
  
  const MatchingScreen({
    super.key, 
    this.forceAIMatch = false, 
    this.isVideoCall = false,
    this.enableAIFilter = false,
    this.privacyMode = false,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  final CallMatchingService _matchingService = CallMatchingService();
  final EvaluationService _evaluationService = EvaluationService();
  final AIFilterService _aiFilterService = AIFilterService();
  
  late Timer _dotTimer;
  int _dotCount = 0;
  int _waitingSeconds = 0;
  Timer? _waitingTimer;
  String? _callRequestId;
  StreamSubscription? _matchingSubscription;
  double _userRating = 100.0;
  bool _hasAIFilterAccess = false;

  @override
  void initState() {
    super.initState();
    _loadUserRating();
    _checkAIFilterAccess();
    _startDotAnimation();
    _startMatching();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面が再表示されるたびにレーティングを更新
    _loadUserRating();
  }

  Future<void> _loadUserRating() async {
    try {
      final rating = await _evaluationService.getUserRating();
      setState(() {
        _userRating = rating;
      });
    } catch (e) {
      print('ユーザーレーティング取得エラー: $e');
    }
  }
  
  Future<void> _checkAIFilterAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final rating = doc.data()?['rating']?.toDouble() ?? 3.0;
        setState(() {
          _hasAIFilterAccess = _aiFilterService.hasAccess(rating);
        });
      }
    }
  }

  void _startDotAnimation() {
    // 400msごとにドット数を更新
    _dotTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4; // 0→1→2→3→0 のサイクル
        });
      }
    });
  }

  Future<void> _startMatching() async {
    // 待機時間カウント開始
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _waitingSeconds++;
        });
      }
    });

    try {
      // 通話リクエストを作成（AI強制マッチングフラグとAIフィルター設定を渡す）
      _callRequestId = await _matchingService.createCallRequest(
        forceAIMatch: widget.forceAIMatch,
        enableAIFilter: widget.enableAIFilter,
        privacyMode: widget.privacyMode,
      );

      // マッチング監視開始
      _matchingSubscription = _matchingService
          .startMatching(_callRequestId!)
          .listen(
        (match) {
          if (match != null) {
            _handleMatchSuccess(match);
          }
        },
        onError: (error) {
          _handleMatchError(error.toString());
        },
      );
    } catch (e) {
      _handleMatchError(e.toString());
    }
  }

  void _handleMatchSuccess(CallMatch match) {
    if (!mounted) return;

    _dotTimer.cancel();
    _waitingTimer?.cancel();
    _matchingSubscription?.cancel();

    // PreCallScreenに遷移
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PreCallScreen(
          callId: match.callId,
          partnerId: match.partnerId,
          channelName: match.channelName,
          isVideoCall: widget.isVideoCall,
          enableAIFilter: widget.enableAIFilter,
          privacyMode: widget.privacyMode,
        ),
      ),
    );
  }

  void _handleMatchError(String error) {
    if (!mounted) return;

    _dotTimer.cancel();
    _waitingTimer?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('マッチングエラー: $error'),
        backgroundColor: Colors.red,
      ),
    );

    // エラー時はホーム画面に戻る
    Navigator.pop(context);
  }

  Future<void> _cancelMatching() async {
    if (_callRequestId != null) {
      await _matchingService.cancelCallRequest(_callRequestId!);
    }

    _dotTimer.cancel();
    _waitingTimer?.cancel();
    _matchingSubscription?.cancel();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _dotTimer.cancel();
    _waitingTimer?.cancel();
    _matchingSubscription?.cancel();
    _matchingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2E0F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE2E0F9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E)),
          onPressed: _cancelMatching,
        ),
        title: Text(
          widget.forceAIMatch 
              ? 'AI練習モード' 
              : widget.isVideoCall 
                  ? 'ビデオ通話マッチング' 
                  : '音声通話マッチング',
          style: const TextStyle(
            color: Color(0xFF1E1E1E),
            fontFamily: 'Catamaran',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TalkOne ロゴ
              const Text(
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

              const SizedBox(height: 48),

              // あなたのRATE / 数値
              Column(
                children: [
                  const Text(
                    'YOUR RATE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 24,
                      fontFamily: 'Catamaran',
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.68,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_userRating.toInt()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 64,
                      fontFamily: 'Noto Sans',
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2.56,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // オンラインユーザー数
              const Text(
                'オンラインのユーザー：10人',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontFamily: 'Catamaran',
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.40,
                ),
              ),

              const SizedBox(height: 32),

              // 待機時間表示
              Text(
                '待機時間: $_waitingSeconds秒',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF4E3B7A),
                  fontSize: 18,
                  fontFamily: 'Catamaran',
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              // マッチング中 ＋ アニメーションドット
              AnimatedMatchingText(
                dotCount: _dotCount,
                isAIMode: widget.forceAIMatch,
              ),

              const SizedBox(height: 48),

              // キャンセルボタン
              ElevatedButton(
                onPressed: _cancelMatching,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC2CEF7),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  elevation: 4,
                ),
                child: const Text(
                  'キャンセル',
                  style: TextStyle(
                    fontSize: 24,
                    fontFamily: 'Catamaran',
                    fontWeight: FontWeight.w800,
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

class AnimatedMatchingText extends StatelessWidget {
  final int dotCount;
  final bool isAIMode;
  
  const AnimatedMatchingText({
    required this.dotCount,
    this.isAIMode = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // ドットの数は 0～3 まで。0 のときは非表示、1→1つ、2→2つ、3→3つのドットを表示
    // 事前に枠を確保するため、最大3つ分のスペースを常に使います。
    const dotStyle = TextStyle(
      color: Colors.black,
      fontSize: 32,
      fontFamily: 'Catamaran',
      fontWeight: FontWeight.w800,
    );
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isAIMode ? 'AI準備中' : 'マッチング中',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 32,
            fontFamily: 'Catamaran',
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        // ドット3つ分のスペースを用意し、dotCountに応じて色だけ切り替える
        for (var i = 0; i < 3; i++) ...[
          Text(
            '．',
            style: dotStyle.copyWith(
              color: (i < dotCount) ? Colors.black : Colors.transparent,
            ),
          ),
        ],
      ],
    );
  }
}