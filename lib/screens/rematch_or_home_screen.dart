import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import 'matching_screen.dart';
import 'home_screen.dart';

class RematchOrHomeScreen extends StatefulWidget {
  const RematchOrHomeScreen({super.key});

  @override
  State<RematchOrHomeScreen> createState() => _RematchOrHomeScreenState();
}

class _RematchOrHomeScreenState extends State<RematchOrHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final UserProfileService _userProfileService = UserProfileService();
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  
  // テーマカラー
  final List<Color> _themeColors = [
    const Color(0xFF5A64ED), // Default Blue
    const Color(0xFFE6D283), // Golden  
    const Color(0xFFA482E5), // Purple
    const Color(0xFF83C8E6), // Blue
    const Color(0xFFF0941F), // Orange
  ];
  int _selectedThemeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedIconPath = profile.iconPath ?? 'aseets/icons/Woman 1.svg';
        int themeIndex = profile.themeIndex ?? 0;
        // 範囲チェック
        if (themeIndex < 0 || themeIndex >= _themeColors.length) {
          themeIndex = 0;
        }
        _selectedThemeIndex = themeIndex;
      });
    }
  }
  
  Color get _currentThemeColor {
    if (_selectedThemeIndex >= 0 && _selectedThemeIndex < _themeColors.length) {
      return _themeColors[_selectedThemeIndex];
    }
    return _themeColors[0]; // デフォルト
  }

  void _goToMatching() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MatchingScreen(),
      ),
      (route) => route.isFirst, // ホーム画面まで戻る
    );
  }

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
      (route) => false, // 全ての履歴をクリア
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentThemeColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            _buildContent(),
            const SizedBox(height: 32),
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatar(),
          const SizedBox(height: 40),
          _buildTitle(),
          const SizedBox(height: 20),
          _buildSubtitle(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: _pulseAnimation.value,
        child: Container(
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
              _selectedIconPath!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      '通話が終了しました',
      style: GoogleFonts.catamaran(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'お疲れさまでした！\n次は何をしますか？',
        style: GoogleFonts.catamaran(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4E3B7A),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          _buildRematchButton(),
          const SizedBox(height: 16),
          _buildHomeButton(),
        ],
      ),
    );
  }

  Widget _buildRematchButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _goToMatching,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4E3B7A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh, size: 24),
            const SizedBox(width: 12),
            Text(
              'もう一度マッチング',
              style: GoogleFonts.catamaran(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _goToHome,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.9),
          foregroundColor: const Color(0xFF4E3B7A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home, size: 24),
            const SizedBox(width: 12),
            Text(
              'ホームに戻る',
              style: GoogleFonts.catamaran(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}