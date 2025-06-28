import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'matching_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import 'settings_screens.dart';

class HomeScreen2 extends StatefulWidget {
  const HomeScreen2({super.key});

  @override
  State<HomeScreen2> createState() => _HomeScreen2State();
}

class _HomeScreen2State extends State<HomeScreen2>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _bubbleController;
  late Animation<Offset> _bubbleAnimation;
  late AnimationController _rateController;
  late Animation<int> _rateAnimation;

  // 背景アニメーションの状態管理
  int _currentBackgroundIndex = 0;
  final List<String> _backgroundAnimations = [
    'aseets/animations/background_animation(sunrise).json',
    'aseets/animations/background_animation(train).json',
    'aseets/animations/background_animation(river).json',
  ];
  final List<String> _backgroundNames = [
    '日の出',
    '電車',
    '川',
  ];

  // 背景アニメーションの表示設定
  final List<BoxFit> _backgroundFits = [
    BoxFit.cover,
    BoxFit.cover,
    BoxFit.cover,
  ];

  final List<Alignment> _backgroundAlignments = [
    Alignment.center,
    Alignment.center,
    Alignment.center,
  ];

  // アイコンアニメーション
  final String _iconAnimation = 'aseets/animations/icon_animation(boy).json';

  // AIアイコンのSVGパス
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  final List<String> _svgIcons = [
    'aseets/icons/Guy 1.svg',
    'aseets/icons/Guy 2.svg',
    'aseets/icons/Guy 3.svg',
    'aseets/icons/Guy 4.svg',
    'aseets/icons/Woman 1.svg',
    'aseets/icons/Woman 2.svg',
    'aseets/icons/Woman 3.svg',
    'aseets/icons/Woman 4.svg',
    'aseets/icons/Woman 5.svg',
  ];

  // HomeScreen2のStateにテーマインデックスを追加
  int _selectedThemeIndex = 0;

  // コメント候補リストを追加
  final List<String> _randomComments = [
    'こんにちは〜。今日もがんばってるね！',
    'おつかれさま。ひといきつこ〜',
    '今日はどんなアイディアが浮かんでる？',
    'ご主人、AIが遊びたがっております〜！',
  ];
  late String _selectedComment;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));

    _bubbleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _bubbleAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -0.1),
    ).animate(CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.easeInOut,
    ));

    _rateController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _rateAnimation = IntTween(
      begin: 0,
      end: 429,
    ).animate(CurvedAnimation(
      parent: _rateController,
      curve: Curves.easeOut,
    ));

    _rateController.forward();
    _selectedComment = (_randomComments..shuffle()).first;
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bubbleController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  // 背景を切り替えるメソッド
  void _switchBackground() {
    setState(() {
      _currentBackgroundIndex =
          (_currentBackgroundIndex + 1) % _backgroundAnimations.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppThemePalette theme = appThemes[_selectedThemeIndex];
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        children: [
          SafeArea(child: Center(child: _buildContent(context, theme))),
          // 下部バー
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Platform.isAndroid
                ? SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    bottom: true,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.barColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: SvgPicture.asset('aseets/icons/ber_Icon.svg',
                                width: 32, height: 32),
                            onPressed: () {
                              Navigator.of(context).push(_createHistoryRoute());
                            },
                          ),
                          const SizedBox(width: 64),
                          IconButton(
                            icon: SvgPicture.asset('aseets/icons/bell.svg',
                                width: 36, height: 36),
                            onPressed: () {
                              Navigator.of(context)
                                  .push(_createNotificationRoute());
                            },
                          ),
                          const SizedBox(width: 64),
                          IconButton(
                            icon: SvgPicture.asset('aseets/icons/Settings.svg',
                                width: 29, height: 29),
                            onPressed: () {
                              Navigator.of(context)
                                  .push(_createSettingsRoute());
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.barColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: SvgPicture.asset('aseets/icons/ber_Icon.svg',
                              width: 32, height: 32),
                          onPressed: () {
                            Navigator.of(context).push(_createHistoryRoute());
                          },
                        ),
                        const SizedBox(width: 64),
                        IconButton(
                          icon: SvgPicture.asset('aseets/icons/bell.svg',
                              width: 36, height: 36),
                          onPressed: () {
                            Navigator.of(context)
                                .push(_createNotificationRoute());
                          },
                        ),
                        const SizedBox(width: 64),
                        IconButton(
                          icon: SvgPicture.asset('aseets/icons/Settings.svg',
                              width: 29, height: 29),
                          onPressed: () {
                            Navigator.of(context).push(_createSettingsRoute());
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppThemePalette theme) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Column(
      children: [
        const SizedBox(height: 40),
        _buildTitle(),
        SizedBox(height: screenHeight * 0.20),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _buildAiIcon(),
              // 編集ボタンをAIアイコンの右下に重ねる
              Positioned(
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: FloatingActionButton(
                    backgroundColor: const Color(0xFFAD98E1),
                    onPressed: _showIconSelectDialog,
                    elevation: 2,
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 18),
                  ),
                ),
              ),
              Positioned(
                top: -110,
                right: -160,
                child: _buildSpeechBubble(),
              ),
            ],
          ),
        ),
        SizedBox(height: screenHeight * 0.05),
        _buildAICallButton(theme),
        const SizedBox(height: 16),
        _buildRateCounter(),
      ],
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

  Widget _buildSpeechBubble() {
    return SlideTransition(
      position: _bubbleAnimation,
      child: SizedBox(
        width: 220,
        height: 110,
        child: Stack(
          children: [
            // メッセージ部分
            Positioned(
              left: 3,
              top: 8,
              child: Container(
                width: 168,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    _selectedComment,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'Cascadia Mono',
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // 雲の部分（上）
            Positioned(
              left: 24,
              top: 63,
              child: Container(
                width: 37,
                height: 19,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            // 雲の部分（下）
            Positioned(
              left: 24,
              top: 87,
              child: Container(
                width: 24,
                height: 19,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E0F9),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: _selectedIconPath == null
            ? Lottie.asset(
                _iconAnimation,
                fit: BoxFit.cover,
                repeat: true,
                alignment: Alignment.center,
              )
            : SvgPicture.asset(
                _selectedIconPath!,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildRateCounter() {
    return SizedBox(
      width: 100,
      height: 90,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'RATE',
            style: GoogleFonts.catamaran(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _rateAnimation,
            builder: (context, child) => Text(
              '${_rateAnimation.value}',
              style: GoogleFonts.notoSans(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAICallButton(AppThemePalette theme) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MatchingScreen(),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.callIconColor,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      child: const Icon(
        Icons.phone,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  // アイコン選択ダイアログ
  void _showIconSelectDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('アイコンを選択'),
          content: SizedBox(
            width: 300,
            height: 200,
            child: GridView.count(
              crossAxisCount: 3,
              children: _svgIcons.map((iconPath) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(iconPath),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SvgPicture.asset(iconPath),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (selected != null) {
      setState(() {
        _selectedIconPath = selected;
      });
    }
  }

  // 設定画面へのスライド遷移
  Route _createSettingsRoute() {
    final theme = appThemes[_selectedThemeIndex];
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(
        currentThemeIndex: _selectedThemeIndex,
        onThemeChanged: (int newIndex) {
          setState(() {
            _selectedThemeIndex = newIndex;
          });
        },
        theme: theme,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // 履歴画面へのスライド遷移
  Route _createHistoryRoute() {
    final theme = appThemes[_selectedThemeIndex];
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          HistoryScreen(theme: theme),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // 通知画面へのスライド遷移
  Route _createNotificationRoute() {
    final theme = appThemes[_selectedThemeIndex];
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          NotificationScreen(theme: theme),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, -1.0);
        const end = Offset.zero;
        const curve = Curves.ease;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}
