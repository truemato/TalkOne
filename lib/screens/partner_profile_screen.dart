import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../utils/theme_utils.dart';
import '../services/rating_service.dart';
import '../services/evaluation_service.dart';

class PartnerProfileScreen extends StatefulWidget {
  final String partnerId;
  final String callId;
  final bool isDummyMatch;

  const PartnerProfileScreen({
    super.key,
    required this.partnerId,
    required this.callId,
    this.isDummyMatch = false,
  });

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final RatingService _ratingService = RatingService();
  final EvaluationService _evaluationService = EvaluationService();
  
  // パートナー情報
  String? _partnerNickname = 'ずんだもん';
  String? _partnerGender = '回答しない';
  String? _partnerComment = 'よろしくお願いします！'; // ダミー
  String? _partnerIconPath = 'aseets/icons/Woman 1.svg';
  int _partnerThemeIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPartnerProfile();
  }

  Future<void> _loadPartnerProfile() async {
    try {
      // 相手の実際のプロフィールをFirebaseから取得
      final profile = await _userProfileService.getUserProfileById(widget.partnerId);
      
      if (profile != null && mounted) {
        setState(() {
          _partnerNickname = profile.nickname ?? 'ユーザー';
          _partnerGender = profile.gender ?? '未設定';
          _partnerComment = profile.comment ?? 'よろしくお願いします！';
          _partnerIconPath = profile.iconPath ?? 'aseets/icons/Woman 1.svg';
          _partnerThemeIndex = profile.themeIndex ?? 0;
          // テーマインデックスが範囲外の場合はデフォルトに設定
          if (_partnerThemeIndex >= themeCount) {
            _partnerThemeIndex = 0;
          }
          _isLoading = false;
        });
        print('相手のプロフィール読み込み完了: ${profile.nickname}');
      } else {
        // プロフィールが見つからない場合はデフォルト値を設定
        if (mounted) {
          setState(() {
            _partnerNickname = 'ユーザー';
            _partnerGender = '未設定';
            _partnerComment = 'よろしくお願いします！';
            _partnerIconPath = 'aseets/icons/Woman 1.svg';
            _partnerThemeIndex = 0;
            _isLoading = false;
          });
        }
        print('相手のプロフィールが見つかりません: ${widget.partnerId}');
      }
    } catch (e) {
      print('パートナープロフィール読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _partnerNickname = 'ユーザー';
          _partnerGender = '未設定';
          _partnerComment = 'よろしくお願いします！';
          _partnerIconPath = 'aseets/icons/Woman 1.svg';
          _partnerThemeIndex = 0;
          _isLoading = false;
        });
      }
    }
  }

  Color get _currentThemeColor => getAppTheme(_partnerThemeIndex).backgroundColor;




  @override
  Widget build(BuildContext context) {
    final currentTheme = getAppTheme(_partnerThemeIndex);
    return Scaffold(
      backgroundColor: currentTheme.backgroundColor, // 相手のテーマカラーを使用
      body: Platform.isAndroid 
          ? SafeArea(child: _buildContent())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return Column(
      children: [
        // ヘッダー
        _buildHeader(),
        
        // コンテンツ
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // プロフィール画像
                _buildProfileIcon(),
                const SizedBox(height: 32),
                
                // ニックネーム
                _buildInfoField('ニックネーム', _partnerNickname ?? 'ユーザー'),
                const SizedBox(height: 20),
                
                // 性別
                _buildInfoField('性別', _partnerGender ?? '未設定'),
                const SizedBox(height: 20),
                
                // 一言コメント
                _buildInfoField('一言コメント', _partnerComment ?? 'よろしくお願いします！'),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '相手のプロフィール',
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileIcon() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: SvgPicture.asset(
                _partnerIconPath!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _partnerNickname ?? 'ユーザー',
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            value,
            style: GoogleFonts.notoSans(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

}