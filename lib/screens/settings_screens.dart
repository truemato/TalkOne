import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// テーマ用データクラス
class AppThemePalette {
  final Color backgroundColor;
  final Color barColor;
  final Color callIconColor;
  AppThemePalette(this.backgroundColor, this.barColor, this.callIconColor);
}

// パレット一覧
final List<AppThemePalette> appThemes = [
  // 1. デフォルト
  AppThemePalette(const Color(0xFF5A64ED), const Color(0xFF979CDE), const Color(0xFF4CAF50)),
  // 2. E6D283, EAC77A, F59A3E
  AppThemePalette(const Color(0xFFE6D283), const Color(0xFFEAC77A), const Color(0xFFF59A3E)),
  // 3. A482E5, D7B3E8, D487E6
  AppThemePalette(const Color(0xFFA482E5), const Color(0xFFD7B3E8), const Color(0xFFD487E6)),
  // 4. 83C8E6, B8D8E6, 618DAA
  AppThemePalette(const Color(0xFF83C8E6), const Color(0xFFB8D8E6), const Color(0xFF618DAA)),
  // 5. F0941F, EF6024, 548AB6
  AppThemePalette(const Color(0xFFF0941F), const Color(0xFFEF6024), const Color(0xFF548AB6)),
];

// 設定画面本体
class SettingsScreen extends StatelessWidget {
  final int currentThemeIndex;
  final void Function(int) onThemeChanged;
  final AppThemePalette theme;
  const SettingsScreen(
      {super.key,
      required this.currentThemeIndex,
      required this.onThemeChanged,
      required this.theme});

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
        backgroundColor: theme.backgroundColor,
        body: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      '設定',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // アイコン分のスペース
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.color_lens, color: Colors.white),
                    title: const Text('背景テーマ',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Row(
                      children: List.generate(
                          appThemes.length,
                          (i) => GestureDetector(
                                onTap: () {
                                  onThemeChanged(i);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 8),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: appThemes[i].backgroundColor,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: currentThemeIndex == i
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 20)
                                      : null,
                                ),
                              )),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.white),
                    title: const Text('プロフィール設定',
                        style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ProfileSettingScreen(theme: theme),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
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
                  ListTile(
                    leading:
                        const Icon(Icons.info_outline, color: Colors.white),
                    title: const Text('クレジット表記',
                        style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  CreditScreen(theme: theme),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
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
        ),
      ),
    );
  }
}

// プロフィール設定画面
class ProfileSettingScreen extends StatelessWidget {
  final AppThemePalette theme;
  const ProfileSettingScreen({super.key, required this.theme});

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
        backgroundColor: theme.backgroundColor,
        body: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'プロフィール設定',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'あなたのプロフィール',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ニックネーム
                      const _ProfileInputField(
                        hintText: 'ニックネーム',
                        inputType: TextInputType.text,
                      ),
                      const SizedBox(height: 20),
                      // 性別（選択式の丸みを帯びた四角）
                      _ProfileSelectBox(
                        hintText: '性別',
                        child: _GenderDropdown(),
                      ),
                      const SizedBox(height: 20),
                      // 誕生日
                      _ProfileSelectBox(
                        hintText: '誕生日',
                        child: _BirthdayField(),
                      ),
                      const SizedBox(height: 20),
                      // 自己紹介（マッチング用の一言コメント）
                      const _ProfileInputField(
                        hintText: 'みんなに一言',
                        inputType: TextInputType.multiline,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      // AIに伝えたいこと
                      const _ProfileInputField(
                        hintText: 'AIに伝えたいこと',
                        inputType: TextInputType.multiline,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 40),
                      // 保存ボタン
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // 保存処理
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: theme.backgroundColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '保存',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
}

// 共通：丸みを帯びた四角の入力欄
class _ProfileInputField extends StatelessWidget {
  final String hintText;
  final TextInputType inputType;
  final int maxLines;
  const _ProfileInputField({
    required this.hintText,
    required this.inputType,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        keyboardType: inputType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
              color: Color(0xFF4E3B7A), fontWeight: FontWeight.bold),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// 共通：丸みを帯びた四角の選択ボックス
class _ProfileSelectBox extends StatelessWidget {
  final String hintText;
  final Widget child;
  const _ProfileSelectBox({required this.hintText, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              hintText,
              style: const TextStyle(
                  color: Color(0xFF4E3B7A), fontWeight: FontWeight.bold),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// 性別選択（ドロップダウン式、透明度のある白背景）
class _GenderDropdown extends StatefulWidget {
  @override
  State<_GenderDropdown> createState() => _GenderDropdownState();
}

class _GenderDropdownState extends State<_GenderDropdown> {
  String? _selected;
  final List<String> _genders = ['男性', '女性', '回答しない'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selected,
          hint: const Text('選択してください',
              style: TextStyle(
                  color: Color(0xFF4E3B7A), fontWeight: FontWeight.bold)),
          isExpanded: true,
          dropdownColor: Colors.white.withOpacity(0.9),
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          borderRadius: BorderRadius.circular(12),
          items: _genders
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selected = v),
        ),
      ),
    );
  }
}

// 誕生日入力ウィジェット
class _BirthdayField extends StatefulWidget {
  @override
  State<_BirthdayField> createState() => _BirthdayFieldState();
}

class _BirthdayFieldState extends State<_BirthdayField> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2000, 1, 1),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF979CDE),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF5A64ED),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _selectedDate == null
              ? '選択してください'
              : '${_selectedDate!.year}年${_selectedDate!.month}月${_selectedDate!.day}日',
          style: const TextStyle(color: Color(0xFF5A64ED), fontSize: 16),
        ),
      ),
    );
  }
}

// クレジット表記画面
class CreditScreen extends StatelessWidget {
  final AppThemePalette theme;
  const CreditScreen({super.key, required this.theme});

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
        backgroundColor: theme.backgroundColor,
        body: Column(
          children: [
            const SizedBox(height: 24),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                              color: Colors.black, fontSize: 14, height: 1.7),
                          textAlign: TextAlign.left,
                        ),
                      ),
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
}

// 履歴画面（仮）
class HistoryScreen extends StatelessWidget {
  final AppThemePalette theme;
  const HistoryScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // 右から左へのスワイプ（負の速度）でホーム画面に戻る
        if (details.primaryVelocity! < 0) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      '履歴',
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
            const Expanded(
              child: Center(
                child: Text('履歴画面（仮）', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 通知画面（仮）
class NotificationScreen extends StatelessWidget {
  final AppThemePalette theme;
  const NotificationScreen({super.key, required this.theme});

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
        backgroundColor: theme.backgroundColor,
        body: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      '通知',
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
            const Expanded(
              child: Center(
                child: Text('通知画面（仮）', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
