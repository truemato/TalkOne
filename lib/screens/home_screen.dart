import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'matching_screen.dart';
import 'history_screen.dart';
import 'zundamon_chat_screen.dart';
import 'settings_screen.dart';
import 'notification_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/localization_service.dart';
import '../utils/permission_util.dart';
import '../utils/theme_utils.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onNavigateToNotification;

  const HomeScreen({
    super.key,
    this.onNavigateToHistory,
    this.onNavigateToSettings,
    this.onNavigateToNotification,
  });

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
  final LocalizationService _localizationService = LocalizationService();
  int _userRating = 1000;
  String? _currentUserId;
  
  // PageView用のコントローラーとページ管理（削除）
  // late PageController _pageController;
  // int _currentPageIndex = 1; // 中央のホーム画面を初期値

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
    _localizationService.loadLanguagePreference();
    _localizationService.addListener(_onLanguageChanged);
    
    // PageControllerの初期化（削除）
    // _pageController = PageController(initialPage: 1);
    
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
    try {
      final profile = await _userProfileService.getUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _userRating = profile.rating;
          // アイコンパスとテーマインデックスも更新
          if (profile.iconPath != null) {
            _selectedIconPath = profile.iconPath;
          }
          _selectedThemeIndex = profile.themeIndex;
        });
        
        // アニメーションコントローラーが破棄されていないか確認
        if (_rateController.isCompleted || _rateController.isAnimating) {
          _rateController.reset();
        }
        
        // アニメーションを再設定
        _rateAnimation = IntTween(
          begin: _rateAnimation.value ?? 0,
          end: _userRating,
        ).animate(CurvedAnimation(
          parent: _rateController,
          curve: Curves.easeOut,
        ));
        
        _rateController.forward();
      }
    } catch (e) {
      print('Error loading user rating: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localizationService.removeListener(_onLanguageChanged);
    _waveController.dispose();
    _bubbleController.dispose();
    _rateController.dispose();
    // _pageController.dispose(); // PageControllerは削除したためコメントアウト
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
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
    // PageViewで戻ってきた時のみレーティングを更新
    if (widget.onNavigateToHistory != null || widget.onNavigateToSettings != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadUserRating();
        }
      });
    }
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
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (!mounted) return;
          
          // 右から左へのスワイプ（負の速度）で設定画面
          if (details.primaryVelocity! < -500) {
            if (widget.onNavigateToSettings != null) {
              widget.onNavigateToSettings!();
            } else {
              Navigator.of(context).push(_createSettingsRoute()).then((_) {
                if (mounted) {
                  _loadUserRating(); // 設定画面から戻った時にテーマを更新
                }
              });
            }
          }
          // 左から右へのスワイプ（正の速度）で履歴画面
          else if (details.primaryVelocity! > 500) {
            if (widget.onNavigateToHistory != null) {
              widget.onNavigateToHistory!();
            } else {
              Navigator.of(context).push(_createHistoryRoute());
            }
          }
        },
        onVerticalDragEnd: (details) {
          if (!mounted) return;
          
          // 上から下へのスワイプ（正の速度）で通知画面
          if (details.primaryVelocity! > 500) {
            if (widget.onNavigateToNotification != null) {
              widget.onNavigateToNotification!();
            } else {
              Navigator.of(context).push(_createNotificationRoute());
            }
          }
        },
        child: Stack(
          children: [
            // メインコンテンツ（SafeAreaの位置を修正）
            Positioned.fill(
              child: SafeArea(
                bottom: false, // 下部はメニューバーがあるのでfalse
                child: _buildContent(context, theme),
              ),
            ),
            // ユーザーID表示（メニューバーの上）
            Positioned(
              left: 0,
              right: 0,
              bottom: 65, // メニューバーが5px上に移動したため65に調整
              child: _buildUserIdDisplay(),
            ),
            // 下部バー（iOS風統一レイアウト）
            Positioned(
              left: 0,
              right: 0,
              bottom: 5, // 5px上に移動
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
                                if (widget.onNavigateToHistory != null) {
                                  widget.onNavigateToHistory!();
                                } else {
                                  Navigator.of(context).push(_createHistoryRoute());
                                }
                              },
                            ),
                            const SizedBox(width: 64),
                            IconButton(
                              icon: SvgPicture.asset('aseets/icons/bell.svg',
                                  width: 36, height: 36),
                              onPressed: () {
                                if (widget.onNavigateToNotification != null) {
                                  widget.onNavigateToNotification!();
                                } else {
                                  Navigator.of(context)
                                      .push(_createNotificationRoute());
                                }
                              },
                            ),
                            const SizedBox(width: 64),
                            IconButton(
                              icon: SvgPicture.asset('aseets/icons/Settings.svg',
                                  width: 29, height: 29),
                              onPressed: () async {
                                if (widget.onNavigateToSettings != null) {
                                  widget.onNavigateToSettings!();
                                  // 設定画面から戻った時にテーマを更新
                                  _loadUserRating();
                                } else {
                                  await Navigator.of(context)
                                      .push(_createSettingsRoute());
                                  // 設定画面から戻った時にテーマを更新
                                  _loadUserRating();
                                }
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
                                if (widget.onNavigateToHistory != null) {
                                  widget.onNavigateToHistory!();
                                } else {
                                  Navigator.of(context).push(_createHistoryRoute());
                                }
                              },
                            ),
                            const SizedBox(width: 64),
                            IconButton(
                              icon: SvgPicture.asset('aseets/icons/bell.svg',
                                  width: 36, height: 36),
                              onPressed: () {
                                if (widget.onNavigateToNotification != null) {
                                  widget.onNavigateToNotification!();
                                } else {
                                  Navigator.of(context)
                                      .push(_createNotificationRoute());
                                }
                              },
                            ),
                            const SizedBox(width: 64),
                            IconButton(
                              icon: SvgPicture.asset('aseets/icons/Settings.svg',
                                  width: 29, height: 29),
                              onPressed: () async {
                                if (widget.onNavigateToSettings != null) {
                                  widget.onNavigateToSettings!();
                                  // 設定画面から戻った時にテーマを更新
                                  _loadUserRating();
                                } else {
                                  await Navigator.of(context)
                                      .push(_createSettingsRoute());
                                  // 設定画面から戻った時にテーマを更新
                                  _loadUserRating();
                                }
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
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppThemePalette theme) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),
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
        SizedBox(height: screenHeight * 0.03),
        // 多段階AI救済システムの警告メッセージを表示
        if (_userRating <= 880) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _getWarningColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getWarningColor().withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  _getWarningIcon(),
                  color: _getWarningColor(),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getWarningMessage(),
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: _getWarningColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTargetMessage(),
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: _getWarningColor().withOpacity(0.8),
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
        const SizedBox(height: 32),
        _buildRateCounter(),
          ],
        ),
      ),
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
    return Column(
      children: [
        Text(
          _localizationService.translate('home_title'),
          style: GoogleFonts.caveat(
            fontSize: 60,
            color: const Color(0xFF4E3B7A),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ver 0.9.1',
          style: GoogleFonts.notoSans(
            color: const Color(0xFF4E3B7A).withOpacity(0.7),
            fontSize: 16,
            fontWeight: FontWeight.w300,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Powered By AI Gemini 2.5 Flash',
          style: GoogleFonts.notoSans(
            color: const Color(0xFF4E3B7A).withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
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
    return SizedBox(
      width: 130, // 幅を100から130に拡大
      height: 100, // 90から100に増やしてオーバーフローを解消
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
            builder: (context, child) => _buildMetallicRatingText(_rateAnimation.value),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetallicRatingText(int rating) {
    double fontSize;
    List<Color> gradientColors;
    List<Color> shadowColors;
    
    if (rating >= 4000) {
      // 金色 (4000以上)
      fontSize = 44; // 38 + 3 + 3
      gradientColors = [
        const Color(0xFFFFD700), // ゴールド
        const Color(0xFFFFA500), // オレンジゴールド
        const Color(0xFFFFD700), // ゴールド
        const Color(0xFFFFE55C), // ライトゴールド
      ];
      shadowColors = [
        Colors.black.withOpacity(0.8), // 黒い影
        Colors.black.withOpacity(0.6), // より薄い黒い影
      ];
    } else if (rating >= 3000) {
      // 銀色 (3000以上)
      fontSize = 41; // 38 + 1 + 2
      gradientColors = [
        const Color(0xFFC0C0C0), // シルバー
        const Color(0xFFE5E5E5), // ライトシルバー
        const Color(0xFFC0C0C0), // シルバー
        const Color(0xFFD3D3D3), // ライトグレー
      ];
      shadowColors = [
        Colors.black.withOpacity(0.8), // 黒い影
        Colors.black.withOpacity(0.6), // より薄い黒い影
      ];
    } else if (rating >= 2000) {
      // 銅色 (2000以上)
      fontSize = 39; // 38 + 1
      gradientColors = [
        const Color(0xFFB87333), // ブロンズ
        const Color(0xFFCD7F32), // ライトブロンズ
        const Color(0xFFB87333), // ブロンズ
        const Color(0xFFD2691E), // チョコレート
      ];
      shadowColors = [
        Colors.black.withOpacity(0.8), // 黒い影
        Colors.black.withOpacity(0.6), // より薄い黒い影
      ];
    } else {
      // 通常 (2000未満)
      fontSize = 38;
      return Text(
        '$rating',
        style: GoogleFonts.notoSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }
    
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(bounds),
      child: Stack(
        children: [
          // シャドウレイヤー (奥行き効果)
          Transform.translate(
            offset: const Offset(2, 2),
            child: Text(
              '$rating',
              style: GoogleFonts.notoSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: shadowColors[1],
              ),
            ),
          ),
          // ミドルシャドウ
          Transform.translate(
            offset: const Offset(1, 1),
            child: Text(
              '$rating',
              style: GoogleFonts.notoSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: shadowColors[0],
              ),
            ),
          ),
          // メインテキスト
          Text(
            '$rating',
            style: GoogleFonts.notoSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
      pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
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
      pageBuilder: (context, animation, secondaryAnimation) =>
          const HistoryScreen(),
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
      pageBuilder: (context, animation, secondaryAnimation) =>
          const NotificationScreen(),
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

  // 多段階AI救済システム用のヘルパーメソッド
  Color _getWarningColor() {
    if (_userRating <= 550) {
      return const Color(0xFFFF1744); // 赤色（最も深刻）
    } else if (_userRating <= 580) {
      return const Color(0xFFFF1744); // 赤色（救済中）
    } else if (_userRating <= 700) {
      return const Color(0xFFFF6D00); // 深いオレンジ（深刻）
    } else if (_userRating <= 730) {
      return const Color(0xFFFF6D00); // 深いオレンジ（救済中）
    } else if (_userRating <= 850) {
      return const Color(0xFFFF9800); // オレンジ（注意）
    } else {
      return const Color(0xFFFF9800); // オレンジ（救済中）
    }
  }

  IconData _getWarningIcon() {
    if (_userRating <= 550) {
      return Icons.warning; // 最も深刻なレベル
    } else if (_userRating <= 700) {
      return Icons.error_outline; // 中程度の警告
    } else {
      return Icons.info_outline; // 軽度の注意
    }
  }

  String _getWarningMessage() {
    if (_userRating <= 550) {
      return 'レート550以下のため、AI救済モード（レベル3）が発動中です';
    } else if (_userRating <= 580) {
      return 'AI救済モード中（レベル3）継続中です';
    } else if (_userRating <= 700) {
      return 'レート700以下のため、AI救済モード（レベル2）が発動中です';
    } else if (_userRating <= 730) {
      return 'AI救済モード中（レベル2）継続中です';
    } else if (_userRating <= 850) {
      return 'レート850以下のため、AI救済モード（レベル1）が発動中です';
    } else {
      return 'AI救済モード中（レベル1）継続中です';
    }
  }

  String _getTargetMessage() {
    if (_userRating <= 580) {
      return 'レート580を超えると次の段階に進みます';
    } else if (_userRating <= 730) {
      return 'レート730を超えると次の段階に進みます';
    } else {
      return 'レート880を超えると人間との通話に戻ります';
    }
  }

}