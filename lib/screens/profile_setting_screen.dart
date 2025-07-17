import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_profile_service.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../utils/validation_util.dart';
import 'login_screen.dart';

// プロフィール設定画面（iOS風のUI）
class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({super.key});

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final AuthService _authService = AuthService();
  final LocalizationService _localizationService = LocalizationService();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _aiMemoController = TextEditingController();
  
  String? _selectedGender;
  DateTime? _selectedDate;
  int _selectedThemeIndex = 0;
  bool _isLoading = false;
  
  List<String> get _genders => [
    _localizationService.translate('profile_gender_male'),
    _localizationService.translate('profile_gender_female'),
    _localizationService.translate('profile_gender_not_specified'),
  ];

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
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _commentController.dispose();
    _aiMemoController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _nicknameController.text = profile.nickname ?? '';
        _selectedGender = profile.gender;
        _selectedDate = profile.birthday;
        _commentController.text = profile.comment ?? '';
        _aiMemoController.text = profile.aiMemory ?? '';
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

  Future<void> _saveProfile() async {
    if (_isLoading) return;
    
    // バリデーション
    final nicknameValidation = ValidationUtil.validateNickname(_nicknameController.text);
    if (!nicknameValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nicknameValidation.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final commentValidation = ValidationUtil.validateComment(_commentController.text);
    if (!commentValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(commentValidation.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final aiMemoryValidation = ValidationUtil.validateAiMemory(_aiMemoController.text);
    if (!aiMemoryValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(aiMemoryValidation.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 入力値をサニタイズしてから保存
      await _userProfileService.updateProfile(
        nickname: _nicknameController.text.trim().isEmpty ? null : ValidationUtil.sanitizeInput(_nicknameController.text),
        gender: _selectedGender,
        birthday: _selectedDate,
        comment: _commentController.text.trim().isEmpty ? null : ValidationUtil.sanitizeInput(_commentController.text),
        aiMemory: _aiMemoController.text.trim().isEmpty ? null : ValidationUtil.sanitizeInput(_aiMemoController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localizationService.translate('profile_save_success')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localizationService.translate('profile_save_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                  _localizationService.translate('profile_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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
                  // アカウント情報セクション
                  _buildAccountSection(),
                  const SizedBox(height: 32),
                  
                  Text(
                    _localizationService.translate('profile_title'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ニックネーム
                  _ProfileInputField(
                    controller: _nicknameController,
                    hintText: _localizationService.translate('profile_nickname'),
                    inputType: TextInputType.text,
                    inputFormatters: ValidationUtil.getNicknameFormatters(),
                  ),
                  const SizedBox(height: 20),
                  // 性別（選択式の丸みを帯びた四角）
                  _ProfileSelectBox(
                    hintText: _localizationService.translate('profile_gender'),
                    child: _GenderDropdown(
                      selectedGender: _selectedGender,
                      genders: _genders,
                      onChanged: (value) => setState(() => _selectedGender = value),
                      localizationService: _localizationService,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 誕生日
                  _ProfileSelectBox(
                    hintText: _localizationService.translate('profile_birthday'),
                    child: _BirthdayField(
                      selectedDate: _selectedDate,
                      onDateSelected: (date) => setState(() => _selectedDate = date),
                      localizationService: _localizationService,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 自己紹介（マッチング用の一言コメント・20文字制限）
                  Text(
                    _localizationService.translate('profile_comment'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ProfileInputField(
                    controller: _commentController,
                    hintText: _localizationService.translate('profile_comment'),
                    inputType: TextInputType.text,
                    maxLines: 1,
                    maxLength: 20,
                    inputFormatters: ValidationUtil.getCommentFormatters(),
                  ),
                  const SizedBox(height: 20),
                  // AIに伝えたいこと（400文字制限）
                  Text(
                    _localizationService.translate('profile_ai_memory'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ProfileInputField(
                    controller: _aiMemoController,
                    hintText: _localizationService.translate('profile_ai_memory'),
                    inputType: TextInputType.multiline,
                    maxLines: 4,
                    maxLength: 400,
                    inputFormatters: ValidationUtil.getAiMemoryFormatters(),
                  ),
                  const SizedBox(height: 40),
                  // 保存ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _currentThemeColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _localizationService.translate('save'),
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
    );
  }

  // アカウント情報セクションを構築
  Widget _buildAccountSection() {
    final user = _authService.currentUser;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _localizationService.translate('profile_account_info'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_authService.isAppleSignedIn) ...[
                // Apple IDでサインイン済み
                Row(
                  children: [
                    const Icon(Icons.apple, color: Colors.black, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _localizationService.translate('profile_apple_account'),
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? _localizationService.translate('profile_sign_in_with_apple'),
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _localizationService.translate('profile_data_transfer_message'),
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSignOutButton(),
              ] else if (_authService.isGoogleSignedIn) ...[
                // Googleアカウントでサインイン済み
                Row(
                  children: [
                    const Icon(Icons.account_circle, color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _localizationService.translate('profile_google_account'),
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _localizationService.translate('profile_data_transfer_message'),
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSignOutButton(),
              ] else if (_authService.isAnonymous) ...[
                // 匿名アカウント
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _localizationService.translate('profile_guest_account'),
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _localizationService.translate('profile_data_loss_warning'),
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildUpgradeToGoogleButton(),
                const SizedBox(height: 8),
                _buildUpgradeToAppleButton(),
                const SizedBox(height: 8),
                _buildSignOutButton(),
              ] else ...[
                // サインインしていない（通常は発生しない）
                Text(
                  _localizationService.translate('profile_sign_in_required'),
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Googleアカウントにアップグレードボタン
  Widget _buildUpgradeToGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: _isLoading ? null : _handleUpgradeToGoogle,
        icon: const Icon(Icons.upgrade, size: 20),
        label: Text(
          _localizationService.translate('profile_upgrade_to_google'),
          style: GoogleFonts.notoSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // サインアウトボタン
  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red[600],
          side: BorderSide(color: Colors.red[600]!, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onPressed: _isLoading ? null : _handleSignOut,
        icon: const Icon(Icons.logout, size: 18),
        label: Text(
          _localizationService.translate('profile_sign_out'),
          style: GoogleFonts.notoSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Googleアカウントへのアップグレード処理
  Future<void> _handleUpgradeToGoogle() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔐 Googleアカウントアップグレード開始');
      
      // 現在のユーザー状態確認
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || !currentUser.isAnonymous) {
        throw Exception('匿名ユーザーではありません');
      }
      
      print('👤 匿名ユーザー確認: ${currentUser.uid}');
      
      final userCredential = await _authService.linkAnonymousWithGoogle().timeout(
        const Duration(seconds: 45), // タイムアウト時間を延長
        onTimeout: () {
          print('⏰ Google Sign In タイムアウト');
          throw TimeoutException('Google Sign In timeout', const Duration(seconds: 45));
        },
      );
      
      print('📱 Google Sign In 結果: ${userCredential != null}');
      
      if (userCredential != null && mounted) {
        print('✅ Googleアカウントアップグレード成功');
        
        // アップグレード成功後、少し待ってからUI更新
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Googleアカウントへのアップグレードが完了しました',
                style: GoogleFonts.notoSans(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {}); // UIを更新
        }
      } else if (mounted) {
        print('⚠️ Googleアカウントアップグレードキャンセル');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'アップグレードがキャンセルされました',
              style: GoogleFonts.notoSans(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Googleアカウントアップグレードエラー: $e');
      print('📍 スタックトレース: $stackTrace');
      
      if (mounted) {
        String errorMessage = 'アップグレードに失敗しました';
        
        // エラー種別による詳細メッセージ
        if (e is TimeoutException) {
          errorMessage = 'ログインがタイムアウトしました。ネットワーク接続を確認して再度お試しください。';
        } else if (e.toString().contains('SIGN_IN_CANCELLED') || 
                   e.toString().contains('cancelled') ||
                   e.toString().contains('canceled')) {
          errorMessage = 'ログインがキャンセルされました';
        } else if (e.toString().contains('network')) {
          errorMessage = 'ネットワークエラーが発生しました。接続を確認してください。';
        } else if (e.toString().contains('account-exists-with-different-credential')) {
          errorMessage = 'このGoogleアカウントは既に別の方法で登録されています。';
        } else if (e.toString().contains('credential-already-in-use')) {
          errorMessage = 'この認証情報は既に使用されています。';
        } else {
          // 一般的なエラーメッセージ（詳細は開発者のみ表示）
          final shortError = e.toString().length > 50 ? 
            e.toString().substring(0, 50) + '...' : e.toString();
          errorMessage = 'ログインに失敗しました。しばらく経ってから再度お試しください。';
          print('詳細エラー: $shortError');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.notoSans(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // 必ずローディング状態を解除
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('🔚 Googleアカウントアップグレード処理完了');
    }
  }

  // Apple IDにアップグレードボタン
  Widget _buildUpgradeToAppleButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(Icons.apple),
        onPressed: _isLoading ? null : _handleUpgradeToApple,
        label: Text(
          'Apple IDにアップグレード',
          style: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Apple IDへのアップグレード処理
  Future<void> _handleUpgradeToApple() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Apple Sign Inではリンクができないため、データを保持して再サインイン
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _localizationService.translate('profile_apple_upgrade_preparing'),
            style: GoogleFonts.notoSans(color: Colors.white),
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // サインアウト処理
  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _localizationService.translate('profile_sign_out_title'),
          style: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${_localizationService.translate('profile_sign_out_message')}\n${_authService.isAnonymous ? _localizationService.translate('profile_sign_out_guest_warning') : ''}',
          style: GoogleFonts.notoSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              _localizationService.translate('cancel'),
              style: GoogleFonts.notoSans(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              _localizationService.translate('profile_sign_out'),
              style: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_localizationService.translate('profile_sign_out_failed')}$e',
                style: GoogleFonts.notoSans(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}

// 共通：丸みを帯びた四角の入力欄
class _ProfileInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType inputType;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  
  const _ProfileInputField({
    required this.controller,
    required this.hintText,
    required this.inputType,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        maxLines: maxLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF4E3B7A),
            fontWeight: FontWeight.bold,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          counterText: maxLength != null ? '' : null, // Hide counter text
        ),
      ),
    );
  }
}

// 共通：丸みを帯びた四角の選択ボックス
class _ProfileSelectBox extends StatelessWidget {
  final String hintText;
  final Widget child;
  
  const _ProfileSelectBox({
    required this.hintText,
    required this.child,
  });
  
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
                color: Color(0xFF4E3B7A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// 性別選択（ドロップダウン式、透明度のある白背景）
class _GenderDropdown extends StatelessWidget {
  final String? selectedGender;
  final List<String> genders;
  final ValueChanged<String?> onChanged;
  final LocalizationService localizationService;

  const _GenderDropdown({
    required this.selectedGender,
    required this.genders,
    required this.onChanged,
    required this.localizationService,
  });

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
          value: selectedGender,
          hint: Text(
            localizationService.translate('profile_gender_select_hint'),
            style: const TextStyle(
              color: Color(0xFF4E3B7A),
              fontWeight: FontWeight.bold,
            ),
          ),
          isExpanded: true,
          dropdownColor: Colors.white.withOpacity(0.9),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          borderRadius: BorderRadius.circular(12),
          items: genders
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// 誕生日入力ウィジェット
class _BirthdayField extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onDateSelected;
  final LocalizationService localizationService;

  const _BirthdayField({
    required this.selectedDate,
    required this.onDateSelected,
    required this.localizationService,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime(2000, 1, 1),
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
          onDateSelected(picked);
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
          selectedDate == null
              ? localizationService.translate('profile_birthday_select_hint')
              : '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}',
          style: const TextStyle(color: Color(0xFF5A64ED), fontSize: 16),
        ),
      ),
    );
  }
}