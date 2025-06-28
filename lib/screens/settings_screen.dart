import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import 'profile_setting_screen.dart';
import 'credit_screen.dart';
import 'zundamon_chat_screen.dart';
import '../utils/theme_utils.dart';

// 設定画面本体
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  int _selectedThemeIndex = 0;

  @override
  void initState() {
    super.initState();
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

  void _selectVoicePersonality(int personalityId) {
    // 人格1（りん）が選択された場合、ずんだもんチャット画面に遷移
    if (personalityId == 1) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ZundamonChatScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    } else {
      // 他の人格は今後実装予定
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '人格${personalityId + 1}は今後実装予定です',
            style: GoogleFonts.notoSans(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
              // VoiceVox人格選択
              ListTile(
                leading: const Icon(Icons.record_voice_over, color: Colors.white),
                title: const Text('音声キャラクター', style: TextStyle(color: Colors.white)),
                subtitle: Row(
                  children: [
                    // 人格1: さくら（ピンク）
                    GestureDetector(
                      onTap: () => _selectVoicePersonality(0),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.pink.shade300,
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.face, color: Colors.white, size: 20),
                      ),
                    ),
                    // 人格2: りん（緑）
                    GestureDetector(
                      onTap: () => _selectVoicePersonality(1),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.green.shade400,
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.face, color: Colors.white, size: 20),
                      ),
                    ),
                    // 人格3: みお（青）
                    GestureDetector(
                      onTap: () => _selectVoicePersonality(2),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade400,
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.face, color: Colors.white, size: 20),
                      ),
                    ),
                    // 人格4: ゆい（オレンジ）
                    GestureDetector(
                      onTap: () => _selectVoicePersonality(3),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade400,
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.face, color: Colors.white, size: 20),
                      ),
                    ),
                    // 人格5: あかり（紫）
                    GestureDetector(
                      onTap: () => _selectVoicePersonality(4),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.purple.shade400,
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.face, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
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