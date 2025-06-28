import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'notification_screen.dart';

class MainPageView extends StatefulWidget {
  const MainPageView({super.key});

  @override
  State<MainPageView> createState() => _MainPageViewState();
}

class _MainPageViewState extends State<MainPageView> {
  final PageController _horizontalPageController = PageController(initialPage: 1);
  final PageController _verticalPageController = PageController(initialPage: 1); // 通知画面を上に配置するため初期値を1に
  
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
            children: const [
              HistoryScreen(),
              HomeScreen(),
              SettingsScreen(),
            ],
          ),
        ],
      ),
    );
  }
}