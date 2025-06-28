import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'settings_screens.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final bool _speechEnabled = false;
  final bool _isListening = false;

  // タイマー関連
  Timer? _timer;
  Duration _left = const Duration(minutes: 3);
  bool _finished = false;

  // テーマ設定
  final int _selectedThemeIndex = 0;

  // 選択されたアイコンのSVGパス
  final String _selectedIconPath = 'aseets/icons/Woman 1.svg';

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

    // ランダムでテーマを選択
    _currentTheme =
        _conversationThemes[Random().nextInt(_conversationThemes.length)];

    // 3分カウントダウン開始
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _left -= const Duration(seconds: 1);
        if (_left <= Duration.zero && !_finished) {
          _finished = true;
          _finishCall();
          t.cancel();
        }
      });
    });
  }

  void _finishCall() {
    // 通話終了処理
    print('通話が終了しました');
  }

  @override
  Widget build(BuildContext context) {
    final AppThemePalette theme = appThemes[_selectedThemeIndex];
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildCallStatus(),
            const SizedBox(height: 20),
            _buildThemeDisplay(),
            SizedBox(height: screenHeight * 0.10),
            _buildPartnerIcon(),
            SizedBox(height: screenHeight * 0.10),
            _buildTimer(),
            const SizedBox(height: 16),
            _buildEndCallButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCallStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F2F2),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
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
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '通話中',
            style: TextStyle(
              color: Color(0xFF4E3B7A),
              fontWeight: FontWeight.bold,
              fontSize: 16,
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

  Widget _buildPartnerIcon() {
    return Center(
      child: Container(
        width: 150,
        height: 150,
        decoration: const BoxDecoration(
          color: Color(0xFFE2E0F9),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: SvgPicture.asset(
            _selectedIconPath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${_left.inMinutes}:${(_left.inSeconds % 60).toString().padLeft(2, '0')}',
        style: GoogleFonts.notoSans(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4E3B7A),
        ),
      ),
    );
  }

  Widget _buildEndCallButton(AppThemePalette theme) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _finished = true;
          _finishCall();
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      child: const Icon(
        Icons.call_end,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
