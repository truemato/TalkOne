import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';

// クレジット表記画面
class CreditScreen extends StatefulWidget {
  final int initialThemeIndex;
  const CreditScreen({ Key? key, required this.initialThemeIndex,}) : super(key: key);

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  late int _selectedThemeIndex;

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
    _selectedThemeIndex = widget.initialThemeIndex;
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
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _currentThemeColor,
        body: Stack(
          children: [
            // 背景にテーマカラーを敷く
            Positioned.fill(
              child: Container(color: _currentThemeColor),
            ),
            // メインコンテンツ
            Platform.isAndroid
                ? SafeArea(child: _buildContent())
                : _buildContent(),
          ],
        ),
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
            const Expanded(
              child: Center(
                child: Text(
                  'クレジット表記',
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
                  const Text(
                    '謝辞',
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
                      'VOICEVOX  …  © Hiroshiba Kazuyuki\n'
                      'Fluent Emoji  …  © Microsoft\n'
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
                      'Permission is hereby granted, free of charge, to any person obtaining a copy\n'
                      'of this software and associated documentation files (the "Software"), to deal\n'
                      'in the Software without restriction, including without limitation the rights\n'
                      'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n'
                      'copies of the Software, and to permit persons to whom the Software is\n'
                      'furnished to do so, subject to the following conditions:\n'
                      '　The above copyright notice and this permission notice shall be included in\n'
                      '　all copies or substantial portions of the Software.\n'
                      '\n'
                      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n'
                      'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n'
                      'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n'
                      'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n'
                      'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n'
                      'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n'
                      'SOFTWARE.',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        height: 1.7,
                      ),
                      textAlign: TextAlign.left,
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