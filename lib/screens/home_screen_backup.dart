// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/agora_call_service.dart';
import '../services/ai_filter_service.dart';
import 'matching_screen.dart';
import 'voicevox_test_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AIFilterService _aiFilterService = AIFilterService();
  bool _hasAIFilterAccess = false;
  
  @override
  void initState() {
    super.initState();
    _checkAIFilterAccess();
  }
  
  Future<void> _checkAIFilterAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final rating = doc.data()?['rating']?.toDouble() ?? 3.0;
        setState(() {
          _hasAIFilterAccess = _aiFilterService.hasAccess(rating);
        });
      }
    }
  }
  
  void _showAIFilterOptionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ビデオ通話設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('素顔を隠すAIフィルターを使用しますか？'),
              const SizedBox(height: 16),
              if (!_hasAIFilterAccess)
                const Text(
                  'AIフィルターはレーティング4.0以上のユーザーのみ利用できます',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startVideoCall(enableAIFilter: false, privacyMode: false);
              },
              child: const Text('通常のビデオ通話'),
            ),
            if (_hasAIFilterAccess) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startVideoCall(enableAIFilter: true, privacyMode: false);
                },
                child: const Text('AIフィルター使用'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startVideoCall(enableAIFilter: true, privacyMode: true);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('プライバシーモード'),
              ),
            ],
          ],
        );
      },
    );
  }
  
  Future<void> _checkPermissionsBeforeCall() async {
    print('ホーム画面: 事前権限確認開始');
    
    try {
      // マイク権限確認
      final micStatus = await Permission.microphone.status;
      print('ホーム画面: マイク権限状態: $micStatus');
      
      // カメラ権限確認
      final cameraStatus = await Permission.camera.status;
      print('ホーム画面: カメラ権限状態: $cameraStatus');
      
      if (micStatus != PermissionStatus.granted || cameraStatus != PermissionStatus.granted) {
        // 権限説明ダイアログを表示
        if (mounted) {
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('権限が必要です'),
              content: const Text('ビデオ通話にはマイクとカメラの権限が必要です。\n設定から権限を許可してください。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('設定を開く'),
                ),
              ],
            ),
          );
          
          if (shouldContinue == true) {
            await openAppSettings();
          }
        }
      }
    } catch (e) {
      print('ホーム画面: 権限確認エラー: $e');
    }
  }
  
  void _startVideoCall({bool enableAIFilter = false, bool privacyMode = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchingScreen(
          isVideoCall: true,
          enableAIFilter: enableAIFilter,
          privacyMode: privacyMode,
        ),
      ),
    );
  }

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
                'AIフィルターで素顔を完全に隠して\n安全に匿名ビデオ通話できます',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1E1E1E),
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 80),
              
              // 音声通話ボタン
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MatchingScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone, size: 28),
                  label: const Text(
                    '音声通話を開始',
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
              
              // 通常のビデオ通話ボタン  
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 通常のビデオ通話（AIフィルターなし）
                    _startVideoCall(enableAIFilter: false, privacyMode: false);
                  },
                  icon: const Icon(Icons.videocam, size: 28),
                  label: const Text(
                    '通常のビデオ通話',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF90CAF9),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // プライバシー保護ビデオ通話ボタン
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // AIフィルター有効なビデオ通話
                    _startVideoCall(enableAIFilter: true, privacyMode: true);
                  },
                  icon: const Icon(Icons.face_retouching_natural, size: 28),
                  label: const Text(
                    'プライバシー保護ビデオ通話',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB3E5FC),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // AI練習ボタン
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MatchingScreen(forceAIMatch: true),
                      ),
                    );
                  },
                  icon: const Icon(Icons.smart_toy, size: 28),
                  label: const Text(
                    'AI練習モード',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[200],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // VOICEVOXテストボタン
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VoiceVoxTestScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.record_voice_over, size: 20),
                  label: const Text(
                    'VOICEVOX テスト',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE1BEE7),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 診断ボタン
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Agora接続テスト
                    final agoraService = AgoraCallService();
                    final success = await agoraService.testConnection();
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Agora接続テスト成功' : 'Agora接続テスト失敗'),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.network_check, size: 20),
                  label: const Text(
                    'Agora接続テスト',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE0B2),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // フッター情報
              const Text(
                'レーティングシステムで成長を実感\n会話スキルを向上させよう',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}