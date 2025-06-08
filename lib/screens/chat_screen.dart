// lib/screens/chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/chat_repository.dart';
import '../services/message_summarizer.dart';
import '../services/conversation_memory.dart';
import '../services/simple_summarizer.dart';
import '../services/personality_system.dart';
import '../services/vap_system_v2.dart';

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
  late final VAPSystemV2 _vapSystem;

  // Firestore helpers
  final _repo = ChatRepository();
  DocumentReference? _convDoc;
  
  // Message summarizer
  final _summarizer = MessageSummarizer();
  
  // Conversation memory
  final _memory = ConversationMemory();
  final _personalitySystem = PersonalitySystem();
  DateTime? _conversationStartTime;
  int? _currentPersonalityId;

  // 3‑minute timer
  Timer? _timer;
  Duration _left = const Duration(minutes: 3);
  bool _finished = false;

  bool _speechEnabled = false; // コメントアウトを解除
  VAPState _vapState = VAPState.idle;
  double _speechProgress = 0.0;
  bool _isVAPInterrupted = false;

  @override
  void initState() {
    super.initState(); // StatefulWidget を使う場合、initState の最初に super.initState() を呼ぶのが慣習的です

    // Firebase AI Logic を使った AI モデルの初期化
    _initializeAI();

    // speech_to_text および flutter_tts の初期化
    _speech = stt.SpeechToText(); // <-- ここに移動
    _tts = FlutterTts();          // <-- ここに移動
    _initSpeech();                // <-- ここに移動
    
    // VAPシステム初期化
    _vapSystem = VAPSystemV2(tts: _tts, speech: _speech);
    _initVAPSystem();

    _setupConversation();
  }
  
  Future<void> _initializeAI() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // 人格をランダムに選択
    _currentPersonalityId = PersonalitySystem.getRandomPersonality();
    
    // 選択された人格のシステムプロンプトを生成
    final systemPrompt = await _personalitySystem.generateSystemPromptWithPersonality(
      user.uid, 
      _currentPersonalityId!,
    );
    
    print('選択された人格: ${PersonalitySystem.getPersonalityName(_currentPersonalityId!)}');
    
    _aiModel = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-1.5-pro',
      systemInstruction: Content.text(systemPrompt),
    );
    _session = _aiModel.startChat();
    
    // 人格の挨拶を追加
    final greeting = PersonalitySystem.getPersonalityGreeting(_currentPersonalityId!);
    setState(() {
      _messages.add((from: 'ai', text: greeting));
    });
    
    // 初回挨拶を音声で再生
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && greeting.isNotEmpty) {
        _vapSystem.speakWithVAP(greeting);
      }
    });
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (error) => print('音声認識エラー: $error'),
        onStatus: (status) => print('音声認識ステータス: $status'),
      );
      print('音声認識初期化結果: $_speechEnabled');
      
      if (_speechEnabled) {
        final locales = await _speech.locales();
        print('利用可能な言語: ${locales.map((l) => l.localeId).join(", ")}');
      }
    } catch (e) {
      print('音声認識初期化エラー: $e');
      _speechEnabled = false;
    }
    
    try {
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.45);
      print('TTS初期化完了');
    } catch (e) {
      print('TTS初期化エラー: $e');
    }
  }
  
  void _initVAPSystem() {
    // VAPシステムのコールバック設定
    _vapSystem.onStateChanged = (state) {
      if (mounted) {
        setState(() {
          _vapState = state;
        });
      }
    };
    
    _vapSystem.onSpeechProgress = (progress) {
      if (mounted) {
        setState(() {
          _speechProgress = progress;
        });
      }
    };
    
    _vapSystem.onInterruption = () {
      print('VAPコールバック: 中断通知受信');
      if (mounted) {
        setState(() {
          _isVAPInterrupted = true;
        });
        print('VAP: 音声が中断されました - UI更新完了');
      }
    };
    
    _vapSystem.onUserSpeech = (userSpeech) {
      print('VAPコールバック: ユーザー音声受信 - "$userSpeech"');
      if (mounted) {
        // 中断後のユーザー音声をテキストフィールドに設定
        setState(() {
          _controller.text = userSpeech;
          _isVAPInterrupted = false;
        });
        // 自動的にメッセージ送信
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            print('VAP: 自動メッセージ送信実行');
            _sendMessage();
          }
        });
      }
    };
  }

  Future<void> _setupConversation() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _convDoc = await _repo.currentOrNewConv(uid);
    _conversationStartTime = DateTime.now();

    // ① 既存メッセージをロード
    final msgs = await _convDoc!
        .collection('messages')
        .orderBy('timestamp')
        .get();
    setState(() {
      _messages.addAll(msgs.docs.map((d) =>
          (from: d['sender'] as String, text: d['text'] as String)));
    });

    // ② 3分カウントダウン
    _timer?.cancel(); // 既存タイマーをキャンセル
    _left = const Duration(minutes: 3); // 3分にリセット
    _finished = false; // 終了フラグをリセット
    
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _left -= const Duration(seconds: 1);
        if (_left <= Duration.zero && !_finished) {
          _finished = true;
          // 音声再生を即座に停止
          _vapSystem.stop();
          _tts.stop();
          print('3分タイマー終了 - 音声再生を強制停止');
          _finishConversation();
          t.cancel();
        }
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isSending) return;
    final userText = _controller.text.trim();
    if (_convDoc != null) {
      await _repo.addMessage(_convDoc!, 'user', userText);
    }
    setState(() {
      _messages.add((from: 'me', text: userText));
      _isSending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      // トークン数をチェックして必要なら圧縮
      final compressedMessages = await _summarizer.compressConversation(_messages);
      if (compressedMessages.length != _messages.length) {
        setState(() {
          _messages.clear();
          _messages.addAll(compressedMessages);
        });
      }
      
      final response = await _session.sendMessage(Content.text(userText));
      var aiText = response.text ?? '';
      
      // 基本的なプロンプトインジェクション対策
      if (aiText.length > 500 || aiText.contains('減量') || aiText.contains('ダイエット') || 
          aiText.contains('医師') || aiText.contains('健康') || aiText.contains('カロリー')) {
        aiText = '申し訳ありませんが、その話題については詳しくお答えできません。他の楽しい話題にしませんか？';
      }
      
      setState(() {
        _messages.add((from: 'ai', text: aiText));
      });
      if (_convDoc != null) {
        await _repo.addMessage(_convDoc!, 'ai', aiText);
      }
      
      // 要約が実行された場合の情報を保存
      if (compressedMessages.length < _messages.length - 1) {
        final summarizedCount = _messages.length - 1 - compressedMessages.length;
        await _repo.saveSummaryInfo(_convDoc!, summarizedCount);
        
        // 要約をFirestoreにも保存
        final summaryMessage = compressedMessages.firstWhere(
          (msg) => msg.from == 'system',
          orElse: () => (from: '', text: ''),
        );
        if (summaryMessage.text.isNotEmpty && _convDoc != null) {
          await _repo.addMessage(_convDoc!, 'system', summaryMessage.text);
        }
      }
      if (aiText.isNotEmpty) {
        // VAPシステムで音声再生（中断機能付き）
        await _vapSystem.speakWithVAP(aiText);
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
    print('マイクボタンが押されました - _speechEnabled: $_speechEnabled');
    
    if (!_speechEnabled) {
      print('音声認識が無効です');
      return;
    }
    
    // VAP状態チェック
    if (_vapState == VAPState.speaking && _vapSystem.canInterrupt) {
      print('音声再生中で中断可能 - 手動中断実行');
      _vapSystem.stop();
      setState(() {
        _isVAPInterrupted = true;
        _controller.text = '手動中断テスト';
      });
      // 自動送信
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _sendMessage();
      });
      return;
    }
    
    if (_speech.isListening) {
      print('音声認識停止');
      _speech.stop();
    } else {
      print('音声認識開始');
      try {
        await _speech.listen(
          onResult: (result) {
            print('マイク結果: ${result.recognizedWords} (信頼度: ${result.confidence})');
            _controller.text = result.recognizedWords;
          },
          localeId: 'ja_JP',
          onSoundLevelChange: (level) {
            if (level > 0.1) {
              print('マイク音声レベル: $level');
            }
          },
        );
      } catch (e) {
        print('音声認識エラー: $e');
      }
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
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('残り ${_left.inMinutes}:${(_left.inSeconds % 60).toString().padLeft(2, '0')}'),
            if (_currentPersonalityId != null)
              Text(
                '${PersonalitySystem.getPersonality(_currentPersonalityId!)['emoji']} ${PersonalitySystem.getPersonalityName(_currentPersonalityId!)}',
                style: const TextStyle(fontSize: 12),
              ),
            // VAP状態表示
            if (_vapState == VAPState.speaking)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.volume_up, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '音声再生中 ${(_speechProgress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  ),
                  if (_vapSystem.canInterrupt)
                    const Text(
                      ' (中断可)',
                      style: TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                ],
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isMe = m.from == 'me';
                final isSystem = m.from == 'system';
                
                if (isSystem) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.text,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
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
          _finished
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    ),
                    child: const Text('新しい会話を始める'),
                  ),
                )
              : Padding(
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
                        icon: Icon(
                          _speech.isListening 
                              ? Icons.mic_off 
                              : _vapState == VAPState.speaking && _vapSystem.canInterrupt
                                  ? Icons.pan_tool // 中断アイコン
                                  : Icons.mic
                        ),
                        color: _vapState == VAPState.speaking && _vapSystem.canInterrupt
                            ? Colors.orange
                            : null,
                        onPressed: _toggleRecording,
                      ),
                      const SizedBox(width: 8),
                      // VAPテストボタン（音声再生中のみ表示）
                      if (_vapState == VAPState.speaking) ...[
                        IconButton(
                          icon: const Icon(Icons.stop_circle, color: Colors.red),
                          onPressed: () {
                            print('手動中断ボタンが押されました');
                            _vapSystem.stop();
                            setState(() {
                              _controller.text = '手動中断テスト';
                            });
                            _sendMessage();
                          },
                          tooltip: 'VAP手動中断',
                        ),
                        // 自動テスト中断ボタン（2秒後に自動中断）
                        IconButton(
                          icon: const Icon(Icons.timer, color: Colors.orange),
                          onPressed: () {
                            print('自動中断テスト開始 - 2秒後に中断');
                            Future.delayed(const Duration(seconds: 2), () {
                              if (_vapState == VAPState.speaking && _vapSystem.canInterrupt) {
                                print('自動中断テスト実行');
                                _vapSystem.stop();
                                setState(() {
                                  _controller.text = '2秒後自動中断テスト';
                                });
                                _sendMessage();
                              } else {
                                print('自動中断テスト失敗 - 状態: $_vapState, 中断可能: ${_vapSystem.canInterrupt}');
                              }
                            });
                          },
                          tooltip: '2秒後自動中断テスト',
                        ),
                      ],
                      const SizedBox(width: 8),
                      _isSending
                          ? const CircularProgressIndicator()
                          : IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _sendMessage,
                            ),
                    ],
                  ),
                ),
          // VAPプログレスバー
          if (_vapState == VAPState.speaking)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _speechProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _speechProgress <= 0.5 ? Colors.orange : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _speechProgress <= 0.5 
                        ? '中断可能期間 (音声で中断できます)'
                        : '継続再生中',
                    style: TextStyle(
                      fontSize: 12,
                      color: _speechProgress <= 0.5 ? Colors.orange : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _finishConversation() async {
    if (_convDoc == null || _conversationStartTime == null || _currentPersonalityId == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // 会話終了をマーク
    await _repo.finishConv(_convDoc!);
    
    // 会話のサマリーを生成（シンプル版を使用）
    final conversationDuration = DateTime.now().difference(_conversationStartTime!);
    final summary = await SimpleSummarizer.generateSimpleSummary(
      _messages.where((m) => m.from != 'system').toList(), // システムメッセージを除外
      conversationDuration,
    );
    
    // 人格付きでサマリーを保存
    await _personalitySystem.saveConversationWithPersonality(
      _convDoc!, 
      _currentPersonalityId!, 
      summary,
    );
    
    // ユーザーメモリーも保存（人格情報付き）
    final summaryWithPersonality = Map<String, dynamic>.from(summary);
    summaryWithPersonality['personalityId'] = _currentPersonalityId;
    summaryWithPersonality['personalityName'] = PersonalitySystem.getPersonalityName(_currentPersonalityId!);
    await _memory.saveUserMemory(user.uid, _convDoc!, summaryWithPersonality);
    
    // UIに詳細なサマリーを表示
    if (mounted) {
      setState(() {
        final summaryText = summaryWithPersonality['summary'] ?? 'サマリーなし';
        final topics = (summaryWithPersonality['topics'] as List<dynamic>?)?.join('、') ?? '';
        final keyPoints = (summaryWithPersonality['keyPoints'] as List<dynamic>?) ?? [];
        final personalInfo = (summaryWithPersonality['personalInfo'] as List<dynamic>?) ?? [];
        final userTraits = (summaryWithPersonality['userTraits'] as List<dynamic>?)?.join('、') ?? '';
        final duration = summaryWithPersonality['duration'] ?? '';
        final mood = summaryWithPersonality['mood'] ?? 'neutral';
        final personalityName = PersonalitySystem.getPersonalityName(_currentPersonalityId!);
        final personalityEmoji = PersonalitySystem.getPersonality(_currentPersonalityId!)['emoji'] ?? '😊';
        final error = summaryWithPersonality['error'] as String?;
        
        var displayText = '📝 会話終了 ($duration)\n';
        displayText += '$personalityEmoji 今回の相手: $personalityName\n';
        displayText += 'サマリー: $summaryText\n';
        
        if (topics.isNotEmpty) {
          displayText += '🏷️ 話題: $topics\n';
        }
        
        if (personalInfo.isNotEmpty) {
          displayText += '👤 個人情報: ${personalInfo.take(3).join('、')}\n';
        }
        
        if (userTraits.isNotEmpty) {
          displayText += '🎭 特徴: $userTraits\n';
        }
        
        if (keyPoints.isNotEmpty) {
          displayText += '🔑 重要ポイント: ${keyPoints.take(2).join('、')}\n';
        }
        
        final moodEmoji = mood == 'positive' ? '😊' : mood == 'negative' ? '😔' : '😐';
        displayText += '🌡️ 雰囲気: $moodEmoji $mood';
        
        if (error != null) {
          displayText += '\n⚠️ エラー: $error';
        }
        
        _messages.add((from: 'system', text: displayText));
      });
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    _vapSystem.dispose(); // VAPシステムのリソース解放
    _timer?.cancel();
    if (!_finished && _messages.isNotEmpty) {
      // 中途終了の場合もサマリーを保存
      _finishConversation();
    }
    super.dispose();
  }
}
