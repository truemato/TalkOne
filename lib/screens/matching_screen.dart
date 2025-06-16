import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/call_matching_service.dart';
import '../models/user_model.dart';
import '../services/personality_system.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import 'shikoku_metan_chat_screen.dart';

class MatchingScreen extends StatefulWidget {
  final bool isVideoCall;
  final bool enableAIFilter;
  final bool privacyMode;
  final bool forceAIMatch;

  const MatchingScreen({
    super.key,
    this.isVideoCall = false,
    this.enableAIFilter = false,
    this.privacyMode = false,
    this.forceAIMatch = false,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  final CallMatchingService _matchingService = CallMatchingService();
  late Timer _timer;
  int _dotCount = 0;
  int _secondsElapsed = 0;
  bool _isMatching = false;
  int _waitingUsersCount = 0;
  StreamSubscription? _waitingCountSubscription;
  
  @override
  void initState() {
    super.initState();
    _startWaitingUsersCountStream();
    _startMatching();
    
    // ドットアニメーション
    _timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }

  void _startWaitingUsersCountStream() {
    _waitingCountSubscription = _matchingService.getWaitingUsersCount().listen(
      (count) {
        if (mounted) {
          setState(() {
            _waitingUsersCount = count;
          });
        }
      },
      onError: (error) {
        print('待機ユーザー数取得エラー: $error');
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _waitingCountSubscription?.cancel();
    _matchingService.dispose();
    super.dispose();
  }

  Future<void> _startMatching() async {
    setState(() {
      _isMatching = true;
    });

    try {
      if (widget.forceAIMatch) {
        // AI強制マッチング
        _navigateToAIChat();
        return;
      }

      // 通常のマッチング開始
      await _matchingService.startMatching(
        isVideoCall: widget.isVideoCall,
        onMatchFound: _onMatchFound,
        onTimeExpired: _onTimeExpired,
      );
    } catch (e) {
      print('マッチングエラー: $e');
      _showErrorDialog('マッチングに失敗しました。もう一度お試しください。');
    }
  }

  void _onMatchFound(UserModel matchedUser) {
    if (!mounted) return;

    setState(() {
      _isMatching = false;
    });

    if (widget.isVideoCall) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            channelName: _matchingService.currentChannelName ?? '',
            remoteUser: matchedUser,
            enableAIFilter: widget.enableAIFilter,
            privacyMode: widget.privacyMode,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceCallScreen(
            channelName: _matchingService.currentChannelName ?? '',
            remoteUser: matchedUser,
          ),
        ),
      );
    }
  }

  void _onTimeExpired() {
    if (!mounted) return;

    setState(() {
      _isMatching = false;
    });

    // AIマッチングに切り替え
    _showAIMatchDialog();
  }

  void _showAIMatchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AIとお話ししませんか？'),
        content: const Text(
          '他のユーザーが見つかりませんでした。\nAIと練習してみませんか？',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // マッチング画面も戻る
            },
            child: const Text('ホームに戻る'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToAIChat();
            },
            child: const Text('AIと話す'),
          ),
        ],
      ),
    );
  }

  void _navigateToAIChat() {
    // ランダムに人格を選択
    final personalityId = PersonalitySystem.getRandomPersonality();
    final personalityName = PersonalitySystem.getPersonalityName(personalityId);
    
    // AI練習モード用のダミーユーザーを作成
    final aiUser = UserModel(
      uid: 'ai_practice_${DateTime.now().millisecondsSinceEpoch}',
      displayName: personalityName,
      rating: 1000.0,
      isAI: true,
      metadata: {
        'personalityId': personalityId,
        'isAIPractice': true,
      },
    );
    
    print('AI練習モード開始: $personalityName (ID: $personalityId)');
    
    // VoiceCallScreenを使用（統一されたUI）
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          channelName: 'ai_practice_${DateTime.now().millisecondsSinceEpoch}',
          remoteUser: aiUser,
          callId: 'ai_practice_${DateTime.now().millisecondsSinceEpoch}',
          partnerId: aiUser.uid,
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // マッチング画面も戻る
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final contentWidth = min(screenSize.width, 600.0);
    final contentHeight = screenSize.height;

    return Scaffold(
      backgroundColor: const Color(0xFFE2E0F9),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: contentWidth,
            height: contentHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: contentHeight * 0.05),
                _buildTitle(),
                SizedBox(height: contentHeight * 0.08),
                _buildRateCounter(),
                SizedBox(height: contentHeight * 0.15),
                _buildOnlineUsers(),
                SizedBox(height: contentHeight * 0.04),
                _buildMatchingText(),
                SizedBox(height: contentHeight * 0.06),
                _buildCancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Talk One',
      style: TextStyle(
        fontSize: 60,
        color: Color(0xFF4E3B7A),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRateCounter() {
    return Container(
      width: 120,
      height: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'RATE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: 429),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) => Text(
              '$value',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineUsers() {
    return Text(
      'オンラインのユーザー ：${_waitingUsersCount}人',
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Colors.black,
      ),
    );
  }

  Widget _buildMatchingText() {
    String matchingType = widget.forceAIMatch 
        ? 'AI接続中'
        : widget.isVideoCall 
            ? 'ビデオ通話マッチング中'
            : 'マッチング中';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          matchingType,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 8),
        for (var i = 0; i < 3; i++) ...[
          Text(
            '.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: (i < _dotCount) ? Colors.black : Colors.transparent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCancelButton() {
    return ElevatedButton(
      onPressed: () {
        _matchingService.cancelMatching();
        Navigator.of(context).pop();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC2CEF7),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      ),
      child: const Text(
        'キャンセル',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}