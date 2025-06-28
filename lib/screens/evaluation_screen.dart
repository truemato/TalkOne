import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import '../services/rating_service.dart';
import '../services/evaluation_service.dart';
import '../services/user_profile_service.dart';
import '../services/call_history_service.dart';
import 'rematch_or_home_screen.dart';
import 'partner_profile_screen.dart';
import '../utils/theme_utils.dart';

class EvaluationScreen extends StatefulWidget {
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
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen>
    with TickerProviderStateMixin {
  int _selectedRating = 0;
  late AnimationController _starController;
  late Animation<double> _starAnimation;
  bool _isSubmitted = false;

  final RatingService _ratingService = RatingService();
  final EvaluationService _evaluationService = EvaluationService();
  final UserProfileService _userProfileService = UserProfileService();
  final CallHistoryService _callHistoryService = CallHistoryService();

  // 相手のアイコンとテーマ
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  int _selectedThemeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _starController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    // 相手のプロフィールを読み込み
    final partnerProfile = await _userProfileService.getUserProfileById(widget.partnerId);
    if (partnerProfile != null && mounted) {
      setState(() {
        _selectedIconPath = partnerProfile.iconPath ?? 'aseets/icons/Woman 1.svg';
        // 相手のテーマインデックスを適用
        _selectedThemeIndex = partnerProfile.themeIndex ?? 0;
        // テーマインデックスが範囲外の場合はデフォルトに設定
        if (_selectedThemeIndex >= themeCount) {
          _selectedThemeIndex = 0;
        }
      });
    }
  }

  Future<void> _submitRating(int rating) async {
    setState(() {
      _isSubmitted = true;
    });

    try {
      // 評価をデータベースに保存
      await _evaluationService.submitEvaluation(
        callId: widget.callId,
        partnerId: widget.partnerId,
        rating: rating,
        isDummyMatch: widget.isDummyMatch,
      );

      // AI通話の場合は特別処理
      if (widget.isDummyMatch || widget.partnerId.contains('ai_')) {
        // AI通話: 相手（AI）には評価を送らず、自分がAIから星3評価を受ける
        print('AI（ずんだもん）から星3の評価を受けました');
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        await _ratingService.updateRating(3, userId); // 自分のレーティングを更新
      } else {
        // 通常マッチ: 相手のレーティングを更新
        await _ratingService.updateRating(rating, widget.partnerId);
      }

      // 通話履歴に評価を反映
      await _callHistoryService.updateCallRating(
        widget.callId,
        rating,
        true, // 自分の評価
      );

      // evaluationコレクションからの評価データを履歴に同期
      await _callHistoryService.syncRatingsFromEvaluations();

      print('評価送信完了: $rating星');

      // 1秒後にリマッチ画面に遷移
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const RematchOrHomeScreen(),
          ),
        );
      }
    } catch (e) {
      print('評価送信エラー: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('評価の送信に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitted = false;
          _selectedRating = 0;
        });
      }
    }
  }

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  @override
  Widget build(BuildContext context) {
    final currentTheme = getAppTheme(_selectedThemeIndex);
    return Scaffold(
      backgroundColor: currentTheme.backgroundColor,
      body: Platform.isAndroid
          ? SafeArea(child: _buildContent())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatar(),
          const SizedBox(height: 12),
          if (!_isSubmitted)
            Text(
              'タップして相手のプロフィールを表示',
              style: GoogleFonts.catamaran(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          const SizedBox(height: 28),
          _buildRatingText(),
          const SizedBox(height: 30),
          _buildRatingStars(),
          const SizedBox(height: 20),
          _buildRatingDescription(),
          if (_isSubmitted) ...[
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              '評価を送信中...',
              style: GoogleFonts.catamaran(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _isSubmitted ? null : () {
        // 相手のプロフィール画面に遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PartnerProfileScreen(
              partnerId: widget.partnerId,
              callId: widget.callId,
              isDummyMatch: widget.isDummyMatch,
            ),
          ),
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.7),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            children: [
              SvgPicture.asset(
                _selectedIconPath!,
                fit: BoxFit.cover,
              ),
              // タップ可能であることを示すオーバーレイ
              if (!_isSubmitted)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.info,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingText() {
    return Text(
      '今の通話を評価してください',
      style: GoogleFonts.catamaran(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRatingStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: _isSubmitted ? null : () {
            setState(() {
              _selectedRating = index + 1;
            });
            _starController.forward(from: 0.0);

            // 星を選択した瞬間に送信処理を実行
            Future.delayed(const Duration(milliseconds: 500), () {
              _submitRating(_selectedRating);
            });
          },
          child: AnimatedBuilder(
            animation: _starController,
            builder: (context, child) => Transform.scale(
              scale: index < _selectedRating
                  ? 1.0 + (_starController.value * 0.2)
                  : 1.0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  size: 50,
                  color: index < _selectedRating
                      ? const Color(0xFFFFD700)
                      : Colors.white.withOpacity(0.6),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRatingDescription() {
    if (_selectedRating == 0) return const SizedBox.shrink();

    final descriptions = [
      '',
      'とても悪い',
      '悪い',
      '普通',
      '良い',
      'とても良い',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        descriptions[_selectedRating],
        style: GoogleFonts.catamaran(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4E3B7A),
        ),
      ),
    );
  }

  Widget _buildSendingIndicator() {
    return Column(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '評価を送信中...',
          style: GoogleFonts.catamaran(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}