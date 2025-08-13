import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../utils/theme_utils.dart';
import 'page_view_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final LocalizationService _localizationService = LocalizationService();
  bool _isLoading = false;
  int _selectedThemeIndex = 0;

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _localizationService.loadLanguagePreference();
    _localizationService.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _localizationService.removeListener(_onLanguageChanged);
    super.dispose();
  }
  
  // レスポンシブ対応のためのヘルパーメソッド
  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // iPadの判定（画面幅が600px以上）
    if (screenWidth >= 600) {
      // iPadの場合は基準サイズの60%に大幅縮小
      return baseSize * 0.6;
    }
    
    // 画面の高さが小さい場合も調整
    if (screenHeight < 700) {
      return baseSize * 0.75;
    }
    
    // 一般的に全体のフォントサイズを20%縮小
    return baseSize * 0.8;
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Language Toggle Button (Top Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      final newLang = _localizationService.isJapanese ? 'en' : 'ja';
                      await _localizationService.setLanguage(newLang);
                    },
                    child: Text(
                      _localizationService.isJapanese ? 'English' : '日本語',
                      style: GoogleFonts.notoSans(
                        color: Colors.white,
                        fontSize: _getResponsiveFontSize(context, 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              // ロゴとタイトル
              SizedBox(height: 40),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // アプリアイコン
                  Container(
                    width: MediaQuery.of(context).size.width >= 600 ? 80 : 100,
                    height: MediaQuery.of(context).size.width >= 600 ? 80 : 100,
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
                  const SizedBox(height: 20),
                
                // アプリ名
                Text(
                  _localizationService.translate('login_app_name'),
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: _getResponsiveFontSize(context, 36),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                
                // キャッチフレーズ
                Text(
                  _localizationService.translate('login_catchphrase'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: _getResponsiveFontSize(context, 14),
                    height: 1.3,
                  ),
                ),
              ],
              
              // サインインボタン
              SizedBox(height: 40),
              Column(
                children: [
                // Googleサインインボタン
                _buildGoogleSignInButton(),
                const SizedBox(height: 16),
                
                // Apple IDサインインボタン（iOS、Android両方で表示）
                _buildAppleSignInButton(),
                const SizedBox(height: 16),
                
                // ゲストでプレイボタン
                _buildAnonymousSignInButton(),
                const SizedBox(height: 24),
                
                // 説明テキスト
                Text(
                  _localizationService.translate('login_description'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: _getResponsiveFontSize(context, 11),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ],
          ),
        ),
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
                    _localizationService.translate('login_google_button'),
                    style: GoogleFonts.notoSans(
                      fontSize: _getResponsiveFontSize(context, 14),
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
                    _localizationService.translate('login_apple_button'),
                    style: GoogleFonts.notoSans(
                      fontSize: _getResponsiveFontSize(context, 14),
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
              _localizationService.translate('login_guest_button'),
              style: GoogleFonts.notoSans(
                fontSize: _getResponsiveFontSize(context, 14),
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
        _showSuccessMessage(_localizationService.translate('login_google_success'));
        _navigateToHome();
      } else if (mounted) {
        _showErrorMessage(_localizationService.translate('login_cancelled'));
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('${_localizationService.translate('login_failed')}: $e');
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
        _showSuccessMessage(_localizationService.translate('login_apple_success'));
        _navigateToHome();
      } else if (mounted) {
        _showErrorMessage(_localizationService.translate('login_cancelled'));
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('${_localizationService.translate('login_failed')}: $e');
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
        _showSuccessMessage(_localizationService.translate('login_guest_success'));
        _navigateToHome();
      } else if (mounted) {
        _showErrorMessage(_localizationService.translate('login_failed'));
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('${_localizationService.translate('login_failed')}: $e');
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