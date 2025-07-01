import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../utils/theme_utils.dart';
import '../services/rating_service.dart';
import '../services/evaluation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rematch_or_home_screen.dart';

class PartnerProfileScreen extends StatefulWidget {
  final String partnerId;
  final String callId;
  final bool isDummyMatch;
  final bool showReportButton;

  const PartnerProfileScreen({
    super.key,
    required this.partnerId,
    required this.callId,
    this.isDummyMatch = false,
    this.showReportButton = false,
  });

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final RatingService _ratingService = RatingService();
  final EvaluationService _evaluationService = EvaluationService();
  
  // パートナー情報
  String? _partnerNickname = 'ずんだもん';
  String? _partnerGender = '回答しない';
  String? _partnerComment = 'よろしくお願いします！'; // ダミー
  String? _partnerIconPath = 'aseets/icons/Woman 1.svg';
  int _partnerThemeIndex = 0;
  bool _isLoading = true;
  bool _isReporting = false;

  @override
  void initState() {
    super.initState();
    _loadPartnerProfile();
  }

  Future<void> _loadPartnerProfile() async {
    try {
      // 相手の実際のプロフィールをFirebaseから取得
      final profile = await _userProfileService.getUserProfileById(widget.partnerId);
      
      if (profile != null && mounted) {
        setState(() {
          _partnerNickname = profile.nickname ?? 'ユーザー';
          _partnerGender = profile.gender ?? '未設定';
          _partnerComment = profile.comment ?? 'よろしくお願いします！';
          _partnerIconPath = profile.iconPath ?? 'aseets/icons/Woman 1.svg';
          _partnerThemeIndex = profile.themeIndex ?? 0;
          // テーマインデックスが範囲外の場合はデフォルトに設定
          if (_partnerThemeIndex >= themeCount) {
            _partnerThemeIndex = 0;
          }
          _isLoading = false;
        });
        print('相手のプロフィール読み込み完了: ${profile.nickname}');
      } else {
        // プロフィールが見つからない場合はデフォルト値を設定
        if (mounted) {
          setState(() {
            _partnerNickname = 'ユーザー';
            _partnerGender = '未設定';
            _partnerComment = 'よろしくお願いします！';
            _partnerIconPath = 'aseets/icons/Woman 1.svg';
            _partnerThemeIndex = 0;
            _isLoading = false;
          });
        }
        print('相手のプロフィールが見つかりません: ${widget.partnerId}');
      }
    } catch (e) {
      print('パートナープロフィール読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _partnerNickname = 'ユーザー';
          _partnerGender = '未設定';
          _partnerComment = 'よろしくお願いします！';
          _partnerIconPath = 'aseets/icons/Woman 1.svg';
          _partnerThemeIndex = 0;
          _isLoading = false;
        });
      }
    }
  }

  Color get _currentThemeColor => getAppTheme(_partnerThemeIndex).backgroundColor;

  // 通報機能
  Future<void> _showReportDialog() async {
    String selectedReason = '不適切な発言';
    String details = '';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '相手を通報',
            style: GoogleFonts.notoSans(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '通報理由を選択してください',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              
              // 通報理由選択
              ...['不適切な発言', '嫌がらせ', 'スパム行為', 'その他'].map((reason) =>
                RadioListTile<String>(
                  title: Text(
                    reason,
                    style: GoogleFonts.notoSans(fontSize: 14),
                  ),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) => setState(() => selectedReason = value!),
                  dense: true,
                ),
              ),
              
              const SizedBox(height: 16),
              Text(
                '詳細（任意）',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: '具体的な内容を記入してください',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
                onChanged: (value) => details = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'キャンセル',
                style: GoogleFonts.notoSans(
                  color: Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '通報する',
                style: GoogleFonts.notoSans(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _submitReport(selectedReason, details);
    }
  }

  Future<void> _submitReport(String reason, String details) async {
    setState(() {
      _isReporting = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('ユーザーが認証されていません');

      // 通報データをFirestoreに保存
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': userId,
        'reportedUserId': widget.partnerId,
        'callId': widget.callId,
        'reason': reason,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // 相手に星1評価を自動送信
      await _evaluationService.submitEvaluation(
        callId: widget.callId,
        partnerId: widget.partnerId,
        rating: 1,
        isDummyMatch: widget.isDummyMatch,
      );

      // 相手のレーティングを更新
      await _ratingService.updateRating(1, widget.partnerId);

      if (mounted) {
        // 通報完了メッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '通報を送信しました。24時間以内にサポートからのメールをお送りいたします。',
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        // RematchOrHomeScreenに遷移
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const RematchOrHomeScreen(),
          ),
        );
      }
    } catch (e) {
      print('通報送信エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '通報の送信に失敗しました。しばらく経ってから再度お試しください。',
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReporting = false;
        });
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    final currentTheme = getAppTheme(_partnerThemeIndex);
    return Scaffold(
      backgroundColor: currentTheme.backgroundColor, // 相手のテーマカラーを使用
      body: Platform.isAndroid 
          ? SafeArea(child: _buildContent())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

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
                // プロフィール画像
                _buildProfileIcon(),
                const SizedBox(height: 32),
                
                // ニックネーム
                _buildInfoField('ニックネーム', _partnerNickname ?? 'ユーザー'),
                const SizedBox(height: 20),
                
                // 性別
                _buildInfoField('性別', _partnerGender ?? '未設定'),
                const SizedBox(height: 20),
                
                // 一言コメント
                _buildInfoField('一言コメント', _partnerComment ?? 'よろしくお願いします！'),
                const SizedBox(height: 40),
                
                // 通報ボタン（評価画面からの遷移時のみ表示）
                if (widget.showReportButton)
                  _buildReportButton(),
                
                // ブロックボタン（履歴画面からの遷移時は表示）
                if (!widget.showReportButton)
                  _buildBlockButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
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
                  '相手のプロフィール',
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
      ),
    );
  }

  Widget _buildProfileIcon() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: SvgPicture.asset(
                _partnerIconPath!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _partnerNickname ?? 'ユーザー',
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            value,
            style: GoogleFonts.notoSans(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      child: ElevatedButton(
        onPressed: _isReporting ? null : _showReportDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isReporting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '通報送信中...',
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.report, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'この相手を通報する',
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ブロック機能
  Future<void> _showBlockDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'ユーザーをブロック',
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'このユーザーをブロックすると、今後マッチングされなくなります。\nブロックしますか？',
          style: GoogleFonts.notoSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'キャンセル',
              style: GoogleFonts.notoSans(
                color: Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'ブロックする',
              style: GoogleFonts.notoSans(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _blockUser();
    }
  }

  Future<void> _blockUser() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('ユーザーが認証されていません');

      // ブロックリストに追加
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('blockedUsers')
          .doc(widget.partnerId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedUserId': widget.partnerId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ユーザーをブロックしました',
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('ブロックエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ブロックに失敗しました。再度お試しください。',
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBlockButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      child: ElevatedButton(
        onPressed: _showBlockDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 20),
            const SizedBox(width: 8),
            Text(
              'このユーザーをブロック',
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

}