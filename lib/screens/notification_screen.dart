import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/version_notification_service.dart';
import '../utils/theme_utils.dart';

// 通知画面（仮）
class NotificationScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  
  const NotificationScreen({super.key, this.onNavigateToHome});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final VersionNotificationService _versionService = VersionNotificationService();
  int _selectedThemeIndex = 0;
  List<VersionNotification> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _loadNotifications();
  }

  Future<void> _loadUserTheme() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedThemeIndex = profile.themeIndex;
      });
    }
  }
  
  void _loadNotifications() {
    _versionService.getUserNotifications().listen(
      (notifications) {
        if (mounted) {
          setState(() {
            _notifications = notifications;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '通知の読み込みに失敗しました';
          });
        }
        print('通知読み込みエラー: $error');
      },
    );
  }

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        // 下から上へのスワイプ（負の速度）でホーム画面に戻る
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
              '通知',
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadNotifications();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
              ),
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Expanded(
          child: _notifications.isEmpty 
              ? _buildEmptyState()
              : _buildNotificationList(),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 24),
          Text(
            '通知はありません',
            style: GoogleFonts.notoSans(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '新しい通知が届くとここに表示されます',
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }
  
  Widget _buildNotificationCard(VersionNotification notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: notification.isVersionUpdate 
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            notification.isVersionUpdate 
                ? Icons.system_update
                : Icons.notifications,
            color: notification.isVersionUpdate ? Colors.green : Colors.blue,
          ),
        ),
        title: Text(
          notification.title,
          style: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            if (notification.isVersionUpdate && 
                notification.fromVersion != null && 
                notification.toVersion != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${notification.fromVersion} → ${notification.toVersion}',
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              notification.relativeTime,
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: !notification.isRead 
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () async {
          if (!notification.isRead) {
            await _versionService.markAsRead(notification.id);
          }
        },
      ),
    );
  }
}