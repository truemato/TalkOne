import 'package:flutter/material.dart';
import 'dart:math';
import '../services/matching_service.dart';
import 'video_call_screen.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen>
    with TickerProviderStateMixin {
  bool _isMatching = false;
  String _status = 'マッチを開始してください';
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _setupMatchingCallbacks();
  }

  void _setupMatchingCallbacks() {
    MatchingService.onMatchFound = (roomId, peerId) {
      if (mounted) {
        _stopMatching();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              roomId: roomId,
              peerId: peerId,
            ),
          ),
        );
      }
    };

    MatchingService.onError = (error) {
      if (mounted) {
        setState(() {
          _status = 'エラー: $error';
          _isMatching = false;
        });
        _stopAnimation();
        _showErrorDialog(error);
      }
    };

    MatchingService.onMatchCancelled = () {
      if (mounted) {
        setState(() {
          _status = 'マッチがキャンセルされました';
          _isMatching = false;
        });
        _stopAnimation();
      }
    };
  }

  void _startMatching() async {
    setState(() {
      _isMatching = true;
      _status = 'マッチを探しています...';
    });

    _startAnimation();

    // Generate a random user ID (in a real app, this would come from authentication)
    final userId = 'user_${Random().nextInt(10000)}';
    
    try {
      await MatchingService.startMatching(userId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'マッチング開始エラー: $e';
          _isMatching = false;
        });
        _stopAnimation();
      }
    }
  }

  void _cancelMatching() {
    MatchingService.cancelMatching();
    setState(() {
      _isMatching = false;
      _status = 'マッチをキャンセルしました';
    });
    _stopAnimation();
  }

  void _startAnimation() {
    _animationController.repeat(reverse: true);
  }

  void _stopAnimation() {
    _animationController.stop();
    _animationController.reset();
  }

  void _stopMatching() {
    _stopAnimation();
    setState(() {
      _isMatching = false;
    });
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    MatchingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('ビデオマッチング'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Matching animation
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isMatching ? _animation.value : 1.0,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isMatching ? Colors.blue[400] : Colors.grey[300],
                        boxShadow: _isMatching
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _isMatching ? Icons.search : Icons.videocam,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Status text
              Text(
                _status,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isMatching ? _cancelMatching : _startMatching,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMatching ? Colors.red[600] : Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    _isMatching ? 'キャンセル' : 'マッチング開始',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Info text
              if (!_isMatching)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ボタンを押すと他のユーザーとのビデオ通話マッチングが開始されます。\nカメラとマイクへのアクセス許可が必要です。',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}