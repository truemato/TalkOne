import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/call_matching_service.dart';
import '../services/user_profile_service.dart';
import 'pre_call_profile_screen.dart';
import 'ai_pre_call_screen.dart';
import '../utils/theme_utils.dart';

class RateCounter extends StatefulWidget {
  final int targetRate;
  const RateCounter({
    super.key,
    this.targetRate = 1000,
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
      begin: widget.targetRate > 100 ? widget.targetRate - 100 : 0,
      end: widget.targetRate,
    ).animate(CurvedAnimation(
      parent: _rateController,
      curve: Curves.easeOut,
    ));

    _rateController.forward();
  }

  @override
  void didUpdateWidget(RateCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetRate != widget.targetRate) {
      // targetRateが変更された場合、アニメーションを再実行
      _rateController.reset();
      _rateAnimation = IntTween(
        begin: widget.targetRate > 100 ? widget.targetRate - 100 : 0,
        end: widget.targetRate,
      ).animate(CurvedAnimation(
        parent: _rateController,
        curve: Curves.easeOut,
      ));
      _rateController.forward();
    }
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Widget _buildMetallicRatingText(int rating) {
    double fontSize;
    List<Color> gradientColors;
    List<Color> shadowColors;
    
    if (rating >= 4000) {
      // 金色 (4000以上)
      fontSize = 52; // 46 + 3 + 3
      gradientColors = [
        const Color(0xFFFFD700), // ゴールド
        const Color(0xFFFFA500), // オレンジゴールド
        const Color(0xFFFFD700), // ゴールド
        const Color(0xFFFFE55C), // ライトゴールド
      ];
      shadowColors = [
        Colors.black.withOpacity(0.8), // 黒い影
        Colors.black.withOpacity(0.6), // より薄い黒い影
      ];
    } else if (rating >= 3000) {
      // 銀色 (3000以上)
      fontSize = 49; // 46 + 1 + 2
      gradientColors = [
        const Color(0xFFC0C0C0), // シルバー
        const Color(0xFFE5E5E5), // ライトシルバー
        const Color(0xFFC0C0C0), // シルバー
        const Color(0xFFD3D3D3), // ライトグレー
      ];
      shadowColors = [
        Colors.black.withOpacity(0.8), // 黒い影
        Colors.black.withOpacity(0.6), // より薄い黒い影
      ];
    } else if (rating >= 2000) {
      // 銅色 (2000以上)
      fontSize = 47; // 46 + 1
      gradientColors = [
        const Color(0xFFB87333), // ブロンズ
        const Color(0xFFCD7F32), // ライトブロンズ
        const Color(0xFFB87333), // ブロンズ
        const Color(0xFFD2691E), // チョコレート
      ];
      shadowColors = [
        Colors.black.withOpacity(0.8), // 黒い影
        Colors.black.withOpacity(0.6), // より薄い黒い影
      ];
    } else {
      // 通常 (2000未満)
      fontSize = 46;
      return Text(
        '$rating',
        style: GoogleFonts.notoSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E1E1E),
        ),
      );
    }
    
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(bounds),
      child: Stack(
        children: [
          // シャドウレイヤー (奥行き効果)
          Transform.translate(
            offset: const Offset(2, 2),
            child: Text(
              '$rating',
              style: GoogleFonts.notoSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: shadowColors[1],
              ),
            ),
          ),
          // ミドルシャドウ
          Transform.translate(
            offset: const Offset(1, 1),
            child: Text(
              '$rating',
              style: GoogleFonts.notoSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: shadowColors[0],
              ),
            ),
          ),
          // メインテキスト
          Text(
            '$rating',
            style: GoogleFonts.notoSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            builder: (context, child) => _buildMetallicRatingText(_rateAnimation.value),
          ),
        ],
      ),
    );
  }
}

class MatchingScreen extends StatefulWidget {
  // AI機能無効化のためコメントアウト
  // final bool forceAIMatch;
  final bool isVideoCall;
  // final bool enableAIFilter;
  final bool privacyMode;
  
  const MatchingScreen({
    super.key,
    // this.forceAIMatch = false,
    this.isVideoCall = false,
    // this.enableAIFilter = false,
    this.privacyMode = false,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen>
    with TickerProviderStateMixin {
  final CallMatchingService _matchingService = CallMatchingService();
  final UserProfileService _userProfileService = UserProfileService();
  
  // シュリンクアニメーション用
  late AnimationController _shrinkController;
  late Animation<double> _shrinkAnimation;
  bool _isMatchFound = false;
  
  // プログレスバー用
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late Timer _progressTimer;
  
  // テーマインデックス
  int _selectedThemeIndex = 0;
  
  late Timer _timer;
  int _dotCount = 0;
  int _userRating = 1000; // デフォルトレーティング値
  int _onlineUsers = 0;
  String? _callRequestId;
  StreamSubscription? _matchingSubscription;
  StreamSubscription? _onlineUsersSubscription;

  @override
  void initState() {
    super.initState();
    
    // シュリンクアニメーション初期化
    _shrinkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shrinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _shrinkController,
      curve: Curves.easeInBack,
    ));
    
    // プログレスバーアニメーション初期化（無限ループ）
    _progressController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));
    
