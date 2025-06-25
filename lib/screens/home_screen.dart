import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'matching_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'zundamon_chat_screen.dart';
import 'settings_screen.dart';
import 'notification_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../utils/permission_util.dart';
import '../utils/theme_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _bubbleController;
  late Animation<Offset> _bubbleAnimation;
  late AnimationController _rateController;
  late Animation<int> _rateAnimation;

  final UserProfileService _userProfileService = UserProfileService();
  int _userRating = 1000;
  String? _currentUserId;

  // 背景アニメーションの状態管理
  int _currentBackgroundIndex = 0;
  final List<String> _backgroundAnimations = [
    'aseets/animations/background_animation(river).json',
  ];
  final List<String> _backgroundNames = [
    '川',
  ];

  // 背景アニメーションの表示設定
  final List<BoxFit> _backgroundFits = [
    BoxFit.cover,
  ];

  final List<Alignment> _backgroundAlignments = [
    Alignment.center,
  ];

  // AIアイコンのSVGパス
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  final List<String> _svgIcons = [
    'aseets/icons/Woman 1.svg',
    'aseets/icons/Woman 2.svg',
    'aseets/icons/Woman 3.svg',
    'aseets/icons/Guy 1.svg',
    'aseets/icons/Guy 3.svg',
    'aseets/icons/Guy 4.svg',
  ];

  // HomeScreenのStateにテーマインデックスを追加
  int _selectedThemeIndex = 0;

  // コメント候補リストを追加
  final List<String> _randomComments = [
    'こんにちは〜\n今日もがんばってるね！',
    'おつかれさま\nひと息つこ〜',
    '今どんなアイディアが\n浮かんでる?',
  ];
  late String _selectedComment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserRating();
    
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
      end: _userRating,
    ).animate(CurvedAnimation(
      parent: _rateController,
      curve: Curves.easeOut,
    ));

    _rateController.forward();
    _selectedComment = (_randomComments..shuffle()).first;
  }

  Future<void> _loadUserRating() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _userRating = profile.rating;
        _rateAnimation = IntTween(
          begin: 0,
          end: _userRating,
        ).animate(CurvedAnimation(
          parent: _rateController,
          curve: Curves.easeOut,
        ));
        // アイコンパスとテーマインデックスも更新
        if (profile.iconPath != null) {
          _selectedIconPath = profile.iconPath;
        }
        _selectedThemeIndex = profile.themeIndex;
      });
      _rateController.reset();
      _rateController.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waveController.dispose();
    _bubbleController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  // 画面復帰時にレーティングを更新
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadUserRating();
    }
  }

  // ウィジェットツリー復帰時にレーティングを更新  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 他の画面から戻ってきた時にレーティングを更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserRating();
    });
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
    final AppThemePalette theme = getAppTheme(_selectedThemeIndex);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: theme.backgroundColor)),
          SafeArea(child: Center(child: _buildContent(context, theme))),
          // ユーザーID表示（メニューバーの上）
          Positioned(
            left: 0,
            right: 0,
            bottom: 60, // メニューバーの高さ分上に配置
            child: _buildUserIdDisplay(),
          ),
          // 下部バー（iOS風統一レイアウト）
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
                        border: Border(
                          top: BorderSide(color: theme.barColor, width: 1),
                          left: BorderSide(color: theme.barColor, width: 1),
                          right: BorderSide(color: theme.barColor, width: 1),
                        ),
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
                            onPressed: () async {
                              await Navigator.of(context)
                                  .push(_createSettingsRoute());
                              // 設定画面から戻った時にテーマを更新
                              _loadUserRating();
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: theme.barColor, // 背景全体をメニューバーの色で埋める
                    ),
                    child: SafeArea(
                      top: false,
                      left: false,
                      right: false,
                      bottom: true,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.barColor,
                          border: Border(
                            top: BorderSide(color: theme.barColor, width: 1),
                            left: BorderSide(color: theme.barColor, width: 1),
                            right: BorderSide(color: theme.barColor, width: 1),
                          ),
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
                            onPressed: () async {
                              await Navigator.of(context).push(_createSettingsRoute());
                              // 設定画面から戻った時にテーマを更新
                              _loadUserRating();
                            },
                          ),
                        ],
                      ),
                    ),
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
        SizedBox(height: screenHeight * 0.15),
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
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 18),
                    elevation: 2,
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
        // レート850以下の場合、警告メッセージを表示
        if (_userRating <= 850) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.1), // オレンジ系の背景
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'レート850以下のため、通話相手はAI（ずんだもん）になります',
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: const Color(0xFFFF9800),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'レート880を超えると人間との通話に戻ります',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: const Color(0xFFFF9800).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildAICallButton(theme),
        const SizedBox(height: 16),
        _buildZundamonButton(theme),
        const SizedBox(height: 16),
        _buildRateCounter(),
      ],
    );
  }

  Widget _buildUserIdDisplay() {
    if (_currentUserId == null) return const SizedBox.shrink();
    
    // UserIDの最初の8文字と最後の4文字を表示
    final shortId = _currentUserId!.length > 8 
        ? '${_currentUserId!.substring(0, 4)}...${_currentUserId!.substring(_currentUserId!.length - 4)}'
        : _currentUserId!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: Text(
          'User: $shortId',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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
      child: Container(
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
      width: 120, // 100から120に拡大（1.2倍）
      height: 120, // 100から120に拡大（1.2倍）
      decoration: const BoxDecoration(
        color: Color(0xFFE2E0F9),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: SvgPicture.asset(
          _selectedIconPath!,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildRateCounter() {
    return Container(
      width: 130, // 幅を100から130に拡大
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
                fontSize: 38,
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


  Widget _buildZundamonButton(AppThemePalette theme) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ZundamonChatScreen(),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF81C784), // ずんだもんカラー（薄緑）
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(16),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      child: const Icon(
        Icons.smart_toy,
        color: Colors.white,
        size: 28,
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
              childAspectRatio: 1.0,
              children: _svgIcons.map((iconPath) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(iconPath),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
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
      // アイコンをFirebaseに保存
      await _userProfileService.updateIconPath(selected);
    }
  }

  // 設定画面へのスライド遷移
  Route _createSettingsRoute() {
    return PageRouteBuilder(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => SettingsScreen(initialThemeIndex: _selectedThemeIndex),
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
    return PageRouteBuilder(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          HistoryScreen(initialThemeIndex: _selectedThemeIndex),
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
    return PageRouteBuilder(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          NotificationScreen(initialThemeIndex: _selectedThemeIndex),
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