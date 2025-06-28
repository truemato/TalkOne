import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'notification_screen.dart';

class PageViewContainer extends StatefulWidget {
  const PageViewContainer({super.key});

  @override
  State<PageViewContainer> createState() => _PageViewContainerState();
}

class _PageViewContainerState extends State<PageViewContainer> {
  final PageController _horizontalPageController = PageController(initialPage: 1);
  final PageController _verticalPageController = PageController(initialPage: 1);
  
  @override
  void dispose() {
    _horizontalPageController.dispose();
    _verticalPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _verticalPageController,
        scrollDirection: Axis.vertical,
        children: [
          // 上にスワイプで表示される通知画面
          const NotificationScreen(),
          // メインの横スクロールページ
          PageView(
            controller: _horizontalPageController,
            scrollDirection: Axis.horizontal,
            children: [
              const HistoryScreen(),
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
              const SettingsScreen(),
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