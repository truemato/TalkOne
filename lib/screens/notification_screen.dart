import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/notification_service.dart';
import '../utils/theme_utils.dart';
import '../utils/font_size_utils.dart';

/// 通知画面
class NotificationScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;
  
  const NotificationScreen({super.key, this.onNavigateToHome});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final UserProfileService _userProfileService = UserProfileService();
  final NotificationService _notificationService = NotificationService();
  int _selectedThemeIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
  }

  Future<void> _loadUserTheme() async {
    final profile = await _userProfileService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedThemeIndex = profile.themeIndex ?? 0;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;

  /// 通知アイコンを取得
  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.reportResponse:
        return Icons.report_problem;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.account:
        return Icons.account_circle;
      case NotificationType.general:
      default:
        return Icons.notifications;
    }
  }

  /// 通知アイコンの色を取得
  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.reportResponse:
        return Colors.orange;
      case NotificationType.warning:
        return Colors.red;
      case NotificationType.account:
        return Colors.blue;
      case NotificationType.general:
      default:
        return Colors.grey;
    }
  }

  /// 日時フォーマット
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (diff.inDays == 1) {
      return '昨日 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return DateFormat('M/d').format(dateTime);
    }
  }

  /// 通知タップ処理
  Future<void> _onNotificationTap(AppNotification notification) async {
    // 未読の場合は既読にマーク
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
    }

    // 通知タイプに応じた詳細画面表示
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => _buildNotificationDetailDialog(notification),
      );
    }
  }

  /// 通知詳細ダイアログ
  Widget _buildNotificationDetailDialog(AppNotification notification) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            _getNotificationIcon(notification.type),
            color: _getNotificationColor(notification.type),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notification.title,
              style: FontSizeUtils.notoSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.message,
            style: FontSizeUtils.notoSans(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            _formatDateTime(notification.createdAt),
            style: FontSizeUtils.notoSans(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '閉じる',
            style: FontSizeUtils.notoSans(
              fontSize: 16,
              color: _currentThemeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// 通知削除（左スワイプ）
  Future<void> _deleteNotification(AppNotification notification) async {
    final success = await _notificationService.deleteNotification(notification.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '通知を削除しました',
            style: FontSizeUtils.notoSans(fontSize: 14),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 全て既読にマーク
  Future<void> _markAllAsRead() async {
    final success = await _notificationService.markAllAsRead();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '全ての通知を既読にしました',
            style: FontSizeUtils.notoSans(fontSize: 14),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        // 下から上へのスワイプ（負の速度）でホーム画面に戻る
        if (details.primaryVelocity! < -500 && mounted) {
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
            onPressed: () {
              if (widget.onNavigateToHome != null) {
                widget.onNavigateToHome!();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            StreamBuilder<int>(
              stream: _notificationService.getUnreadCountStream(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                if (unreadCount > 0) {
                  return IconButton(
                    icon: const Icon(Icons.mark_email_read, color: Colors.white),
                    onPressed: _markAllAsRead,
                    tooltip: '全て既読にする',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
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

    return StreamBuilder<List<AppNotification>>(
      stream: _notificationService.getNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'エラーが発生しました',
                  style: FontSizeUtils.notoSans(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          );
        }
        
        final notifications = snapshot.data ?? [];
        
        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  '通知はありません',
                  style: FontSizeUtils.notoSans(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '新しい通知があると、ここに表示されます',
                  style: FontSizeUtils.notoSans(
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
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationCard(notification);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // 削除確認ダイアログ
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              '通知を削除',
              style: FontSizeUtils.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'この通知を削除しますか？',
              style: FontSizeUtils.notoSans(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'キャンセル',
                  style: FontSizeUtils.notoSans(fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  '削除',
                  style: FontSizeUtils.notoSans(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ?? false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.delete,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              '削除',
              style: FontSizeUtils.notoSans(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onNotificationTap(notification),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 通知アイコン
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // 通知内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // タイトル行
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: FontSizeUtils.notoSans(
                                fontSize: 16,
                                fontWeight: notification.isRead 
                                    ? FontWeight.w500 
                                    : FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 未読インジケーター
                          if (!notification.isRead)
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // メッセージ
                      Text(
                        notification.message,
                        style: FontSizeUtils.notoSans(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // 日時
                      Text(
                        _formatDateTime(notification.createdAt),
                        style: FontSizeUtils.notoSans(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}