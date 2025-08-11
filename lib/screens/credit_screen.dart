import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/localization_service.dart';

// クレジット表記画面
class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final LocalizationService _localizationService = LocalizationService();
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
        backgroundColor: _currentThemeColor,
        body: Platform.isAndroid
            ? SafeArea(child: _buildContent())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        const SizedBox(height: 48),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Text(
                  _localizationService.translate('credit_title'),
                  style: TextStyle(
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
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TalkOneタイトル
                  Center(
                    child: Text(
                      'Talk One',
                      style: GoogleFonts.caveat(
                        fontSize: 60,
                        color: const Color(0xFF4E3B7A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 謝辞タイトル（左寄せ）
                  Text(
                    _localizationService.translate('credit_acknowledgments'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 16),
                  // 謝辞内容（F9F2F2の丸みを帯びた四角、黒文字）
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F2F2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'VOICEVOX\n'
                      '　© Hiroshiba Kazuyuki\n'
                      'Fluent Emoji\n'
                      '　© Microsoft\n'
                      'Lottiefiles\n'
                      '　Free Cold Mountain Background Animation\n'
                      '　© Felipe Da Silva Pinho\n'
                      'Figma\n'
                      '　People Icons\n'
                      '　© Terra Pappas\n'
                      '\n'
                      'MIT License\n'
                      'Copyright (c)  yuu-1230, truemato\n'
                      '\n'
                      'Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n'
                      '\n'
                      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        height: 1.7,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // お問い合わせ情報
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail_outline,
                          color: _currentThemeColor,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'お問い合わせ',
                          style: GoogleFonts.notoSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          'mail@yoshida.com',
                          style: GoogleFonts.notoSans(
                            fontSize: 16,
                            color: _currentThemeColor,
                            decoration: TextDecoration.underline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ご質問・ご要望・不具合報告など\nお気軽にお問い合わせください',
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}