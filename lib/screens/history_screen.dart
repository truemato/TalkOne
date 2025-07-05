import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'dart:io' show Platform;
import '../services/call_history_service.dart';
import '../services/user_profile_service.dart';
import '../services/block_service.dart';
import '../utils/theme_utils.dart';
import 'partner_profile_screen.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  
  const HistoryScreen({super.key, this.onNavigateToHome});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final CallHistoryService _callHistoryService = CallHistoryService();
  final UserProfileService _userProfileService = UserProfileService();
  final BlockService _blockService = BlockService();
  
  int _selectedThemeIndex = 0;
  Set<String> _blockedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _loadBlockedUsers();
    // Unknownニックネームを修正
    _callHistoryService.fixUnknownNicknames();
  }

  Future<void> _loadUserTheme() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedThemeIndex = profile.themeIndex ?? 0;
      });
    }
  }

  Future<void> _loadBlockedUsers() async {
    final blockedIds = await _blockService.getBlockedUserIds();
    if (mounted) {
      setState(() {
        _blockedUserIds = blockedIds.toSet();
      });
    }
  }

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (diff.inDays == 1) {
      return '昨日 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前 ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('M/d HH:mm').format(dateTime);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildStarRating(int? rating) {
    if (rating == null) return const Text('未評価');
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  // 相手プロフィール画面に遷移
  void _navigateToPartnerProfile(CallHistory history) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartnerProfileScreen(
          partnerId: history.partnerId,
          callId: history.callId,
          isDummyMatch: false,
        ),
      ),
    );
  }



  void _showRatingDialog(CallHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          '${history.partnerNickname}との通話評価',
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 相手のアイコン
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: SvgPicture.asset(
                  history.partnerIconPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 自分の評価
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'あなたの評価:',
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _buildStarRating(history.myRatingToPartner),
              ],
            ),
            const SizedBox(height: 12),
            
            const SizedBox(height: 20),
            
            // 通話情報
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '通話時間:',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _formatDuration(history.callDuration),
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '通話日時:',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _formatDateTime(history.callDateTime),
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '閉じる',
              style: GoogleFonts.notoSans(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
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
        // 右から左へのスワイプ（負の速度）でホーム画面に戻る
        if (details.primaryVelocity! < 0 && mounted) {
          if (widget.onNavigateToHome != null) {
            widget.onNavigateToHome!();
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
          backgroundColor: _currentThemeColor,
          appBar: AppBar(
            title: Text(
              '通話履歴',
              style: GoogleFonts.notoSans(
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
    return StreamBuilder<List<CallHistory>>(
      stream: _callHistoryService.getCallHistoryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'エラーが発生しました',
              style: GoogleFonts.notoSans(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          );
        }
        
        final histories = snapshot.data ?? [];
        
        if (histories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  '通話履歴がありません',
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '最初の通話を始めてみましょう！',
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: histories.length,
          itemBuilder: (context, index) {
            final history = histories[index];
            return _buildHistoryCard(history);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(CallHistory history) {
    final isBlocked = _blockedUserIds.contains(history.partnerId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ブロック状態バー（一番上に表示）
          if (isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Text(
                'ブロック中',
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          // メインコンテンツ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: isBlocked 
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    )
                  : BorderRadius.circular(16),
            ),
            child: GestureDetector(
              onTap: () {
                if (!history.isAiCall) {
                  _navigateToPartnerProfile(history);
                } else {
                  _showRatingDialog(history);
                }
              },
              child: Row(
                children: [
                  // アイコン
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: SvgPicture.asset(
                        history.partnerIconPath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // 通話情報
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                history.partnerNickname,
                                style: GoogleFonts.notoSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (history.isAiCall)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'AI',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(history.callDateTime),
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(history.callDuration),
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // 評価情報（自分の評価のみ）
                        Row(
                          children: [
                            Text(
                              '私の評価: ',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            _buildStarRating(history.myRatingToPartner),
                          ],
                        ),
                      ],
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
}