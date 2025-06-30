import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/rating_service.dart';
import 'profile_setting_screen.dart';
import 'credit_screen.dart';
import '../utils/theme_utils.dart';

// 設定画面本体
class SettingsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  
  const SettingsScreen({super.key, this.onNavigateToHome});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final RatingService _ratingService = RatingService();
  int _selectedThemeIndex = 0;
  int _currentRating = 1000;
  
  // デバッグ機能（実績ポップアップ連続タップ）
  int _achievementTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserRating();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedThemeIndex = profile.themeIndex;
      });
    }
  }

  Future<void> _loadUserRating() async {
    final ratingData = await _ratingService.getRatingData();
    if (mounted) {
      setState(() {
        _currentRating = ratingData.currentRating;
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

  void _selectVoicePersonality(int personalityId) async {
    // ペルソナID対応表とレート条件
    const personalityData = [
      {'name': '春日部つむぎ', 'minRate': 4000},     // 0: さくら（ピンク）
      {'name': 'ずんだもん', 'minRate': 2000},       // 1: りん（緑）
      {'name': '四国めたん', 'minRate': 1500},       // 2: みお（青）
      {'name': '雨晴はう', 'minRate': 0},            // 3: ゆい（オレンジ） - 制限なし
      {'name': '青山龍星', 'minRate': 3000},         // 4: あかり（紫）
    ];
    
    // 冥鳴ひまりの特殊条件（レート700以下）をチェック
    bool isHimariUnlocked = false;
    String characterName = '';
    
    if (personalityId < personalityData.length) {
      characterName = personalityData[personalityId]['name'] as String;
      final minRate = personalityData[personalityId]['minRate'] as int;
      
      // レート条件をチェック
      if (_currentRating < minRate) {
        // レート条件を満たしていない
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'レートの条件を満たしてください。',
                style: GoogleFonts.notoSans(color: Colors.white),
              ),
              backgroundColor: Colors.red.shade600,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    } else if (personalityId == 5) {
      // 冥鳴ひまり（ID: 5）の特殊条件
      characterName = '冥鳴ひまり';
      if (_currentRating > 700) {
        // レート700以下でないと解禁されない
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'レートの条件を満たしてください。',
                style: GoogleFonts.notoSans(color: Colors.white),
              ),
              backgroundColor: Colors.red.shade600,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      isHimariUnlocked = true;
    }
    
    // VOICEVOX設定を無効化し、デフォルトのSTT/TTS機能を使用
    final useVoicevox = false;
    
    // ペルソナIDと音声合成設定を保存
    await _userProfileService.updateProfile(
      useVoicevox: useVoicevox,
      aiPersonalityId: personalityId,
    );
    
    // 成功メッセージを表示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'エージェントを${characterName}に変更しました。',
            style: GoogleFonts.notoSans(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  AppThemePalette get _currentTheme => getAppTheme(_selectedThemeIndex);

  // 実績レベルを取得
  Map<String, dynamic> get _achievementInfo {
    if (_currentRating >= 5000) {
      return {
        'level': '殿堂入り',
        'color': const Color(0xFFFFD700), // ゴールド
        'description': 'すべての機能が解禁されています',
        'unlocked': 'すべての機能解禁',
        'progress': 1.0,
        'nextTarget': null,
      };
    } else if (_currentRating >= 4000) {
      return {
        'level': '金メダル',
        'color': const Color(0xFFFFD700), // ゴールド
        'description': 'VOICEVOX機能が解禁されています',
        'unlocked': 'VOICEVOX解禁',
        'progress': (_currentRating - 4000) / 1000.0,
        'nextTarget': 5000,
      };
    } else if (_currentRating >= 3000) {
      return {
        'level': '銀メダル',
        'color': const Color(0xFFC0C0C0), // シルバー
        'description': 'VOICEVOX機能が解禁されています',
        'unlocked': 'VOICEVOX解禁',
        'progress': (_currentRating - 3000) / 1000.0,
        'nextTarget': 4000,
      };
    } else if (_currentRating >= 2000) {
      return {
        'level': '銅メダル',
        'color': const Color(0xFFCD7F32), // 銅色
        'description': 'VOICEVOX機能が解禁されています',
        'unlocked': 'VOICEVOX解禁',
        'progress': (_currentRating - 2000) / 1000.0,
        'nextTarget': 3000,
      };
    } else if (_currentRating >= 1500) {
      return {
        'level': 'ブロンズ',
        'color': const Color(0xFFCD7F32), // 銅色
        'description': 'VOICEVOX機能が解禁されています',
        'unlocked': 'VOICEVOX解禁',
        'progress': (_currentRating - 1500) / 500.0,
        'nextTarget': 2000,
      };
    } else {
      return {
        'level': 'ビギナー',
        'color': Colors.grey,
        'description': 'レーティング1500以上でVOICEVOX解禁',
        'unlocked': '基本機能のみ',
        'progress': _currentRating / 1500.0,
        'nextTarget': 1500,
      };
    }
  }

  // デバッグ用レーティング変更ダイアログ
  void _showRatingChangeDialog() {
    final TextEditingController ratingController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'デバッグ: レーティング変更',
          style: GoogleFonts.notoSans(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '現在のレーティング: $_currentRating',
              style: GoogleFonts.notoSans(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ratingController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '新しいレーティング (0-5000)',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white70),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'キャンセル',
              style: GoogleFonts.notoSans(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newRating = int.tryParse(ratingController.text);
              if (newRating != null && newRating >= 0 && newRating <= 5000) {
                // レーティングを変更
                await _ratingService.setRating(newRating);
                setState(() {
                  _currentRating = newRating;
                });
                
                Navigator.of(context).pop();
                
                // 成功メッセージ
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'レーティングを$newRatingに変更しました',
                      style: GoogleFonts.notoSans(color: Colors.white),
                    ),
                    backgroundColor: Colors.green.shade600,
                  ),
                );
                
                // ホーム画面に戻る
                if (widget.onNavigateToHome != null) {
                  widget.onNavigateToHome!();
                } else {
                  Navigator.of(context).pop();
                }
              } else {
                // エラーメッセージ
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '0から5000の間の数値を入力してください',
                      style: GoogleFonts.notoSans(color: Colors.white),
                    ),
                    backgroundColor: Colors.red.shade600,
                  ),
                );
              }
            },
            child: Text(
              'OK',
              style: GoogleFonts.notoSans(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
  
  // 実績セクションタップ処理
  void _onAchievementTap() {
    final now = DateTime.now();
    
    // 10秒以内の連続タップかチェック
    if (_lastTapTime == null || now.difference(_lastTapTime!).inSeconds > 10) {
      _achievementTapCount = 1;
    } else {
      _achievementTapCount++;
    }
    
    _lastTapTime = now;
    
    print('実績タップ: $_achievementTapCount回目');
    
    // 10回連続タップでデバッグダイアログ表示
    if (_achievementTapCount >= 10) {
      _achievementTapCount = 0;
      _showRatingChangeDialog();
    }
  }
  
  // 実績セクションを構築
  Widget _buildAchievementSection() {
    final achievement = _achievementInfo;
    
    return GestureDetector(
      onTap: _onAchievementTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          color: Colors.white.withOpacity(0.1),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: achievement['color'],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '実績',
                      style: GoogleFonts.notoSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              
              // 現在のレベル表示
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '現在のレベル: ${achievement['level']}',
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: achievement['color'],
                    ),
                  ),
                  Text(
                    'レーティング: $_currentRating',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // プログレスバー
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (achievement['nextTarget'] != null) ...[
                    Text(
                      '次の目標: ${achievement['nextTarget']}',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: achievement['progress'],
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(achievement['color']),
                      minHeight: 8,
                    ),
                  ),
                  if (achievement['nextTarget'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '残り${achievement['nextTarget'] - _currentRating}ポイント',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              
              // 解禁機能
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '解禁機能: ${achievement['unlocked']}',
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement['description'],
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
                // 実績レベル説明
                const SizedBox(height: 16),
                ExpansionTile(
                  title: Text(
                    '実績レベル一覧',
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white70,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _buildLevelRow('1500', 'ブロンズ', 'VOICEVOX解禁', Colors.grey),
                          _buildLevelRow('2000', '銅メダル', 'VOICEVOX解禁', const Color(0xFFCD7F32)),
                          _buildLevelRow('3000', '銀メダル', 'VOICEVOX解禁', const Color(0xFFC0C0C0)),
                          _buildLevelRow('4000', '金メダル', 'VOICEVOX解禁', const Color(0xFFFFD700)),
                          _buildLevelRow('5000', '殿堂入り', 'すべての機能解禁', const Color(0xFFFFD700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelRow(String rating, String level, String feature, Color color) {
    final isAchieved = _currentRating >= int.parse(rating);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isAchieved ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isAchieved ? color : Colors.white30,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$rating: $level - $feature',
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: isAchieved ? Colors.white : Colors.white60,
                fontWeight: isAchieved ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // 左から右へのスワイプ（正の速度）でホーム画面に戻る
        if (details.primaryVelocity! > 0 && mounted) {
          if (widget.onNavigateToHome != null) {
            widget.onNavigateToHome!();
          } else {
            Navigator.of(context).pop();
          }
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
              onPressed: () {
                if (widget.onNavigateToHome != null) {
                  widget.onNavigateToHome!();
                } else {
                  Navigator.of(context).pop();
                }
              },
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
                    // 1番目: 四国めたん（赤）- レート1500以上
                    GestureDetector(
                      onTap: () => _selectVoicePersonality(2),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.face, color: Colors.white, size: 20),
                      ),
                    ),
                    // 2番目: ずんだもん（緑）- レート2000以上
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
                    // 3番目: 青山龍星（青）- レート3000以上
                    GestureDetector(
                      onTap: () => _selectVoicePersonality(4),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.face, color: Colors.white, size: 20),
                      ),
                    ),
                    // 4番目: 春日部つむぎ（オレンジ）- レート4000以上
                    GestureDetector(
                      onTap: () => _selectVoicePersonality(0),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade500,
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.face, color: Colors.white, size: 20),
                      ),
                    ),
                    // 5番目: 冥鳴ひまり（紫）- レート700以下
                    GestureDetector(
                      onTap: () => _selectVoicePersonality(5),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade700,
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
              // 実績セクション
              _buildAchievementSection(),
            ],
          ),
        ),
      ],
    );
  }
}