    // プログレスバー開始（無限ループ）
    _progressController.repeat();
    
    // 60秒後のタイマーは削除（マッチングを続ける）
    _progressTimer = Timer(const Duration(seconds: 1), () {
      // 何もしない（プレースホルダー）
    });
    
    _loadUserRating();
    _startOnlineUsersListener();
    _startMatching();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _progressTimer.cancel();
    _shrinkController.dispose();
    _progressController.dispose();
    _matchingSubscription?.cancel();
    _onlineUsersSubscription?.cancel();
    if (_callRequestId != null) {
      _matchingService.cancelCallRequest(_callRequestId!);
    }
    _matchingService.dispose();
    super.dispose();
  }

  Future<void> _loadUserRating() async {
    try {
      // まずUserProfileServiceから取得を試す
      final profile = await _userProfileService.getUserProfile();
      if (profile != null && profile.rating != 1000) {
        if (mounted) {
          setState(() {
            _userRating = profile.rating;
            _selectedThemeIndex = profile.themeIndex ?? 0;
            print('MatchingScreen: UserProfileからレーティング読み込み完了 - $_userRating');
          });
        }
        return;
      }
      
      // UserProfileがない、またはデフォルト値の場合、usersコレクションから直接取得
      final userId = _userProfileService.getCurrentUserId();
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists && mounted) {
          final userData = userDoc.data()!;
          final rating = (userData['rating'] ?? 100.0).toDouble().toInt();
          setState(() {
            _userRating = rating;
            _selectedThemeIndex = 0; // デフォルトテーマ
            print('MatchingScreen: usersコレクションからレーティング読み込み完了 - $_userRating');
          });
          
          // UserProfileにも同期保存
          await _userProfileService.updateRating(rating);
        } else if (mounted) {
          // 新規ユーザーの場合、初期レーティング1000を設定
          setState(() {
            _userRating = 1000; // デフォルトレーティング
            _selectedThemeIndex = 0; // デフォルトテーマ
            print('MatchingScreen: 新規ユーザー、初期レーティング1000を設定');
          });
          await _userProfileService.updateRating(1000);
        }
      }
    } catch (e) {
      print('MatchingScreen: レーティング読み込みエラー - $e');
      if (mounted) {
        setState(() {
          _userRating = 1000; // エラー時のフォールバック
          _selectedThemeIndex = 0; // デフォルトテーマ
        });
      }
    }
  }

  void _startOnlineUsersListener() {
    // オンラインユーザー数をリアルタイムで監視
    _onlineUsersSubscription = FirebaseFirestore.instance
        .collection('callRequests')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        // マッチング待ちのユーザー数をカウント
        final waitingUsers = snapshot.docs.where((doc) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          return status == 'waiting' || status == 'matched';
        }).length;

        // 会話中のユーザー数をカウント（activeCalls コレクションから）
        _getActiveCalls().then((activeCalls) {
          if (mounted) {
            final totalOnlineUsers = waitingUsers + (activeCalls * 2); // 通話は2人1組
            setState(() {
              _onlineUsers = totalOnlineUsers;
            });
          }
        });
      }
    });
  }

  Future<int> _getActiveCalls() async {
    try {
      // アクティブな通話数を取得
      final activeCallsSnapshot = await FirebaseFirestore.instance
          .collection('activeCalls')
          .where('status', isEqualTo: 'active')
          .get();
      
      return activeCallsSnapshot.docs.length;
    } catch (e) {
      print('アクティブ通話数取得エラー: $e');
      return 0;
    }
  }

  Future<void> _startMatching() async {
    try {
      // 多段階AI救済システムの判定
      bool isAIRescueMode = _userRating <= 880;
      if (isAIRescueMode) {
        String rescueLevel = '';
        if (_userRating <= 550) rescueLevel = 'レベル3（550以下）';
        else if (_userRating <= 580) rescueLevel = 'レベル3継続中（550-580）';
        else if (_userRating <= 700) rescueLevel = 'レベル2（700以下）';
        else if (_userRating <= 730) rescueLevel = 'レベル2継続中（700-730）';
        else if (_userRating <= 850) rescueLevel = 'レベル1（850以下）';
        else rescueLevel = 'レベル1継続中（850-880）';
        
        print('レート${_userRating}: AI救済モード $rescueLevel でずんだもんとのマッチングを開始します');
      }
      
      // 通話リクエストを作成（レート850以下は自動でAI判定）
      _callRequestId = await _matchingService.createCallRequest(
        forceAIMatch: false, // CallMatchingService内で自動判定
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

  void _handleMatchSuccess(CallMatch match) async {
    if (!mounted) return;
    
    _timer.cancel();
    _progressTimer.cancel();
    _matchingSubscription?.cancel();
    
    // シュリンクアニメーション開始
    setState(() {
      _isMatchFound = true;
    });
    
    await _shrinkController.forward();
    
    if (!mounted) return;
    
    // AIマッチかどうかを判定
    final isAIMatch = match.partnerId.contains('ai_') || match.partnerId.contains('zundamon');
    
    if (isAIMatch) {
      // AI専用プリコール画面に遷移
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AiPreCallScreen(
            callId: match.callId,
            channelName: match.channelName,
            isVideoCall: widget.isVideoCall,
          ),
        ),
      );
    } else {
      // 通常のプロフィール画面に遷移
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PreCallProfileScreen(
            match: match,
          ),
        ),
      );
    }
  }

  void _handleMatchError(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('マッチングエラー: $error'),
        backgroundColor: Colors.red,
      ),
    );
    
    // ホームに戻る
    Navigator.pop(context);
  }

  Future<void> _cancelMatching() async {
    if (_callRequestId != null) {
      await _matchingService.cancelCallRequest(_callRequestId!);
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }
  
  // AI会話を開始する関数
  Future<void> _startAIConversation() async {
    if (!mounted) return;
    
    _timer.cancel();
    _progressTimer.cancel();
    _matchingSubscription?.cancel();
    
    // Gemini AI会話画面に遷移
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AiPreCallScreen(
          callId: 'gemini_chat_${DateTime.now().millisecondsSinceEpoch}',
          channelName: 'gemini_channel',
          isVideoCall: widget.isVideoCall,
        ),
      ),
    );
  }

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final contentWidth = min(screenSize.width, 600.0);
    final contentHeight = screenSize.height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _cancelMatching();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 背景色
            Positioned.fill(
              child: Container(
                color: _currentThemeColor,
              ),
            ),
            // 背景の川のLottieアニメーション（シュリンクアニメーション付き）
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _shrinkAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isMatchFound ? _shrinkAnimation.value : 1.0,
                    child: Lottie.asset(
                      'aseets/animations/background_animation(river).json',
                      fit: BoxFit.cover,
                      repeat: !_isMatchFound,
                      alignment: Alignment.center,
                    ),
                  );
                },
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
                      Column(
                        children: [
                          RateCounter(targetRate: _userRating),
                          if (_userRating == 0)
                            Text(
                              '読み込み中...',
                              style: GoogleFonts.catamaran(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(
                          height: contentHeight * 0.15), // レートとオンラインユーザーの間（15%）
                      _buildOnlineUsers(),
                      SizedBox(
                          height: contentHeight * 0.04), // オンラインユーザーとマッチング中の間（4%）
                      // 多段階AI救済システムの通知を表示
                      if (_userRating <= 880) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: _getAINotificationColor().withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getAINotificationIcon(),
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _getAINotificationMessage(),
                                  style: GoogleFonts.notoSans(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildProgressBar(),
                      const SizedBox(height: 16),
                      _buildAIConversationButton(),
                      const SizedBox(height: 16),
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
      'オンラインのユーザー ：$_onlineUsers人',
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

  Widget _buildProgressBar() {
    return Container(
      width: 300,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.white.withOpacity(0.3),
      ),
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return LinearProgressIndicator(
            value: _progressAnimation.value,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white,
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildAIConversationButton() {
    return ElevatedButton(
      onPressed: _startAIConversation,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_toy, size: 20),
          const SizedBox(width: 8),
          Text(
            'AIと会話',
            style: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return ElevatedButton(
      onPressed: _cancelMatching,
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

  // 多段階AI救済システム用の通知ヘルパーメソッド
  Color _getAINotificationColor() {
    if (_userRating <= 550) {
      return const Color(0xFFFF5722); // 深いオレンジ赤（レベル3）
    } else if (_userRating <= 580) {
      return const Color(0xFFFF5722); // 深いオレンジ赤（レベル3継続）
    } else if (_userRating <= 700) {
      return const Color(0xFFFF9800); // オレンジ（レベル2）
    } else if (_userRating <= 730) {
      return const Color(0xFFFF9800); // オレンジ（レベル2継続）
    } else if (_userRating <= 850) {
      return const Color(0xFF81C784); // ずんだもんカラー（レベル1）
    } else {
      return const Color(0xFF81C784); // ずんだもんカラー（レベル1継続）
    }
  }

  IconData _getAINotificationIcon() {
    if (_userRating <= 550) {
      return Icons.emergency; // 緊急レベル
    } else if (_userRating <= 700) {
      return Icons.medical_services; // 医療レベル
    } else {
      return Icons.smart_toy; // AI通常レベル
    }
  }

  String _getAINotificationMessage() {
    if (_userRating <= 550) {
      return 'AI救済モード（レベル3）- ずんだもんとマッチング';
    } else if (_userRating <= 580) {
      return 'AI救済継続中（レベル3）- ずんだもんとマッチング';
    } else if (_userRating <= 700) {
      return 'AI救済モード（レベル2）- ずんだもんとマッチング';
    } else if (_userRating <= 730) {
      return 'AI救済継続中（レベル2）- ずんだもんとマッチング';
    } else if (_userRating <= 850) {
      return 'AI救済モード（レベル1）- ずんだもんとマッチング';
    } else {
      return 'AI救済継続中（レベル1）- ずんだもんとマッチング';
    }
  }
}