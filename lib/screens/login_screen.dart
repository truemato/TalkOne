import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/auth_service.dart';
import '../utils/theme_utils.dart';
import 'page_view_container.dart';
import 'privacy_compliant_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  int _selectedThemeIndex = 0;

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;
  
  // レスポンシブ対応のためのヘルパーメソッド
  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // iPadの判定（画面幅が600px以上）
    if (screenWidth >= 600) {
      // iPadの場合は基準サイズの70-80%に縮小
      return baseSize * 0.75;
    }
    
    // 画面の高さが小さい場合も調整
    if (screenHeight < 700) {
      return baseSize * 0.9;
    }
    
    return baseSize;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          // ロゴとタイトル
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // アプリアイコン
                Container(
                  width: MediaQuery.of(context).size.width >= 600 ? 90 : 120,
                  height: MediaQuery.of(context).size.width >= 600 ? 90 : 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: SvgPicture.asset(
                      'aseets/icons/Woman 1.svg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // アプリ名
                Text(
                  'TalkOne',
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: _getResponsiveFontSize(context, 48),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                
                
                // キャッチフレーズ
                Text(
                  '1対1のボイスチャットで\n会話スキルを向上させよう',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: _getResponsiveFontSize(context, 16),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          // サインインボタン
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Googleサインインボタン
                _buildGoogleSignInButton(),
                const SizedBox(height: 16),
                
                // Apple IDサインインボタン（iOS、Android両方で表示）
                _buildAppleSignInButton(),
                const SizedBox(height: 16),
                
                // プライバシー準拠ログインボタン（App Store Guideline 4.8 対応）
                _buildPrivacyCompliantSignInButton(),
                const SizedBox(height: 16),
                
                // ゲストでプレイボタン
                _buildAnonymousSignInButton(),
                const SizedBox(height: 24),
                
                // 説明テキスト
                Text(
                  'Apple ID、プライバシー保護ログイン、\nまたはGoogleでサインインすると、\n機種変更時もAIとの会話履歴が引き継がれます\n\n※メールアドレスは一切収集しません（App Store準拠）',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: _getResponsiveFontSize(context, 13),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 4,
        ),
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/google_logo.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.account_circle, size: 24);
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Googleアカウントでサインイン',
                    style: GoogleFonts.notoSans(
                      fontSize: _getResponsiveFontSize(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAppleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 4,
        ),
        onPressed: _isLoading ? null : _handleAppleSignIn,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apple, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Apple IDでサインイン',
                    style: GoogleFonts.notoSans(
                      fontSize: _getResponsiveFontSize(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPrivacyCompliantSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7), // プライバシー保護を表す紫色
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 4,
        ),
        onPressed: _isLoading ? null : _handlePrivacyCompliantSignIn,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.privacy_tip_outlined, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'プライバシー保護ログイン',
                    style: GoogleFonts.notoSans(
                      fontSize: _getResponsiveFontSize(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAnonymousSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onPressed: _isLoading ? null : _handleAnonymousSignIn,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 24),
            const SizedBox(width: 12),
            Text(
              'ゲストでプレイ',
              style: GoogleFonts.notoSans(
                fontSize: _getResponsiveFontSize(context, 12),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithGoogle();
      
      if (userCredential != null && mounted) {
        _showSuccessMessage('Googleアカウントでサインインしました');
        _navigateToHome();
      } else if (mounted) {
        _showErrorMessage('サインインがキャンセルされました');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('サインインに失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.signInWithApple();
      
      if (userCredential != null && mounted) {
        _showSuccessMessage('Apple IDでサインインしました');
        _navigateToHome();
      } else if (mounted) {
        _showErrorMessage('サインインがキャンセルされました');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('サインインに失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePrivacyCompliantSignIn() async {
    try {
      // プライバシー準拠ログイン画面に遷移
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const PrivacyCompliantLoginScreen(),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorMessage('プライバシー保護ログイン画面の表示に失敗しました: $e');
      }
    }
  }

  Future<void> _handleAnonymousSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.signInAnonymously();
      
      if (userCredential != null && mounted) {
        _showSuccessMessage('ゲストとしてサインインしました');
        _navigateToHome();
      } else if (mounted) {
        _showErrorMessage('サインインに失敗しました');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('サインインに失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
}