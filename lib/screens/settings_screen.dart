import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/rating_service.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'profile_setting_screen.dart';
import 'credit_screen.dart';
import 'login_screen.dart';
import '../utils/theme_utils.dart';
import '../utils/font_size_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  final AuthService _authService = AuthService();
  final LocalizationService _localizationService = LocalizationService();
  int _selectedThemeIndex = 0;
  int _currentRating = 1000;
  bool _isDeleting = false;
  
  // デバッグ機能（実績ポップアップ連続タップ）
  int _achievementTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserRating();
    _localizationService.loadLanguagePreference();
    _localizationService.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _localizationService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
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
                _localizationService.translate('settings_rate_requirement_not_met'),
                style: FontSizeUtils.notoSans(fontSize: 16, color: Colors.white),
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
      if (_currentRating < 5000) {
        // レート5000以上でないと解禁されない
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _localizationService.translate('settings_rate_requirement_not_met'),
                style: FontSizeUtils.notoSans(fontSize: 16, color: Colors.white),
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
            _localizationService.translate('settings_agent_changed').replaceAll('{characterName}', characterName),
            style: FontSizeUtils.notoSans(fontSize: 16, color: Colors.white),
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
        'level': _localizationService.translate('settings_achievement_hall_of_fame'),
        'color': const Color(0xFFFFD700), // ゴールド
        'description': _localizationService.translate('settings_all_features_unlocked'),
        'unlocked': _localizationService.translate('settings_all_features_unlocked'),
        'progress': 1.0,
        'nextTarget': null,
      };
    } else if (_currentRating >= 4000) {
      return {
        'level': _localizationService.translate('settings_achievement_gold'),
        'color': const Color(0xFFFFD700), // ゴールド
        'description': _localizationService.translate('settings_voicevox_unlocked'),
        'unlocked': _localizationService.translate('settings_voicevox_unlocked'),
        'progress': (_currentRating - 4000) / 1000.0,
        'nextTarget': 5000,
      };
    } else if (_currentRating >= 3000) {
      return {
        'level': _localizationService.translate('settings_achievement_silver'),
        'color': const Color(0xFFC0C0C0), // シルバー
        'description': _localizationService.translate('settings_voicevox_unlocked'),
        'unlocked': _localizationService.translate('settings_voicevox_unlocked'),
        'progress': (_currentRating - 3000) / 1000.0,
        'nextTarget': 4000,
      };
    } else if (_currentRating >= 2000) {
      return {
        'level': _localizationService.translate('settings_achievement_bronze'),
        'color': const Color(0xFFCD7F32), // 銅色
        'description': _localizationService.translate('settings_voicevox_unlocked'),
        'unlocked': _localizationService.translate('settings_voicevox_unlocked'),
        'progress': (_currentRating - 2000) / 1000.0,
        'nextTarget': 3000,
      };
    } else if (_currentRating >= 1500) {
      return {
        'level': _localizationService.translate('settings_achievement_bronze'),
        'color': const Color(0xFFCD7F32), // 銅色
        'description': _localizationService.translate('settings_voicevox_unlocked'),
        'unlocked': _localizationService.translate('settings_voicevox_unlocked'),
        'progress': (_currentRating - 1500) / 500.0,
        'nextTarget': 2000,
      };
    } else {
      return {
        'level': _localizationService.translate('settings_achievement_beginner'),
        'color': Colors.grey,
        'description': _localizationService.translate('settings_voicevox_requirement'),
        'unlocked': _localizationService.translate('settings_basic_features_only'),
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
          style: FontSizeUtils.notoSans(fontSize: 16, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '現在のレーティング: $_currentRating',
              style: FontSizeUtils.notoSans(fontSize: 16, color: Colors.white70),
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
              style: FontSizeUtils.notoSans(fontSize: 16, color: Colors.white70),
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
                      style: FontSizeUtils.notoSans(fontSize: 16, color: Colors.white),
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
                      style: FontSizeUtils.notoSans(fontSize: 16, color: Colors.white),
                    ),
                    backgroundColor: Colors.red.shade600,
                  ),
                );
              }
            },
            child: Text(
              'OK',
              style: FontSizeUtils.notoSans(fontSize: 16, color: Colors.blue),
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
  
  // 現在のレベルとレーティングを1行で表示
  Widget _buildCurrentStatusRow() {
    final achievement = _achievementInfo;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Colors.white.withOpacity(0.1),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 現在のレベル
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: achievement['color'],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    achievement['level'],
                    style: FontSizeUtils.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: achievement['color'],
                    ),
                  ),
                ],
              ),
              // レーティング
              Text(
                _localizationService.translate('settings_current_rating').replaceAll('{rating}', '$_currentRating'),
                style: FontSizeUtils.notoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                Text(
                  _localizationService.translate('settings_achievement_section'),
                  style: FontSizeUtils.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 16),
              
              // プログレスバー
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (achievement['nextTarget'] != null) ...[
                    Text(
                      _localizationService.translate('settings_next_target').replaceAll('{target}', '${achievement['nextTarget']}'),
                      style: FontSizeUtils.notoSans(
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
                      _localizationService.translate('settings_points_remaining').replaceAll('{points}', '${achievement['nextTarget'] - _currentRating}'),
                      style: FontSizeUtils.notoSans(
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
                      _localizationService.translate('settings_unlocked_features').replaceAll('{features}', achievement['unlocked']),
                      style: FontSizeUtils.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement['description'],
                      style: FontSizeUtils.notoSans(
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
                    _localizationService.translate('settings_achievement_list'),
                    style: FontSizeUtils.notoSans(
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
                          _buildLevelRow('1500', _localizationService.translate('achievement_bronze'), _localizationService.translate('achievement_voicevox_unlocked'), Colors.grey),
                          _buildLevelRow('2000', _localizationService.translate('achievement_copper'), _localizationService.translate('achievement_voicevox_unlocked'), const Color(0xFFCD7F32)),
                          _buildLevelRow('3000', _localizationService.translate('achievement_silver'), _localizationService.translate('achievement_voicevox_unlocked'), const Color(0xFFC0C0C0)),
                          _buildLevelRow('4000', _localizationService.translate('achievement_gold'), _localizationService.translate('achievement_voicevox_unlocked'), const Color(0xFFFFD700)),
                          _buildLevelRow('5000', _localizationService.translate('achievement_hall_of_fame'), _localizationService.translate('achievement_all_features_unlocked'), const Color(0xFFFFD700)),
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
              style: FontSizeUtils.notoSans(
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
              _localizationService.translate('settings_title'),
              style: FontSizeUtils.notoSans(
                fontSize: 18,
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
              // 言語設定
              ListTile(
                leading: const Icon(Icons.language, color: Colors.white),
                title: Text(
                  _localizationService.translate('settings_language'),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Row(
                  children: [
                    // 日本語
                    GestureDetector(
                      onTap: () => _localizationService.setLanguage('ja'),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _localizationService.isJapanese 
                              ? Colors.blue.shade600 
                              : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Text(
                          _localizationService.translate('settings_language_japanese'),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    // 英語
                    GestureDetector(
                      onTap: () => _localizationService.setLanguage('en'),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _localizationService.isEnglish 
                              ? Colors.blue.shade600 
                              : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Text(
                          _localizationService.translate('settings_language_english'),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // テーマカラー選択
              ListTile(
                leading: const Icon(Icons.color_lens, color: Colors.white),
                title: Text(
                  _localizationService.translate('settings_theme'),
                  style: const TextStyle(color: Colors.white),
                ),
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
                title: Text(_localizationService.translate('settings_voice_character'), style: const TextStyle(color: Colors.white)),
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
                title: Text(
                  _localizationService.translate('settings_profile'),
                  style: const TextStyle(color: Colors.white),
                ),
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
                title: Text(
                  _localizationService.translate('settings_credits'),
                  style: const TextStyle(color: Colors.white),
                ),
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
              // 現在のレベルとレーティング表示（1行）
              _buildCurrentStatusRow(),
              
              // 実績セクション
              _buildAchievementSection(),
              
              const Divider(color: Colors.white24, height: 32),
              
              // アカウント削除
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(_localizationService.translate('settings_delete_account'), style: const TextStyle(color: Colors.red)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 16),
                onTap: _isDeleting ? null : _showDeleteAccountDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Future<void> _showDeleteAccountDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          _localizationService.translate('delete_account_title'),
          style: FontSizeUtils.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          _localizationService.translate('settings_delete_account_confirm'),
          style: FontSizeUtils.notoSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              _localizationService.translate('cancel'),
              style: FontSizeUtils.notoSans(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              _localizationService.translate('settings_delete_account_button'),
              style: FontSizeUtils.notoSans(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteAccount();
    }
  }
  
  Future<void> _deleteAccount() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final user = FirebaseAuth.instance.currentUser;
      
      if (userId == null || user == null) {
        throw Exception('ユーザーが認証されていません');
      }

      print('🗑️ ユーザーデータ削除開始: $userId');
      
      // 1. マッチングリクエストの削除（最初に実行）
      print('📱 マッチングリクエスト削除中...');
      final matchingRequests = await FirebaseFirestore.instance
          .collection('matchingRequests')
          .where('userId', isEqualTo: userId)
          .get();
      
      final matchingBatch = FirebaseFirestore.instance.batch();
      for (final doc in matchingRequests.docs) {
        matchingBatch.delete(doc.reference);
        print('🔥 マッチングリクエスト削除: ${doc.id}');
      }
      if (matchingRequests.docs.isNotEmpty) {
        await matchingBatch.commit();
        print('✅ マッチングリクエスト削除完了: ${matchingRequests.docs.length}件');
      }
      
      // 2. 評価データの削除
      print('⭐ 評価データ削除中...');
      final evaluations = await FirebaseFirestore.instance
          .collection('evaluations')
          .where('evaluatorId', isEqualTo: userId)
          .get();
      
      final evaluationBatch = FirebaseFirestore.instance.batch();
      for (final doc in evaluations.docs) {
        evaluationBatch.delete(doc.reference);
        print('🔥 評価データ削除: ${doc.id}');
      }
      
      // 自分への評価も削除
      final evaluationsToMe = await FirebaseFirestore.instance
          .collection('evaluations')
          .where('evaluatedUserId', isEqualTo: userId)
          .get();
      
      for (final doc in evaluationsToMe.docs) {
        evaluationBatch.delete(doc.reference);
        print('🔥 自分への評価削除: ${doc.id}');
      }
      
      if (evaluations.docs.isNotEmpty || evaluationsToMe.docs.isNotEmpty) {
        await evaluationBatch.commit();
        print('✅ 評価データ削除完了: ${evaluations.docs.length + evaluationsToMe.docs.length}件');
      }
      
      // 3. メインユーザーデータの削除
      print('👤 メインユーザーデータ削除中...');
      final batch = FirebaseFirestore.instance.batch();
      
      // userProfiles削除
      batch.delete(FirebaseFirestore.instance.collection('userProfiles').doc(userId));
      print('🔥 userProfiles削除予約');
      
      // userRatings削除
      batch.delete(FirebaseFirestore.instance.collection('userRatings').doc(userId));
      print('🔥 userRatings削除予約');
      
      // 4. サブコレクション削除
      print('📚 サブコレクション削除中...');
      
      // callHistoriesサブコレクション削除
      final callHistories = await FirebaseFirestore.instance
          .collection('callHistories')
          .doc(userId)
          .collection('calls')
          .get();
      
      for (final doc in callHistories.docs) {
        batch.delete(doc.reference);
      }
      print('🔥 通話履歴削除予約: ${callHistories.docs.length}件');
      
      // conversationLogsサブコレクション削除
      final conversationLogs = await FirebaseFirestore.instance
          .collection('conversationLogs')
          .doc(userId)
          .collection('logs')
          .get();
          
      for (final doc in conversationLogs.docs) {
        batch.delete(doc.reference);
      }
      print('🔥 会話ログ削除予約: ${conversationLogs.docs.length}件');
      
      // blockedUsersサブコレクション削除
      final blockedUsers = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('blockedUsers')
          .get();
          
      for (final doc in blockedUsers.docs) {
        batch.delete(doc.reference);
      }
      print('🔥 ブロックユーザーリスト削除予約: ${blockedUsers.docs.length}件');
      
      // 通報データ削除
      final reports = await FirebaseFirestore.instance
          .collection('reports')
          .where('reporterId', isEqualTo: userId)
          .get();
          
      for (final doc in reports.docs) {
        batch.delete(doc.reference);
      }
      print('🔥 通報データ削除予約: ${reports.docs.length}件');
      
      // 5. 親ドキュメント削除（callHistories, conversationLogs, users）
      batch.delete(FirebaseFirestore.instance.collection('callHistories').doc(userId));
      batch.delete(FirebaseFirestore.instance.collection('conversationLogs').doc(userId));
      batch.delete(FirebaseFirestore.instance.collection('users').doc(userId));
      print('🔥 親ドキュメント削除予約');
      
      // バッチ実行
      print('💾 メインバッチ実行中...');
      await batch.commit();
      print('✅ メインユーザーデータ削除完了');
      
      // 6. Firebase Auth アカウント削除（再認証付き）
      print('🔐 Firebase Auth アカウント削除中...');
      
      try {
        // Googleアカウントの場合は再認証が必要な場合がある
        if (_authService.isGoogleSignedIn) {
          print('🔄 Google再認証を試行中...');
          try {
            final googleUser = await GoogleSignIn().signInSilently();
            if (googleUser != null) {
              final googleAuth = await googleUser.authentication;
              final credential = GoogleAuthProvider.credential(
                accessToken: googleAuth.accessToken,
                idToken: googleAuth.idToken,
              );
              await user.reauthenticateWithCredential(credential);
              print('✅ Google再認証成功');
            }
          } catch (e) {
            print('⚠️ Google再認証スキップ: $e');
          }
        }
        
        // アカウント削除実行
        await user.delete();
        print('✅ Firebase Authアカウント削除完了');
        
        // 最後にサインアウト（念のため）
        await _authService.signOut();
        print('✅ サインアウト完了');
        
      } catch (e) {
        print('⚠️ Firebase Authアカウント削除エラー: $e');
        // Firebase Authの削除に失敗してもFirestoreデータは削除済みなのでサインアウトする
        await _authService.signOut();
        print('✅ データ削除完了、サインアウト実行');
      }
      
      if (mounted) {
        // 成功メッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'お使いのGoogle/Appleアカウントのアプリケーション内情報を削除しました。',
              style: FontSizeUtils.notoSans(fontSize: 14),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // ログイン画面に戻る
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('アカウント削除エラー: $e');
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'アカウントの削除に失敗しました。再度お試しください。',
              style: FontSizeUtils.notoSans(fontSize: 14),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}