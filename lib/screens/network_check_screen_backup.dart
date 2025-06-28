import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class NetworkCheckScreen extends StatefulWidget {
  const NetworkCheckScreen({super.key});

  @override
  State<NetworkCheckScreen> createState() => _NetworkCheckScreenState();
}

class _NetworkCheckScreenState extends State<NetworkCheckScreen> {
  bool _isChecking = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    print('=== ネットワーク確認開始 ===');
    
    setState(() {
      _isChecking = true;
      _errorMessage = '';
    });

    try {
      // ネットワーク接続確認
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'インターネットに接続されていません';
        });
        return;
      }

      // Firebase認証確認
      try {
        await FirebaseAuth.instance.signInAnonymously();
        // 接続成功 - ホーム画面へ遷移
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } catch (e) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'サーバーに接続できません';
        });
      }
    } catch (e) {
      setState(() {
        _isChecking = false;
        _errorMessage = '接続エラーが発生しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // アプリロゴ
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 48),
                
                // ステータス表示
                if (_isChecking) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    '接続を確認しています...',
                    style: TextStyle(fontSize: 16),
                  ),
                ] else if (_errorMessage.isNotEmpty) ...[
                  Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'インターネット接続を確認してください',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // リトライボタン
                  GestureDetector(
                    onTap: _isChecking ? null : () {
                      print('リトライボタンがタップされました');
                      _checkConnection();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8), // タップ範囲拡大
                      child: ElevatedButton.icon(
                        onPressed: _isChecking ? null : () {
                          print('リトライボタンがタップされました');
                          _checkConnection();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('もう一度接続する'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}