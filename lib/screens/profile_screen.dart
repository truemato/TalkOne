import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';

class ProfileScreen extends StatefulWidget {
  final int initialThemeIndex;
  const ProfileScreen({Key? key,required this.initialThemeIndex,}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  
  // フォームのコントローラー
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _aiMemoryController = TextEditingController();
  // 選択項目
  String? _selectedGender;
  DateTime? _selectedBirthday;
  
  // テーマカラー
  final List<Color> _themeColors = [
    const Color(0xFF5A64ED), // 青紫
    const Color(0xFFE91E63), // ピンク
    const Color(0xFF4CAF50), // 緑
    const Color(0xFFFF9800), // オレンジ
    const Color(0xFF9C27B0), // 紫
  ];
  late int _selectedThemeIndex;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedThemeIndex = widget.initialThemeIndex;
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _aiMemoryController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      // 有効な性別値のリスト
      const validGenders = ['male', 'female', 'other'];
      
      setState(() {
        _nicknameController.text = profile.nickname ?? '';
        // 性別が有効な値でない場合はnullに設定
        _selectedGender = validGenders.contains(profile.gender) ? profile.gender : null;
        _selectedBirthday = profile.birthday;
        _aiMemoryController.text = profile.aiMemory ?? '';
        _selectedThemeIndex = profile.themeIndex ?? 0;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await _userProfileService.updateProfile(
        nickname: _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim(),
        gender: _selectedGender,
        birthday: _selectedBirthday,
        aiMemory: _aiMemoryController.text.trim().isEmpty ? null : _aiMemoryController.text.trim(),
        themeIndex: _selectedThemeIndex, // 現在のテーマカラーを保持
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '保存しました',
              style: GoogleFonts.notoSans(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '保存に失敗しました。しばらく経ってから再度お試しください。',
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

  Color get _currentThemeColor => _themeColors[_selectedThemeIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentThemeColor,
      body: Stack(
        children: [
          // 最下層：テーマ色で全画面を塗りつぶし
          Positioned.fill(
            child: Container(color: _currentThemeColor),
          ),
          // メインコンテンツ
          Platform.isAndroid
              ? SafeArea(child: _buildContent())
              : _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // ヘッダー
        _buildHeader(),
        
        // コンテンツ
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ニックネーム
                _buildInputField(
                  controller: _nicknameController,
                  hintText: 'ニックネーム',
                ),
                const SizedBox(height: 20),
                
                // 性別
                _buildGenderSelector(),
                const SizedBox(height: 20),
                
                // 誕生日
                _buildBirthdaySelector(),
                const SizedBox(height: 20),
                
                // AIに覚えておいてほしいこと
                _buildInputField(
                  controller: _aiMemoryController,
                  hintText: 'AIに覚えておいてほしいこと',
                  maxLines: 3,
                ),
                const SizedBox(height: 40),
                
                // 保存ボタン
                _buildSaveButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                'プロフィール設定',
                style: GoogleFonts.notoSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }



  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.notoSans(color: Colors.black),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.notoSans(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    // 有効なgender値のリスト
    const validGenders = ['male', 'female', 'other'];
    
    // もし現在の値が有効でない場合はnullに設定
    final currentGender = validGenders.contains(_selectedGender) ? _selectedGender : null;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<String>(
        value: currentGender,
        decoration: InputDecoration(
          hintText: '性別',
          hintStyle: GoogleFonts.notoSans(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: const [
          DropdownMenuItem(value: 'male', child: Text('男性')),
          DropdownMenuItem(value: 'female', child: Text('女性')),
          DropdownMenuItem(value: 'other', child: Text('その他')),
        ],
        onChanged: (value) {
          setState(() {
            _selectedGender = value;
          });
        },
      ),
    );
  }

  Widget _buildBirthdaySelector() {
    return GestureDetector(
      onTap: _selectBirthday,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedBirthday != null
                    ? '${_selectedBirthday!.year}年${_selectedBirthday!.month}月${_selectedBirthday!.day}日'
                    : '誕生日',
                style: GoogleFonts.notoSans(
                  color: _selectedBirthday != null ? Colors.black : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.9),
            foregroundColor: _currentThemeColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 4,
          ),
          onPressed: _isLoading ? null : _saveProfile,
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  '保存',
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }


  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }
}