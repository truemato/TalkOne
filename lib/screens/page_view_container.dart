import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'notification_screen.dart';
import '../services/version_notification_service.dart';

class PageViewContainer extends StatefulWidget {
  const PageViewContainer({super.key});

  @override
  State<PageViewContainer> createState() => _PageViewContainerState();
}

class _PageViewContainerState extends State<PageViewContainer> {
  final PageController _horizontalPageController = PageController(initialPage: 1);
  final PageController _verticalPageController = PageController(initialPage: 1);
  final VersionNotificationService _versionService = VersionNotificationService();
  
  @override
  void initState() {
    super.initState();
    // アプリ起動時にバージョンチェックを実行
    _checkVersionOnStartup();
  }
  
  @override
  void dispose() {
    _horizontalPageController.dispose();
    _verticalPageController.dispose();
    super.dispose();
  }
  
  /// アプリ起動時のバージョンチェック
  Future<void> _checkVersionOnStartup() async {
    try {
      await _versionService.checkAndNotifyVersionUpdate();
    } catch (e) {
      print('バージョンチェックエラー: $e');
    }
  }

  // ホーム画面に戻る関数
  void _navigateToHome() {
    // 縦方向のPageViewがホーム画面(index 1)にない場合、まず縦方向を戻す
    if (_verticalPageController.page?.round() != 1) {
      _verticalPageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
    // 横方向のPageViewをホーム画面(index 1)に戻す
    if (_horizontalPageController.page?.round() != 1) {
      _horizontalPageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _verticalPageController,
        scrollDirection: Axis.vertical,
        children: [
          // 上にスワイプで表示される通知画面
          NotificationScreenWrapper(onNavigateToHome: _navigateToHome),
          // メインの横スクロールページ
          PageView(
            controller: _horizontalPageController,
            scrollDirection: Axis.horizontal,
            children: [
              HistoryScreenWrapper(onNavigateToHome: _navigateToHome),
              HomeScreenWrapper(
                onNavigateToHistory: () {
                  _horizontalPageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                },
                onNavigateToSettings: () {
                  _horizontalPageController.animateToPage(
                    2,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                },
                onNavigateToNotification: () {
                  _verticalPageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                },
              ),
              SettingsScreenWrapper(onNavigateToHome: _navigateToHome),
            ],
          ),
        ],
      ),
    );
  }
}

// HomeScreenをラップして、ナビゲーションコールバックを提供
class HomeScreenWrapper extends StatelessWidget {
  final VoidCallback onNavigateToHistory;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onNavigateToNotification;

  const HomeScreenWrapper({
    super.key,
    required this.onNavigateToHistory,
    required this.onNavigateToSettings,
    required this.onNavigateToNotification,
  });

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      onNavigateToHistory: onNavigateToHistory,
      onNavigateToSettings: onNavigateToSettings,
      onNavigateToNotification: onNavigateToNotification,
    );
  }
}

// HistoryScreenをラップして、ホーム戻り機能を提供
class HistoryScreenWrapper extends StatelessWidget {
  final VoidCallback onNavigateToHome;

  const HistoryScreenWrapper({
    super.key,
    required this.onNavigateToHome,
  });

  @override
  Widget build(BuildContext context) {
    return HistoryScreen(onNavigateToHome: onNavigateToHome);
  }
}

// SettingsScreenをラップして、ホーム戻り機能を提供
class SettingsScreenWrapper extends StatelessWidget {
  final VoidCallback onNavigateToHome;

  const SettingsScreenWrapper({
    super.key,
    required this.onNavigateToHome,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(onNavigateToHome: onNavigateToHome);
  }
}

// NotificationScreenをラップして、ホーム戻り機能を提供
class NotificationScreenWrapper extends StatelessWidget {
  final VoidCallback onNavigateToHome;

  const NotificationScreenWrapper({
    super.key,
    required this.onNavigateToHome,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationScreen(onNavigateToHome: onNavigateToHome);
  }
}