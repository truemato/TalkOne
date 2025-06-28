import 'package:flutter/material.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkOne Test',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: const TestHomeScreen(),
    );
  }
}

class TestHomeScreen extends StatelessWidget {
  const TestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE2E0F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TalkOneロゴ
              const Text(
                'TalkOne',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1E1E),
                  letterSpacing: -4.48,
                  fontFamily: 'Catamaran',
                ),
              ),
              
              const SizedBox(height: 60),
              
              // 説明テキスト
              const Text(
                'AIフィルター機能テスト\nアプリが正常に起動しました！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1E1E1E),
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 80),
              
              // テストボタン
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('アプリは正常に動作しています！'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle, size: 28),
                  label: const Text(
                    'テスト実行',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC2CEF7),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // AIフィルター情報
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('AIフィルター機能'),
                          content: const Text(
                            'iOS/Android両対応のAIフィルター機能が実装されています。\n\n'
                            '• プライバシーモード対応\n'
                            '• エッジ検出によるカラフル線画\n'
                            '• 素顔完全隠蔽機能'
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.blur_on, size: 28),
                  label: const Text(
                    'AIフィルター情報',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade100,
                    foregroundColor: Colors.purple.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}