// lib/services/message_summarizer.dart
import 'package:firebase_ai/firebase_ai.dart';

class MessageSummarizer {
  static const int maxTokensPerMessage = 100; // 推定トークン数
  static const int tokenLimit = 8000; // 会話の最大トークン数
  
  final GenerativeModel _summarizerModel;
  
  MessageSummarizer() : 
    _summarizerModel = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.0-flash-lite',
      systemInstruction: Content.text('あなたは会話を1行に要約する専門家です。重要な情報を保持しながら、簡潔に要約してください。')
    );
  
  // トークン数を推定（簡易版）
  int estimateTokens(String text) {
    // 日本語: 1文字 ≈ 1トークン、英語: 4文字 ≈ 1トークン（概算）
    return (text.length * 0.7).round();
  }
  
  // 会話履歴の総トークン数を計算
  int calculateTotalTokens(List<({String from, String text})> messages) {
    return messages.fold(0, (sum, msg) => sum + estimateTokens(msg.text));
  }
  
  // 古いメッセージを要約
  Future<String> summarizeMessages(List<({String from, String text})> messages) async {
    final conversationText = messages
        .map((msg) => '${msg.from}: ${msg.text}')
        .join('\n');
    
    try {
      final response = await _summarizerModel.generateContent([
        Content.text('以下の会話を1行で要約してください:\n\n$conversationText')
      ]);
      
      return response.text ?? '要約できませんでした';
    } catch (e) {
      print('要約エラー: $e');
      return '要約エラー';
    }
  }
  
  // 会話履歴を圧縮
  Future<List<({String from, String text})>> compressConversation(
    List<({String from, String text})> messages,
  ) async {
    final totalTokens = calculateTotalTokens(messages);
    
    if (totalTokens < tokenLimit) {
      return messages; // 圧縮不要
    }
    
    // 古いメッセージを要約対象として抽出
    const compressRatio = 0.3; // 古い30%を要約
    final compressCount = (messages.length * compressRatio).round();
    
    if (compressCount < 2) {
      return messages; // 要約するメッセージが少なすぎる
    }
    
    final messagesToSummarize = messages.take(compressCount).toList();
    final remainingMessages = messages.skip(compressCount).toList();
    
    // 要約を生成
    final summary = await summarizeMessages(messagesToSummarize);
    
    // 要約を新しいメッセージリストの先頭に追加
    return [
      (from: 'system', text: '[以前の会話の要約] $summary'),
      ...remainingMessages,
    ];
  }
}