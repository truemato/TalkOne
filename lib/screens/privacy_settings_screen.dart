import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import '../services/privacy_compliant_auth_service.dart';
import '../utils/theme_utils.dart';
import '../utils/font_size_utils.dart';

/// プライバシー設定画面
/// App Store Guideline 4.8 準拠のプライバシー管理
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final PrivacyCompliantAuthService _authService = PrivacyCompliantAuthService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  int _selectedThemeIndex = 0;
  
  // プライバシー設定
  bool _emailVisible = false;
  bool _dataProcessingConsent = true;
  bool _advertisingConsent = false;
  String? _consentVersion;
  DateTime? _consentTimestamp;

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return;

      final settings = await _authService.getPrivacySettings(user.uid);
      
      if (settings != null && mounted) {
        setState(() {
          _emailVisible = settings['emailVisible'] ?? false;
          _dataProcessingConsent = settings['dataProcessingConsent'] ?? true;
          _advertisingConsent = settings['advertisingConsent'] ?? false;
          _consentVersion = settings['consentVersion'];
          
          // Timestampを適切に処理
          if (settings['consentTimestamp'] != null) {
            try {
              _consentTimestamp = (settings['consentTimestamp'] as dynamic).toDate();
            } catch (e) {
              print('Timestamp変換エラー: $e');
            }
          }
          
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('プライバシー設定読み込みエラー: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentThemeColor,
      appBar: AppBar(
        title: Text(
          'プライバシー設定',
          style: FontSizeUtils.notoSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Platform.isAndroid 
          ? SafeArea(child: _buildContent())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          'ログインが必要です',
          style: FontSizeUtils.notoSans(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー情報
          _buildHeaderInfo(user),
          const SizedBox(height: 32),
          
          // プライバシー設定
          _buildPrivacySettingsSection(),
          const SizedBox(height: 32),
          
          // データ収集情報
          _buildDataCollectionInfo(),
          const SizedBox(height: 32),
          
          // 同意履歴
          _buildConsentHistory(),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(User user) {
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
          Row(
            children: [
              const Icon(Icons.privacy_tip, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'App Store準拠プライバシー',
                style: FontSizeUtils.notoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow('表示名', user.displayName ?? '未設定'),
          _buildInfoRow('ユーザーID', '${user.uid.substring(0, 8)}...'),
          _buildInfoRow('メール収集', 'なし（プライバシー保護）'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: FontSizeUtils.notoSans(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: FontSizeUtils.notoSans(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettingsSection() {
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
            'プライバシー制御',
            style: FontSizeUtils.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // メール収集なしの説明
          _buildPrivacyInfo(
            title: 'メールアドレス収集なし',
            subtitle: 'App Store準拠のため、メールアドレスは一切収集していません',
            icon: Icons.privacy_tip_outlined,
            isCompliant: true,
          ),
          
          const SizedBox(height: 16),
          
          // 広告同意設定
          _buildPrivacyToggle(
            title: '広告目的でのデータ利用に同意',
            subtitle: 'オフにしても、アプリの基本機能は影響を受けません',
            value: _advertisingConsent,
            onChanged: _updateAdvertisingConsent,
            icon: Icons.ads_click_outlined,
            isOptional: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyInfo({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompliant,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompliant ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isCompliant ? Colors.green : Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: FontSizeUtils.notoSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCompliant ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isCompliant ? '準拠' : '要確認',
                        style: FontSizeUtils.notoSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: FontSizeUtils.notoSans(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyToggle({
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
    required IconData icon,
    bool isOptional = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: FontSizeUtils.notoSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isOptional)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'オプション',
                          style: FontSizeUtils.notoSans(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: FontSizeUtils.notoSans(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: (newValue) => onChanged(newValue),
            activeColor: Colors.white,
            activeTrackColor: _currentThemeColor.withOpacity(0.7),
            inactiveThumbColor: Colors.white.withOpacity(0.7),
            inactiveTrackColor: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCollectionInfo() {
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
          Row(
            children: [
              const Icon(Icons.data_usage, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                '収集データの制限',
                style: FontSizeUtils.notoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildDataItem('✓', '名前（表示名）', '設定されたニックネームのみ'),
          _buildDataItem('✗', 'メールアドレス', '一切収集しません（App Store準拠）'),
          _buildDataItem('✗', 'その他の個人情報', '一切収集しません'),
          _buildDataItem('✗', '位置情報', '収集しません'),
          _buildDataItem('✗', '連絡先', '収集しません'),
          _buildDataItem('✗', 'デバイス識別子', '広告目的では収集しません'),
          _buildDataItem('✗', '行動データ', '同意なしでは広告目的で収集しません'),
        ],
      ),
    );
  }

  Widget _buildDataItem(String status, String item, String description) {
    final isCollected = status == '✓';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isCollected ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                status,
                style: FontSizeUtils.notoSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item,
                  style: FontSizeUtils.notoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: FontSizeUtils.notoSans(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentHistory() {
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
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                '同意履歴',
                style: FontSizeUtils.notoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_consentTimestamp != null) ...[
            _buildConsentRow('初回同意日時', _formatDateTime(_consentTimestamp!)),
            _buildConsentRow('同意バージョン', _consentVersion ?? '不明'),
            _buildConsentRow('データ処理同意', _dataProcessingConsent ? '同意済み' : '未同意'),
            _buildConsentRow('メール公開設定', _emailVisible ? '公開' : '非公開'),
            _buildConsentRow('広告利用同意', _advertisingConsent ? '同意済み' : '拒否'),
          ] else ...[
            Text(
              '同意履歴がありません',
              style: FontSizeUtils.notoSans(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: FontSizeUtils.notoSans(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: FontSizeUtils.notoSans(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateEmailVisibility(bool isVisible) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final success = await _authService.updateEmailVisibility(user.uid, isVisible);
    
    if (success && mounted) {
      setState(() => _emailVisible = isVisible);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVisible 
                ? 'メールアドレスが他のユーザーに公開されます'
                : 'メールアドレスが非公開に設定されました',
            style: FontSizeUtils.notoSans(fontSize: 14),
          ),
          backgroundColor: isVisible ? Colors.orange : Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '設定の更新に失敗しました',
            style: FontSizeUtils.notoSans(fontSize: 14),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateAdvertisingConsent(bool hasConsent) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final success = await _authService.updateAdvertisingConsent(user.uid, hasConsent);
    
    if (success && mounted) {
      setState(() => _advertisingConsent = hasConsent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasConsent 
                ? '広告目的でのデータ利用に同意しました'
                : '広告目的でのデータ利用を拒否しました',
            style: FontSizeUtils.notoSans(fontSize: 14),
          ),
          backgroundColor: hasConsent ? Colors.orange : Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '設定の更新に失敗しました',
            style: FontSizeUtils.notoSans(fontSize: 14),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}