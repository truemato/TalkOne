import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';

// 通知画面（仮）
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  int _selectedThemeIndex = 0;

  // テーマカラー配列
  final List<Color> _themeColors = [
    const Color(0xFF5A64ED), // Default Blue
    const Color(0xFFE6D283), // Golden
    const Color(0xFFA482E5), // Purple
    const Color(0xFF83C8E6), // Blue
    const Color(0xFFF0941F), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
  }

  Future<void> _loadUserTheme() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedThemeIndex = profile.themeIndex ?? 0;
      });
    }
  }

  Color get _currentThemeColor => _themeColors[_selectedThemeIndex];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        // 下から上へのスワイプ（負の速度）でホーム画面に戻る
        if (details.primaryVelocity! < 0) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _currentThemeColor,
        appBar: AppBar(
          title: Text(
            '通知',
            style: GoogleFonts.notoSans(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Platform.isAndroid
            ? SafeArea(child: _buildContent())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return const Column(
      children: [
        Expanded(
          child: Center(
            child: Text(
              '通知画面（仮）',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}