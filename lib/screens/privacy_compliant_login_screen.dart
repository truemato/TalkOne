import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import '../services/privacy_compliant_auth_service.dart';
import '../utils/theme_utils.dart';
import 'page_view_container.dart';

/// App Store Guideline 4.8 準拠のプライバシー保護ログイン画面
class PrivacyCompliantLoginScreen extends StatefulWidget {
  const PrivacyCompliantLoginScreen({super.key});

  @override
  State<PrivacyCompliantLoginScreen> createState() => _PrivacyCompliantLoginScreenState();
}

class _PrivacyCompliantLoginScreenState extends State<PrivacyCompliantLoginScreen> {
  final PrivacyCompliantAuthService _authService = PrivacyCompliantAuthService();
  final _formKey = GlobalKey<FormState>();
  
  // フォーム入力用コントローラー
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  // 状態管理
  bool _isLoading = false;
  bool _isSignUpMode = true; // サインアップ/サインインの切り替え
  int _selectedThemeIndex = 0;
  
  // プライバシー設定（App Store要件対応）
  bool _emailVisibilityConsent = false; // メール非公開設定
  bool _dataProcessingConsent = false; // データ処理同意（必須）
  bool _advertisingConsent = false; // 広告同意（オプション）

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentThemeColor,
      body: Platform.isAndroid 
          ? SafeArea(child: _buildContent())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // タイトル部分
            _buildTitle(),
            const SizedBox(height: 40),
            
            // サインアップ/サインイン切り替え
            _buildModeToggle(),
            const SizedBox(height: 32),
            
            // 入力フォーム
            _buildInputFields(),
            const SizedBox(height: 24),
            
            // プライバシー設定（サインアップ時のみ）
            if (_isSignUpMode) ...[
              _buildPrivacySettings(),
              const SizedBox(height: 24),
            ],
            
            // ログインボタン
            _buildSubmitButton(),
            const SizedBox(height: 16),
            
            // プライバシーポリシーリンク
            _buildPrivacyPolicyLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'プライバシー保護ログイン',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'メールアドレス収集なし\nApp Store Guideline 4.8準拠',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSans(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSignUpMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isSignUpMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'サインアップ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: _isSignUpMode ? _currentThemeColor : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSignUpMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isSignUpMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'サインイン',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: !_isSignUpMode ? _currentThemeColor : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        // 表示名（サインアップ時のみ）
        if (_isSignUpMode) ...[
          _buildTextField(
            controller: _displayNameController,
            label: '表示名',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '表示名を入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],
        
        // メールアドレス
        _buildTextField(
          controller: _emailController,
          label: 'メールアドレス',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'メールアドレスを入力してください';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return '有効なメールアドレスを入力してください';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        // パスワード
        _buildTextField(
          controller: _passwordController,
          label: 'パスワード',
          icon: Icons.lock_outline,
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'パスワードを入力してください';
            }
            if (_isSignUpMode && value.length < 6) {
              return 'パスワードは6文字以上で入力してください';
            }
            return null;
          },
        ),
        
        // パスワード確認（サインアップ時のみ）
        if (_isSignUpMode) ...[
          const SizedBox(height: 16),
          _buildTextField(
            controller: _confirmPasswordController,
            label: 'パスワード確認',
            icon: Icons.lock_outline,
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'パスワード確認を入力してください';
              }
              if (value != _passwordController.text) {
                return 'パスワードが一致しません';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.notoSans(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.notoSans(color: Colors.white.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildPrivacySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'プライバシー設定（App Store準拠）',
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // データ処理同意（必須）
          _buildConsentCheckbox(
            value: _dataProcessingConsent,
            onChanged: (value) => setState(() => _dataProcessingConsent = value!),
            title: 'データ処理への同意（必須）',
            subtitle: '名前のみを収集・処理することに同意します（メールアドレスは収集しません）',
            isRequired: true,
          ),
          
          // プライバシー保護の説明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.privacy_tip, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'メールアドレスは一切収集しません（App Store準拠）',
                    style: GoogleFonts.notoSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 広告同意（オプション）
          _buildConsentCheckbox(
            value: _advertisingConsent,
            onChanged: (value) => setState(() => _advertisingConsent = value!),
            title: '広告目的での行動データ利用への同意（オプション）',
            subtitle: 'チェックしない場合、アプリ内行動データは広告目的で一切使用されません',
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    required String subtitle,
    required bool isRequired,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            checkColor: _currentThemeColor,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.notoSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '必須',
                            style: GoogleFonts.notoSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.notoSans(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _currentThemeColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 4,
        ),
        onPressed: _isLoading ? null : _handleSubmit,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _isSignUpMode ? 'プライバシー保護アカウント作成' : 'サインイン',
                style: GoogleFonts.notoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildPrivacyPolicyLink() {
    return TextButton(
      onPressed: () {
        // プライバシーポリシー画面への遷移
        _showPrivacyPolicyDialog();
      },
      child: Text(
        'プライバシーポリシーを確認する',
        style: GoogleFonts.notoSans(
          color: Colors.white.withOpacity(0.8),
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // サインアップ時の必須同意確認
    if (_isSignUpMode && !_dataProcessingConsent) {
      _showErrorMessage('データ処理への同意が必要です');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential? userCredential;
      
      if (_isSignUpMode) {
        // プライバシー準拠サインアップ
        userCredential = await _authService.signInWithPrivacyCompliance(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          emailVisibilityConsent: _emailVisibilityConsent,
          dataProcessingConsent: _dataProcessingConsent,
          advertisingConsentOptional: _advertisingConsent,
        );
      } else {
        // 既存ユーザーサインイン
        userCredential = await _authService.signInWithPrivacyComplianceExisting(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (userCredential != null && mounted) {
        _showSuccessMessage(_isSignUpMode 
            ? 'プライバシー保護アカウントを作成しました' 
            : 'サインインしました');
        _navigateToHome();
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('${_isSignUpMode ? "アカウント作成" : "サインイン"}に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const PageViewContainer(),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.notoSans(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.notoSans(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'プライバシーポリシー',
          style: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            '''TalkOneのプライバシー保護ログインについて：

データ収集の制限：
• 収集するデータは「お名前」と「メールアドレス」のみです
• その他の個人情報は一切収集しません

メールアドレスの非公開設定：
• アカウント設定でメールアドレスを他のユーザーに対して非公開にできます
• デフォルトでは非公開に設定されています

広告目的でのデータ利用：
• ユーザーの明示的な同意なしに、アプリとのやり取りを広告目的で収集することはありません
• 広告同意はオプションであり、拒否してもアプリの利用に影響はありません

このログイン方式はApp Store Guideline 4.8に完全準拠しており、Sign in with Appleと同等のプライバシー保護を提供します。''',
            style: GoogleFonts.notoSans(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '確認',
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.bold,
                color: _currentThemeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}