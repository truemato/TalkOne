import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../services/user_profile_service.dart';
import '../services/call_history_service.dart';
import '../services/agora_call_service.dart';
import '../services/evaluation_service.dart';
import '../services/rating_service.dart';
import 'evaluation_screen.dart';
import 'partner_profile_screen.dart';
import '../utils/theme_utils.dart';
import '../utils/font_size_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VoiceCallScreen extends StatefulWidget {
  final String channelName;
  final String callId;
  final String partnerId;
  final String? conversationTheme;

  const VoiceCallScreen({
    super.key,
    required this.channelName,
    required this.callId,
    required this.partnerId,
    this.conversationTheme,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  final UserProfileService _userProfileService = UserProfileService();
  final CallHistoryService _callHistoryService = CallHistoryService();
  final AgoraCallService _agoraService = AgoraCallService();
  final EvaluationService _evaluationService = EvaluationService();
  final RatingService _ratingService = RatingService();
  String? _selectedIconPath = 'aseets/icons/Woman 1.svg';
  String _partnerNickname = 'Unknown';
  
  // Agora関連の状態
  bool _isConnected = false;
  bool _isMuted = false;
  bool _partnerJoined = false;
  AgoraConnectionState _connectionState = AgoraConnectionState.disconnected;
  
  // 音声レベルによるアイコンサイズ制御
  int _currentAudioVolume = 0;
  late AnimationController _volumeController;
  late Animation<double> _volumeAnimation;
  // テーマインデックス
  int _selectedThemeIndex = 0;
  
  // タイマー関連
  int _remainingSeconds = 180; // 3分 = 180秒
  Timer? _timer;
  bool _callEnded = false;
  DateTime? _callStartTime;
  
  // 緊急通報関連
  bool _isReporting = false;
  
  // 会話テーマリスト
  final List<String> _conversationThemes = [
    '🎯 自己紹介・自己理解系',
    '最近ハマってること',
    '好きな食べ物／嫌いな食べ物',
    '休日の過ごし方',
    '朝型？夜型？',
    '自分の性格を一言で言うと？',
    '今までで一番頑張ったこと',
    '最近ちょっと変わったこと',
    '尊敬している人',
    '自分の中のマイルール',
    '子どもの頃の夢',
    '💬 日常会話・雑談系',
    '最近観た映画／ドラマ',
    '今日の天気、好き？',
    '通勤・通学時間の過ごし方',
    '最近びっくりしたこと',
    '今、部屋にあるものでお気に入りは？',
    '最近の「ちょっと嬉しかったこと」',
    '毎日欠かさずやってること',
    '今食べたいもの',
    'おすすめのアプリ／ツール',
    '今のスマホの待ち受け画面、どんなの？',
    '💭 意見交換・感情表現系',
    '幸せだなと思う瞬間は？',
    'イライラしたとき、どうする？',
    '自分って変わってるなと思うとき',
    '友達ってどんな存在？',
    'プレゼントするなら何を選ぶ？',
    'あえて「何もしない時間」って必要？',
    '人から言われて嬉しかった言葉',
    '自分の中の「こだわり」って何？',
    '落ち込んだときの立ち直り方',
    'やってみたいけど、ちょっと怖いこと',
  ];
  late String _currentTheme;

  @override
  void initState() {
    super.initState();
    _callStartTime = DateTime.now();
    _loadUserProfile();
    _initializeAnimations();
    _initializeVolumeAnimation();
    _initializeAgora();
    _startCallTimer();
    
    // 共有テーマまたはランダムでテーマを選択
    _currentTheme = widget.conversationTheme ?? 
                   _conversationThemes[(DateTime.now().millisecondsSinceEpoch % _conversationThemes.length)];
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _volumeController.dispose();
    _agoraService.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  void _initializeVolumeAnimation() {
    _volumeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _volumeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _volumeController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _loadUserProfile() async {
    // 相手のプロフィール情報を取得
    final partnerProfile = await _userProfileService.getUserProfileById(widget.partnerId);
    
    if (partnerProfile != null && mounted) {
      setState(() {
        // 相手の情報（アイコン、ニックネーム、テーマカラー）
        _selectedIconPath = partnerProfile.iconPath ?? 'aseets/icons/Woman 1.svg';
        // ニックネームが空文字やnullの場合のデフォルト処理
        final nickname = partnerProfile.nickname;
        if (nickname != null && nickname.trim().isNotEmpty) {
          _partnerNickname = nickname.trim();
        } else {
          // ニックネームが未設定の場合、ユーザーIDの一部を使用
          _partnerNickname = 'ユーザー${widget.partnerId.substring(0, 6)}';
        }
        _selectedThemeIndex = partnerProfile.themeIndex ?? 0;
      });
      print('VoiceCall: 相手プロフィール読み込み完了 - ニックネーム: $_partnerNickname');
    } else {
      print('VoiceCall: 相手プロフィールが見つからない - ID: ${widget.partnerId}');
      setState(() {
        _partnerNickname = 'ユーザー${widget.partnerId.substring(0, 6)}';
      });
    }
  }

  Future<void> _initializeAgora() async {
    try {
      // Agoraサービスのコールバックを設定
      _agoraService.onUserJoined = (uid) {
        print('VoiceCall: 相手が参加しました - $uid');
        if (mounted) {
          setState(() {
            _partnerJoined = true;
          });
        }
      };

      _agoraService.onUserLeft = (uid) {
        print('VoiceCall: 相手が離脱しました - $uid');
        if (mounted) {
          setState(() {
            _partnerJoined = false;
          });
          
          // 相手が離脱したら自動で通話を終了
          print('VoiceCall: 相手の離脱により通話を自動終了します');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_callEnded) {
              _endCall();
            }
          });
        }
      };

      _agoraService.onConnectionStateChanged = (state) {
        print('VoiceCall: 接続状態変更 - $state');
        if (mounted) {
          setState(() {
            _connectionState = state;
            _isConnected = state == AgoraConnectionState.connected;
          });
          
          // 接続が失敗または切断された場合の処理
          if (state == AgoraConnectionState.failed) {
            print('VoiceCall: 接続に失敗しました');
          } else if (state == AgoraConnectionState.disconnected && _partnerJoined) {
            print('VoiceCall: 予期しない切断が発生しました');
            // 相手がいた状態での切断の場合、少し待ってから通話終了
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && !_callEnded && !_partnerJoined) {
                print('VoiceCall: 相手との接続が回復しないため通話を終了します');
                _endCall();
              }
            });
          }
        }
      };
      
      // 音声レベル監視を設定
      _agoraService.onAudioVolumeIndication = (volume) {
        _updateAudioVolume(volume);
      };

      _agoraService.onError = (error) {
        print('VoiceCall: Agoraエラー - $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('通話エラー: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      };

      // Agoraエンジンを初期化
      print('VoiceCall: Agora初期化開始...');
      
      // 複数回試行（iOS用）
      bool success = false;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (!success && retryCount < maxRetries && mounted) {
        if (retryCount > 0) {
          print('VoiceCall: 初期化リトライ $retryCount/$maxRetries');
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        }
        
        success = await _agoraService.initialize();
        
        if (!success) {
          retryCount++;
          if (retryCount < maxRetries) {
            print('VoiceCall: 初期化失敗、リトライします...');
          }
        }
      }
      
      if (success && mounted) {
        print('VoiceCall: Agora初期化成功、チャンネル参加中...');
        // チャンネルに参加
        final joinSuccess = await _agoraService.joinChannel(widget.channelName);
        
        if (joinSuccess) {
          print('VoiceCall: チャンネル参加成功 - ${widget.channelName}');
          _agoraService.recordCallStart();
        } else {
          print('VoiceCall: チャンネル参加失敗');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('通話に参加できませんでした。ネットワーク接続を確認してください。'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('VoiceCall: Agora初期化失敗（最大リトライ回数到達）');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('音声通話の初期化に失敗しました。マイクの権限を確認してください。'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('VoiceCall: Agora初期化エラー - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('通話エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCallTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        _endCall();
      }
    });
  }

  Future<void> _toggleMute() async {
    try {
      await _agoraService.toggleMute();
      final newMuteState = await _agoraService.isMuted();
      if (mounted) {
        setState(() {
          _isMuted = newMuteState;
        });
      }
      print('VoiceCall: ミュート状態変更 - $_isMuted');
    } catch (e) {
      print('VoiceCall: ミュート切り替えエラー - $e');
    }
  }

  void _endCall() {
    if (_callEnded) {
      print('VoiceCall: 通話終了処理は既に実行済みです');
      return;
    }
    
    print('VoiceCall: 通話終了処理を開始します');
    _callEnded = true;
    
    // タイマーを停止
    _timer?.cancel();
    print('VoiceCall: タイマー停止完了');
    
    // Agoraから離脱（相手に離脱通知を送信）
    print('VoiceCall: Agoraチャンネルから離脱中...');
    _agoraService.leaveChannel();
    
    // 通話履歴を保存
    print('VoiceCall: 通話履歴を保存中...');
    _saveCallHistory();
    
    // 直接評価画面に遷移
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => EvaluationScreen(
            callId: widget.callId,
            partnerId: widget.partnerId,
            isDummyMatch: false, // 通話のみバージョンではAI通話なし
            // isDummyMatch: widget.partnerId.startsWith('dummy_') || 
            //              widget.partnerId.startsWith('ai_practice_'),
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _saveCallHistory() async {
    if (_callStartTime == null) return;
    
    final callDuration = DateTime.now().difference(_callStartTime!).inSeconds;
    // final isAiCall = widget.partnerId.startsWith('dummy_') || 
    //                  widget.partnerId.startsWith('ai_practice_');
    
    final history = CallHistory(
      callId: widget.callId,
      partnerId: widget.partnerId,
      partnerNickname: _partnerNickname,
      partnerIconPath: _selectedIconPath ?? 'aseets/icons/Woman 1.svg',
      callDateTime: _callStartTime!,
      callDuration: callDuration,
      isAiCall: false, // 通話のみバージョンではAI通話なし
    );
    
    await _callHistoryService.saveCallHistory(history);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Color get _currentThemeColor => getAppTheme(_selectedThemeIndex).backgroundColor;
  
  // 音声レベルを更新してアイコンサイズを変更
  void _updateAudioVolume(int volume) {
    if (!mounted) return;
    
    _currentAudioVolume = volume;
    
    // 音声レベル（0-255）を1.0-1.2のスケールに変換
    final normalizedVolume = (volume / 255.0).clamp(0.0, 1.0);
    final targetScale = 1.0 + (normalizedVolume * 0.2); // 最大1.2倍
    
    // アニメーションで滑らかにスケール変更
    _volumeController.animateTo(normalizedVolume);
    
    print('VoiceCall: 音声レベル $volume -> スケール ${targetScale.toStringAsFixed(2)}');
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = getAppTheme(_selectedThemeIndex);
    return Scaffold(
      backgroundColor: currentTheme.backgroundColor,
      body: Platform.isAndroid 
          ? SafeArea(child: _buildContent())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 接続状態表示
            _buildConnectionStatus(),
            
            // 話題表示
            _buildThemeDisplay(),
            
            // ユーザーアイコン
            Center(child: _buildUserIcon()),
            
            // 3分間タイマー
            Center(child: _buildTimer()),
            
            // 通話コントロール（ミュート・通話切り）
            Center(child: _buildCallControls()),
          ],
        ),
      ),
    );
  }

  Widget _buildUserIcon() {
    return Stack(
      children: [
        // メインアイコン
        AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _volumeAnimation]),
          builder: (context, child) {
            // 基本のパルス + 音声レベルによる拡大
            final combinedScale = _pulseAnimation.value * _volumeAnimation.value;
            
            return Transform.scale(
              scale: combinedScale,
              child: Container(
                width: 234, // 180 * 1.3 = 234
                height: 234, // 180 * 1.3 = 234
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    // 音声レベルが高い時の追加エフェクト
                    if (_currentAudioVolume > 30)
                      BoxShadow(
                        color: getAppTheme(_selectedThemeIndex).backgroundColor.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: ClipOval(
                  child: SvgPicture.asset(
                    _selectedIconPath!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        ),
        
        // 緊急通報ボタン（右下に配置）
        Positioned(
          bottom: 10,
          right: 10,
          child: _buildEmergencyReportButton(),
        ),
      ],
    );
  }

  Widget _buildTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _formatTime(_remainingSeconds),
        style: FontSizeUtils.notoSans(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: getAppTheme(_selectedThemeIndex).backgroundColor,
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    String statusText;
    Color statusColor;
    
    switch (_connectionState) {
      case AgoraConnectionState.connecting:
        statusText = '接続中...';
        statusColor = Colors.orange;
        break;
      case AgoraConnectionState.connected:
        statusText = _partnerJoined ? '通話中' : '相手を待機中';
        statusColor = _partnerJoined ? Colors.green : Colors.blue;
        break;
      case AgoraConnectionState.failed:
        statusText = '接続エラー';
        statusColor = Colors.red;
        break;
      case AgoraConnectionState.disconnected:
      default:
        statusText = '未接続';
        statusColor = Colors.grey;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: FontSizeUtils.notoSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F2F2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        _currentTheme,
        style: const TextStyle(
          color: Color(0xFF4E3B7A),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // ミュートボタン
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _isMuted ? Colors.red : Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: _toggleMute,
              child: Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                color: _isMuted ? Colors.white : getAppTheme(_selectedThemeIndex).backgroundColor,
                size: 28,
              ),
            ),
          ),
        ),
        
        // 通話終了ボタン
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: _endCall,
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 緊急通報ボタン
  Widget _buildEmergencyReportButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: _isReporting ? null : _showEmergencyReportDialog,
          child: const Icon(
            Icons.priority_high,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  /// 緊急通報確認ダイアログ
  Future<void> _showEmergencyReportDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // ダイアログ外タップで閉じない
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(
              '緊急通報',
              style: FontSizeUtils.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          'この相手を通報しますか？\n\n通報すると即座に通話が終了し、相手のプロフィール画面に移動します。',
          style: FontSizeUtils.notoSans(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'キャンセル',
              style: FontSizeUtils.notoSans(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '通報する',
              style: FontSizeUtils.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _executeEmergencyReport();
    }
  }

  /// 緊急通報の実行
  Future<void> _executeEmergencyReport() async {
    if (_isReporting) return;
    
    setState(() {
      _isReporting = true;
    });

    try {
      print('緊急通報実行: 通話終了 & プロフィール画面遷移');
      
      // 1. 通話を即座に終了（タイマー停止、Agora切断）
      _timer?.cancel();
      await _agoraService.leaveChannel();
      await _agoraService.dispose();
      
      // 2. 通話履歴を保存
      if (_callStartTime != null) {
        final callDuration = DateTime.now().difference(_callStartTime!).inSeconds;
        final history = CallHistory(
          callId: widget.callId,
          partnerId: widget.partnerId,
          partnerNickname: _partnerNickname,
          partnerIconPath: _selectedIconPath ?? 'aseets/icons/Woman 1.svg',
          callDateTime: _callStartTime!,
          callDuration: callDuration,
          myRatingToPartner: null, // 緊急通報時は評価なし
          partnerRatingToMe: null,
          isAiCall: false,
        );
        await _callHistoryService.saveCallHistory(history);
      }

      // 3. 相手に星1評価を自動送信（緊急通報として）
      await _evaluationService.submitEvaluation(
        callId: widget.callId,
        partnerId: widget.partnerId,
        rating: 1,
        isDummyMatch: false,
      );

      // 4. 相手のレーティングを更新
      await _ratingService.updateRating(1, widget.partnerId);

      if (mounted) {
        // 5. 相手のプロフィール画面に遷移（通報機能付き）
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PartnerProfileScreen(
              partnerId: widget.partnerId,
              callId: widget.callId,
              isDummyMatch: false,
              showReportButton: true, // 通報ボタンを表示
            ),
          ),
        );
      }
    } catch (e) {
      print('緊急通報エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '緊急通報の処理中にエラーが発生しました。',
              style: FontSizeUtils.notoSans(fontSize: 14),
            ),
            backgroundColor: Colors.red,
          ),
        );
        
        // エラーの場合は通常の通話終了処理
        _endCall();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReporting = false;
        });
      }
    }
  }
}