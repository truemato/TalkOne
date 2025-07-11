import 'package:flutter/material.dart';
import '../utils/font_size_utils.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/call_matching_service.dart';
import '../services/evaluation_service.dart';
import 'voice_call_screen.dart';
import 'matching_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PreCallProfileScreen extends StatefulWidget {
  final CallMatch match;
  
  const PreCallProfileScreen({
    super.key,
    required this.match,
  });

  @override
  State<PreCallProfileScreen> createState() => _PreCallProfileScreenState();
}

class _PreCallProfileScreenState extends State<PreCallProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _bubbleController;
  late Animation<Offset> _bubbleAnimation;
  late AnimationController _rateController;
  late Animation<int> _rateAnimation;
  
  final UserProfileService _profileService = UserProfileService();
  UserProfile? _partnerProfile;
  UserProfile? _myProfile;
  bool _isLoading = true;
  int _partnerRating = 1000; // デフォルトレーティング
  String? _myIconPath = 'aseets/icons/Woman 1.svg'; // デフォルトアイコン

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

  // HomeScreen2のStateにテーマインデックスを追加
  int _selectedThemeIndex = 0;

  // ユーザーの一言コメント用
  String _userComment = 'よろしくお願いします！';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadPartnerProfile();
    _loadMyProfile();
  }

  void _initializeAnimations() {
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
      begin: const Offset(0, 0.02),
      end: const Offset(0, -0.02),
    ).animate(CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.easeInOut,
    ));

    _rateController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _rateAnimation = IntTween(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _rateController, curve: Curves.easeOut),
    );
  }

  Future<void> _loadPartnerProfile() async {
    try {
      // 相手のプロフィールを取得
      final profile = await _getPartnerProfile(widget.match.partnerId);
      
      if (profile == null) {
        // プロフィールが存在しない場合、評価システムからレーティングを取得
        int actualRating = 1000;
        try {
          final evaluationService = EvaluationService();
          final ratingFromEvaluation = await evaluationService.getUserRating(widget.match.partnerId);
          actualRating = ratingFromEvaluation.toInt();
        } catch (e) {
          print('評価システムからのレーティング取得エラー: $e');
        }
        
        final defaultProfile = UserProfile(
          nickname: '名前をください',
          gender: '回答しない',
          themeIndex: 0,
          rating: actualRating,
        );
        
        await _saveDefaultProfileForUser(widget.match.partnerId, defaultProfile);
        
        setState(() {
          _partnerProfile = defaultProfile;
          _isLoading = false;
          _partnerRating = actualRating;
        });
        
        // レートアニメーションを更新
        _rateController.reset();
        _rateAnimation = IntTween(begin: 0, end: _partnerRating).animate(
          CurvedAnimation(parent: _rateController, curve: Curves.easeOut),
        );
        _rateController.forward();
      } else {
        // プロフィールが存在する場合、不足している値にデフォルト値を設定
        final updatedProfile = UserProfile(
          nickname: profile.nickname ?? '名前をください',
          gender: profile.gender ?? '回答しない',
          birthday: profile.birthday,
          aiMemory: profile.aiMemory,
          iconPath: profile.iconPath,
          themeIndex: profile.themeIndex,
          rating: profile.rating,
        );
        
        setState(() {
          _partnerProfile = updatedProfile;
          _isLoading = false;
          _partnerRating = profile.rating;
        });
      }
      
      // レートアニメーションを更新
      _rateController.reset();
      _rateAnimation = IntTween(begin: 0, end: _partnerRating).animate(
        CurvedAnimation(parent: _rateController, curve: Curves.easeOut),
      );
      _rateController.forward();
      
      // 自動遷移は削除し、ボタンで判断するように変更
    } catch (e) {
      print('パートナープロフィール読み込みエラー: $e');
      // エラーの場合も評価システムからレーティングを取得
      int actualRating = 1000;
      try {
        final evaluationService = EvaluationService();
        final ratingFromEvaluation = await evaluationService.getUserRating(widget.match.partnerId);
        actualRating = ratingFromEvaluation.toInt();
      } catch (e) {
        print('評価システムからのレーティング取得エラー: $e');
      }
      
      setState(() {
        _partnerProfile = UserProfile(
          nickname: '名前をください',
          gender: '回答しない',
          themeIndex: 0,
          rating: actualRating,
        );
        _isLoading = false;
        _partnerRating = actualRating;
      });
      
      // レートアニメーションを更新
      _rateController.reset();
      _rateAnimation = IntTween(begin: 0, end: _partnerRating).animate(
        CurvedAnimation(parent: _rateController, curve: Curves.easeOut),
      );
      _rateController.forward();
    }
  }

  Future<UserProfile?> _getPartnerProfile(String partnerId) async {
    try {
      // UserProfileServiceを使用して統一されたプロフィール取得
      final doc = await FirebaseFirestore.instance.collection('userProfiles').doc(partnerId).get();
      if (doc.exists) {
        final profile = UserProfile.fromMap(doc.data()!);
        
        // レーティングが1000（デフォルト）の場合、評価システムから最新値を取得
        if (profile.rating == 1000) {
          try {
            final evaluationService = EvaluationService();
            final actualRating = await evaluationService.getUserRating(partnerId);
            
            return profile.copyWith(rating: actualRating.toInt());
          } catch (e) {
            print('評価システムからのレーティング取得エラー: $e');
            return profile;
          }
        }
        
        return profile;
      }
      return null;
    } catch (e) {
      print('パートナープロフィール取得エラー: $e');
      return null;
    }
  }

  Future<void> _loadMyProfile() async {
    try {
      final profile = await _profileService.getUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _myProfile = profile;
          _myIconPath = profile.iconPath ?? 'aseets/icons/Woman 1.svg';
          // マッチング時の表示コメントは固定
          _userComment = 'よろしくお願いします！';
          // _userComment = profile.comment?.isNotEmpty == true 
          //     ? (profile.comment!.length > 20 
          //         ? profile.comment!.substring(0, 20) + '...' 
          //         : profile.comment!) 
          //     : 'よろしくお願いします！';
        });
      }
    } catch (e) {
      print('自分のプロフィール読み込みエラー: $e');
    }
  }

  Future<void> _saveDefaultProfileForUser(String userId, UserProfile profile) async {
    try {
      await FirebaseFirestore.instance.collection('userProfiles').doc(userId).set(
        profile.toMap(),
        SetOptions(merge: true),
      );
      print('デフォルトプロフィール保存成功: $userId');
    } catch (e) {
      print('デフォルトプロフィール保存エラー: $e');
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bubbleController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 背景アニメーション
          _buildBackground(),
          // メインコンテンツ
          _buildMainContent(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E3A8A).withOpacity(0.8),
              const Color(0xFF7C3AED).withOpacity(0.8),
              const Color(0xFFEC4899).withOpacity(0.8),
            ],
          ),
        ),
        child: Lottie.asset(
          _backgroundAnimations[_currentBackgroundIndex],
          fit: _backgroundFits[_currentBackgroundIndex],
          alignment: _backgroundAlignments[_currentBackgroundIndex],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Platform.isIOS
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 18.0, 24.0, 18.0), // iOS: 上下6px削減
              child: Column(
                children: [
                  // ヘッダー部分
                  _buildHeader(),
                  const SizedBox(height: 34), // iOS: 40→34
                  
                  // アイコンとプロフィール
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // アイコンアニメーション
                        _buildIconSection(),
                        const SizedBox(height: 34), // iOS: 40→34
                        
                        // プロフィール情報
                        _buildProfileInfo(),
                        const SizedBox(height: 34), // iOS: 40→34
                        
                        // コメント（16px上に移動）
                        Transform.translate(
                          offset: const Offset(0, -16), // iOS: -10→-16
                          child: _buildCommentSection(),
                        ),
                      ],
                    ),
                  ),
                  
                  // フッター（レートカウンター）
                  _buildFooter(),
                ],
              ),
            ),
          )
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // ヘッダー部分
                  _buildHeader(),
                  const SizedBox(height: 40),
                  
                  // アイコンとプロフィール
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // アイコンアニメーション
                        _buildIconSection(),
                        const SizedBox(height: 40),
                        
                        // プロフィール情報
                        _buildProfileInfo(),
                        const SizedBox(height: 40),
                        
                        // コメント（10px上に移動）
                        Transform.translate(
                          offset: const Offset(0, -10),
                          child: _buildCommentSection(),
                        ),
                      ],
                    ),
                  ),
                  
                  // フッター（レートカウンター）
                  _buildFooter(),
                ],
              ),
            ),
          );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Talk One',
          style: FontSizeUtils.caveat(
            fontSize: 40,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Text(
            _backgroundNames[_currentBackgroundIndex],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconSection() {
    return SlideTransition(
      position: _bubbleAnimation,
      child: AnimatedBuilder(
        animation: _waveAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _waveAnimation.value,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: SvgPicture.asset(
                    _partnerProfile?.iconPath ?? 'aseets/icons/Guy 1.svg',
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileInfo() {
    if (_isLoading) {
      return const Column(
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'プロフィールを読み込み中...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // ニックネーム
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                'ニックネーム',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _partnerProfile?.nickname ?? '名前をください',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // 性別
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                '性別',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _partnerProfile?.gender ?? '回答しない',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        _userComment,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // レートカウンター
        SizedBox(
          width: 100,
          height: 100, // 90から100に増やしてオーバーフローを解消
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RATE',
                style: FontSizeUtils.catamaran(
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
        ),
        const SizedBox(height: 30),
        // 承認/拒否/スキップボタン
        _buildActionButtons(),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 拒否ボタン
        ElevatedButton.icon(
          onPressed: _handleReject,
          icon: const Icon(Icons.close, color: Colors.white),
          label: Text(
            '拒否',
            style: FontSizeUtils.notoSans(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        // 承認ボタン
        ElevatedButton.icon(
          onPressed: _handleApprove,
          icon: const Icon(Icons.check, color: Colors.white),
          label: Text(
            '承認',
            style: FontSizeUtils.notoSans(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        // スキップボタン
        ElevatedButton.icon(
          onPressed: _handleSkip,
          icon: const Icon(Icons.skip_next, color: Colors.white),
          label: Text(
            'スキップ',
            style: FontSizeUtils.notoSans(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
      ],
    );
  }

  // ハンドラメソッドを追加
  void _handleReject() async {
    // マッチングを拒否してホーム画面に戻る
    try {
      // マッチングを削除
      await FirebaseFirestore.instance
          .collection('callRequests')
          .doc(widget.match.callId)
          .delete();
      
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print('マッチング拒否エラー: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _handleApprove() {
    // 承認して通話画面へ遷移
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceCallScreen(
            channelName: widget.match.channelName,
            callId: widget.match.callId,
            partnerId: widget.match.partnerId,
            conversationTheme: widget.match.conversationTheme,
          ),
        ),
      );
    }
  }

  void _handleSkip() async {
    // 現在のマッチングをスキップして新しいマッチングを探す
    try {
      // 現在のマッチングを削除
      await FirebaseFirestore.instance
          .collection('callRequests')
          .doc(widget.match.callId)
          .delete();
      
      if (mounted) {
        // マッチング画面に戻る
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MatchingScreen(),
          ),
        );
      }
    } catch (e) {
      print('マッチングスキップエラー: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildMetallicRatingText(int rating) {
    double fontSize;
    List<Color> gradientColors;
    List<Color> shadowColors;
    
    if (rating >= 4000) {
      // 金色 (4000以上)
      fontSize = 44; // 40 + 4
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
      fontSize = 42; // 40 + 2
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
      fontSize = 41; // 40 + 1
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
      fontSize = 40;
      return Text(
        '$rating',
        style: FontSizeUtils.notoSans(
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
              style: FontSizeUtils.notoSans(
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
              style: FontSizeUtils.notoSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: shadowColors[0],
              ),
            ),
          ),
          // メインテキスト
          Text(
            '$rating',
            style: FontSizeUtils.notoSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}