import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import 'profile_setting_screen.dart';
import 'credit_screen.dart';
import '../utils/theme_utils.dart';

// 設定画面本体
class SettingsScreen extends StatefulWidget {
  final int initialThemeIndex;
  const SettingsScreen({Key? key, required this.initialThemeIndex})
      : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  late int _selectedThemeIndex;

  @override
  void initState() {
    super.initState();
    _selectedThemeIndex = widget.initialThemeIndex;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedThemeIndex = profile.themeIndex;
      });
    }
  }

  Future<void> _updateTheme(int newThemeIndex) async {
    setState(() {
      _selectedThemeIndex = newThemeIndex;
    });
    
    // UserProfileServiceで保存
    await _userProfileService.updateProfile(themeIndex: newThemeIndex);
  }


  AppThemePalette get _currentTheme => getAppTheme(_selectedThemeIndex);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // 左から右へのスワイプ（正の速度）でホーム画面に戻る
        if (details.primaryVelocity! > 0) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _currentTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            '設定',
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
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              // テーマカラー選択
              ListTile(
                leading: const Icon(Icons.color_lens, color: Colors.white),
                title: const Text('背景テーマ', style: TextStyle(color: Colors.white)),
                subtitle: Row(
                  children: List.generate(
                    appThemesForSelection.length,
                    (i) => GestureDetector(
                      onTap: () => _updateTheme(i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: appThemesForSelection[i].backgroundColor,
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _selectedThemeIndex == i
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              // プロフィール設定
              ListTile(
                leading: const Icon(Icons.person, color: Colors.white),
                title: const Text('プロフィール設定', style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const ProfileSettingScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.ease;
                        final tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                    ),
                  );
                },
              ),
              // クレジット表記
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text('クレジット表記', style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const CreditScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.ease;
                        final tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

}