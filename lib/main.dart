// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:english_words/english_words.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
// Firebase の初期化を行うための設定


// late final String geminiApiKey;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await dotenv.load(); // .env を読み込む
  // geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MyAppState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Namer App')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Start AI Chat'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
          },
        ),
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({super.key, required this.pair});

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: '${pair.first} ${pair.second}',
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 必要な変数を宣言（コメントアウトを解除）
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<({String from, String text})> _messages = [];
  // Firebase AI Logic に移行後のモデル変数
  late final GenerativeModel _aiModel; // 名前を変更しました
  late final ChatSession _session;
  bool _isSending = false; // コメントアウトを解除

  // speech_to_text および flutter_tts の変数も宣言
  late final stt.SpeechToText _speech;
  late final FlutterTts _tts;
  bool _speechEnabled = false; // コメントアウトを解除

  @override
  void initState() {
    super.initState(); // StatefulWidget を使う場合、initState の最初に super.initState() を呼ぶのが慣習的です

    // Firebase AI Logic を使った AI モデルの初期化
    // ここで GenerativeModel を初期化します
    // 前回の説明で修正した内容をここに反映
    _aiModel = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash-preview-05-20');
    _session = _aiModel.startChat(); // 初期化したモデルからチャットセッションを開始

    // speech_to_text および flutter_tts の初期化
    _speech = stt.SpeechToText(); // <-- ここに移動
    _tts = FlutterTts();          // <-- ここに移動
    _initSpeech();                // <-- ここに移動
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isSending) return;
    final userText = _controller.text.trim();
    setState(() {
      _messages.add((from: 'me', text: userText));
      _isSending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await _session.sendMessage(Content.text(userText));
      final aiText = response.text ?? '';
      setState(() {
        _messages.add((from: 'ai', text: aiText));
      });
      if (aiText.isNotEmpty) {
        _tts.stop();
        await _tts.speak(aiText);
      }
    } catch (e) {
      setState(() {
        _messages.add((from: 'error', text: 'Error: $e'));
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  Future<void> _toggleRecording() async {
    if (!_speechEnabled) return;
    if (_speech.isListening) {
      _speech.stop();
    } else {
      _speech.listen(
        onResult: (result) {
          _controller.text = result.recognizedWords;
        },
      );
    }
    setState(() {}); // update UI mic icon
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Conversation')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isMe = m.from == 'me';
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Say something...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_speech.isListening ? Icons.mic_off : Icons.mic),
                  onPressed: _toggleRecording,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
