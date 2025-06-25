import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';

// プロフィール設定画面（iOS風のUI）
class ProfileSettingScreen extends StatefulWidget {
  final int initialThemeIndex;
  const ProfileSettingScreen({
    Key? key,
    required this.initialThemeIndex,  // ← 追加
  }) : super(key: key);

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _aiMemoController = TextEditingController();
  
  String? _selectedGender;
  DateTime? _selectedDate;
  late int _selectedThemeIndex;
  bool _isLoading = false;
  
  final List<String> _genders = ['男性', '女性', '回答しない'];

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
    _selectedThemeIndex = widget.initialThemeIndex;
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
        _selectedThemeIndex = profile.themeIndex;
      });
    }
  }

  Color get _currentThemeColor => _themeColors[_selectedThemeIndex];

  Future<void> _saveProfile() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await _userProfileService.updateProfile(
        nickname: _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim(),
        gender: _selectedGender,
        birthday: _selectedDate,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        aiMemory: _aiMemoController.text.trim().isEmpty ? null : _aiMemoController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存に失敗しました。しばらく経ってから再度お試しください。'),
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
            const Expanded(
              child: Center(
                child: Text(
                  'プロフィール設定',
                  style: TextStyle(
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
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'あなたのプロフィール',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ニックネーム
                  _ProfileInputField(
                    controller: _nicknameController,
                    hintText: 'ニックネーム',
                    inputType: TextInputType.text,
                  ),
                  const SizedBox(height: 20),
                  // 性別（選択式の丸みを帯びた四角）
                  _ProfileSelectBox(
                    hintText: '性別',
                    child: _GenderDropdown(
                      selectedGender: _selectedGender,
                      genders: _genders,
                      onChanged: (value) => setState(() => _selectedGender = value),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 誕生日
                  _ProfileSelectBox(
                    hintText: '誕生日(他の人には公開されません)',
                    child: _BirthdayField(
                      selectedDate: _selectedDate,
                      onDateSelected: (date) => setState(() => _selectedDate = date),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 自己紹介（マッチング用の一言コメント・20文字制限）
                  _ProfileInputField(
                    controller: _commentController,
                    hintText: 'みんなに一言（20文字以内）',
                    inputType: TextInputType.text,
                    maxLines: 1,
                    maxLength: 20,
                  ),
                  const SizedBox(height: 20),
                  // AIに伝えたいこと（400文字制限）
                  _ProfileInputField(
                    controller: _aiMemoController,
                    hintText: 'AIに伝えたいこと',
                    inputType: TextInputType.multiline,
                    maxLines: 4,
                    maxLength: 400,
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
                          : const Text(
                              '保存',
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
}

// 共通：丸みを帯びた四角の入力欄
class _ProfileInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType inputType;
  final int maxLines;
  final int? maxLength;
  
  const _ProfileInputField({
    required this.controller,
    required this.hintText,
    required this.inputType,
    this.maxLines = 1,
    this.maxLength,
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

  const _GenderDropdown({
    required this.selectedGender,
    required this.genders,
    required this.onChanged,
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
          hint: const Text(
            '選択してください',
            style: TextStyle(
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

  const _BirthdayField({
    required this.selectedDate,
    required this.onDateSelected,
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
              ? '選択してください'
              : '${selectedDate!.year}年${selectedDate!.month}月${selectedDate!.day}日',
          style: const TextStyle(color: Color(0xFF5A64ED), fontSize: 16),
        ),
      ),
    );
  }
}