// lib/screens/call_matching_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/call_matching_service.dart';
import 'voice_call_screen.dart';
import 'voice_call_simulation_screen.dart';

enum MatchingState {
  initial,    // 初期状態
  waiting,    // マッチング待機中
  matched,    // マッチング成功
  cancelled,  // キャンセル
  error,      // エラー
}

class CallMatchingScreen extends StatefulWidget {
  const CallMatchingScreen({super.key});

  @override
  State<CallMatchingScreen> createState() => _CallMatchingScreenState();
}

class _CallMatchingScreenState extends State<CallMatchingScreen>
    with TickerProviderStateMixin {
  final CallMatchingService _matchingService = CallMatchingService();
  
  MatchingState _state = MatchingState.initial;
  String? _callRequestId;
  StreamSubscription? _matchingSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _waitingSeconds = 0;
  Timer? _waitingTimer;
  
  @override
  void initState() {
    super.initState();
    
    // パルスアニメーション設定
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _matchingSubscription?.cancel();
    _waitingTimer?.cancel();
    _matchingService.dispose();
    super.dispose();
  }
  
  // マッチング開始
  Future<void> _startMatching() async {
    setState(() {
      _state = MatchingState.waiting;
      _waitingSeconds = 0;
    });
    
    // パルスアニメーション開始
    _pulseController.repeat(reverse: true);
    
    // 待機時間カウント開始
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _waitingSeconds++;
      });
    });
    
    try {
      // 通話リクエストを作成
      _callRequestId = await _matchingService.createCallRequest();
      
      // マッチング監視開始
      _matchingSubscription = _matchingService
          .startMatching(_callRequestId!)
          .listen(
        (match) {
          if (match != null) {
            _handleMatchSuccess(match);
          }
        },
        onError: (error) {
          _handleMatchError(error.toString());
        },
      );
    } catch (e) {
      _handleMatchError(e.toString());
    }
  }
  
  // マッチング成功処理
  void _handleMatchSuccess(CallMatch match) {
    if (!mounted) return;
    
    setState(() {
      _state = MatchingState.matched;
    });
    
    _pulseController.stop();
    _waitingTimer?.cancel();
    _matchingSubscription?.cancel();
    
    // 少し待ってから通話画面に遷移（シミュレーション版を使用）
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VoiceCallSimulationScreen(
              channelName: match.channelName,
              callId: match.callId,
              partnerId: match.partnerId,
            ),
          ),
        );
      }
    });
  }
  
  // マッチングエラー処理
  void _handleMatchError(String error) {
    setState(() {
      _state = MatchingState.error;
    });
    
    _pulseController.stop();
    _waitingTimer?.cancel();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('マッチングエラー: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  // マッチングキャンセル
  Future<void> _cancelMatching() async {
    if (_callRequestId != null) {
      await _matchingService.cancelCallRequest(_callRequestId!);
    }
    
    if (mounted) {
      setState(() {
        _state = MatchingState.cancelled;
      });
    }
    
    _pulseController.stop();
    _waitingTimer?.cancel();
    _matchingSubscription?.cancel();
    
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state != MatchingState.waiting,
      onPopInvoked: (didPop) {
        if (!didPop && _state == MatchingState.waiting) {
          _cancelMatching();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('音声通話マッチング'),
          leading: _state == MatchingState.waiting
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ステータス表示
              _buildStatusWidget(),
              const SizedBox(height: 40),
              // 説明テキスト
              _buildDescriptionText(),
              const SizedBox(height: 40),
              // アクションボタン
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusWidget() {
    switch (_state) {
      case MatchingState.initial:
        return const Icon(
          Icons.phone,
          size: 120,
          color: Colors.blue,
        );
      
      case MatchingState.waiting:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  const Icon(
                    Icons.search,
                    size: 60,
                    color: Colors.orange,
                  ),
                ],
              ),
            );
          },
        );
      
      case MatchingState.matched:
        return Column(
          children: [
            const Icon(
              Icons.people,
              size: 120,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'マッチング成功！',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      
      case MatchingState.cancelled:
        return const Icon(
          Icons.cancel,
          size: 120,
          color: Colors.grey,
        );
      
      case MatchingState.error:
        return const Icon(
          Icons.error,
          size: 120,
          color: Colors.red,
        );
    }
  }
  
  Widget _buildDescriptionText() {
    switch (_state) {
      case MatchingState.initial:
        return Column(
          children: [
            Text(
              '音声通話を開始します',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '• 他のユーザーとランダムマッチング\n'
              '• 3分間の音声通話\n'
              '• マイクの使用許可が必要です',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        );
      
      case MatchingState.waiting:
        return Column(
          children: [
            Text(
              '通話相手を探しています...',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '待機時間: ${_waitingSeconds}秒',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '他のユーザーが通話ボタンを押すまでお待ちください',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        );
      
      case MatchingState.matched:
        return Text(
          '通話を開始します...',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        );
      
      case MatchingState.cancelled:
        return Text(
          'マッチングがキャンセルされました',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        );
      
      case MatchingState.error:
        return Text(
          'エラーが発生しました\nもう一度お試しください',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        );
    }
  }
  
  Widget _buildActionButton() {
    switch (_state) {
      case MatchingState.initial:
        return ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('通話相手を探す'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: _startMatching,
        );
      
      case MatchingState.waiting:
        return ElevatedButton.icon(
          icon: const Icon(Icons.cancel),
          label: const Text('キャンセル'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: _cancelMatching,
        );
      
      case MatchingState.matched:
        return const SizedBox.shrink();
      
      case MatchingState.cancelled:
      case MatchingState.error:
        return ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('もう一度試す'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          onPressed: () {
            setState(() {
              _state = MatchingState.initial;
            });
          },
        );
    }
  }
}