import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/auth_service.dart';
import '../utils/theme_utils.dart';
import 'page_view_container.dart';

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
                  width: 120,
                  height: 120,
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
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                
                // バージョン情報
                Text(
                  'Ver 0.6',
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                
                // キャッチフレーズ
                Text(
                  '1対1のボイスチャットで\n会話スキルを向上させよう',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
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
                
                // Apple IDサインインボタン（iOSのみ）
                if (Platform.isIOS) ...[
                  _buildAppleSignInButton(),
                  const SizedBox(height: 16),
                ],
                
                // ゲストでプレイボタン
                _buildAnonymousSignInButton(),
                const SizedBox(height: 24),
                
                // 説明テキスト
                Text(
                  Platform.isIOS 
                    ? 'GoogleまたはApple IDでサインインすると、\n機種変更時もAIとの会話履歴が\n引き継がれます'
                    : 'Googleアカウントでサインインすると、\n機種変更時もAIとの会話履歴が\n引き継がれます',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
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
                      fontSize: 16,
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
                      fontSize: 16,
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
                fontSize: 16,
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