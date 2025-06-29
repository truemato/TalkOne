import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 会話データ保存・管理サービス
/// 
/// ユーザーの会話内容をSTTで文字化してFirestoreに保存し、
/// AI機能の品質向上とデータ分析に活用します。
class ConversationDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// 新しい会話セッションを開始
  Future<String> startConversationSession({
    required String partnerId,
    required ConversationType type,
    bool isAIPartner = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ユーザー認証が必要です');
    
    final sessionData = {
      'sessionId': _generateSessionId(),
      'participants': [user.uid, partnerId],
      'type': type.name,
      'isAIPartner': isAIPartner,
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'status': ConversationStatus.active.name,
      'totalDuration': 0,
      'messageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    final docRef = await _firestore
        .collection('conversation_sessions')
        .add(sessionData);
    
    print('会話セッション開始: ${docRef.id}');
    return docRef.id;
  }
  
  /// 音声メッセージ（STT結果）を保存
  Future<void> saveVoiceMessage({
    required String sessionId,
    required String speakerId,
    required String transcribedText,
    required double confidence,
    required DateTime timestamp,
    String? originalAudioUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final messageData = {
        'sessionId': sessionId,
        'speakerId': speakerId,
        'transcribedText': transcribedText,
        'confidence': confidence,
        'timestamp': Timestamp.fromDate(timestamp),
        'originalAudioUrl': originalAudioUrl,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // メッセージを保存
      await _firestore
          .collection('conversation_messages')
          .add(messageData);
      
      // セッションのメッセージ数を更新
      await _updateSessionMessageCount(sessionId);
      
      print('音声メッセージ保存完了: セッション $sessionId');
    } catch (e) {
      print('音声メッセージ保存エラー: $e');
      rethrow;
    }
  }
  
  /// AI応答を保存
  Future<void> saveAIResponse({
    required String sessionId,
    required String aiResponse,
    required String aiPersonalityId,
    required String voiceCharacter,
    Map<String, dynamic>? aiMetadata,
  }) async {
    try {
      final responseData = {
        'sessionId': sessionId,
        'speakerId': 'AI',
        'transcribedText': aiResponse,
        'confidence': 1.0, // AI応答は100%確信度
        'timestamp': FieldValue.serverTimestamp(),
        'aiPersonalityId': aiPersonalityId,
        'voiceCharacter': voiceCharacter,
        'isAIGenerated': true,
        'metadata': aiMetadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('conversation_messages')
          .add(responseData);
      
      await _updateSessionMessageCount(sessionId);
      
      print('AI応答保存完了: セッション $sessionId');
    } catch (e) {
      print('AI応答保存エラー: $e');
      rethrow;
    }
  }
  
  /// 簡単な会話保存（ずんだもんチャット用）
  Future<void> saveConversation({
    required String userId,
    required String userText,
    required String aiResponse,
    required String sessionId,
  }) async {
    try {
      final conversationData = {
        'userId': userId,
        'userText': userText,
        'aiResponse': aiResponse,
        'sessionId': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'zundamon_chat',
      };
      
      await _firestore
          .collection('conversations')
          .add(conversationData);
      
      print('ずんだもん会話保存完了: $sessionId');
    } catch (e) {
      print('会話保存エラー: $e');
    }
  }

  /// 会話セッション終了
  Future<void> endConversationSession({
    required String sessionId,
    required int actualDurationSeconds,
    ConversationEndReason? endReason,
    Map<String, int>? ratings,
  }) async {
    try {
      final updateData = {
        'endTime': FieldValue.serverTimestamp(),
        'status': ConversationStatus.completed.name,
        'totalDuration': actualDurationSeconds,
        'endReason': endReason?.name,
        'ratings': ratings,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('conversation_sessions')
          .doc(sessionId)
          .update(updateData);
      
      print('会話セッション終了: $sessionId');
    } catch (e) {
      print('セッション終了エラー: $e');
      rethrow;
    }
  }
  
  /// ユーザーの会話履歴を取得
  Future<List<ConversationSession>> getUserConversationHistory({
    int limit = 20,
    DateTime? before,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    try {
      Query query = _firestore
          .collection('conversation_sessions')
          .where('participants', arrayContains: user.uid)
          .orderBy('startTime', descending: true)
          .limit(limit);
      
      if (before != null) {
        query = query.where('startTime', isLessThan: Timestamp.fromDate(before));
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => ConversationSession.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('会話履歴取得エラー: $e');
      return [];
    }
  }
  
  /// 特定セッションのメッセージを取得
  Future<List<ConversationMessage>> getSessionMessages(String sessionId) async {
    try {
      final snapshot = await _firestore
          .collection('conversation_messages')
          .where('sessionId', isEqualTo: sessionId)
          .orderBy('timestamp')
          .get();
      
      return snapshot.docs
          .map((doc) => ConversationMessage.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('セッションメッセージ取得エラー: $e');
      return [];
    }
  }
  
  /// AI学習用データを取得（管理者用）
  Future<List<ConversationMessage>> getAITrainingData({
    int limit = 1000,
    double minConfidence = 0.8,
    DateTime? since,
  }) async {
    try {
      Query query = _firestore
          .collection('conversation_messages')
          .where('confidence', isGreaterThanOrEqualTo: minConfidence)
          .orderBy('confidence', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      
      if (since != null) {
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => ConversationMessage.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('AI学習データ取得エラー: $e');
      return [];
    }
  }
  
  /// 統計情報を取得
  Future<ConversationStats> getUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ユーザー認証が必要です');
    
    try {
      // 会話セッション数
      final sessionsSnapshot = await _firestore
          .collection('conversation_sessions')
          .where('participants', arrayContains: user.uid)
          .where('status', isEqualTo: ConversationStatus.completed.name)
          .get();
      
      final sessions = sessionsSnapshot.docs
          .map((doc) => ConversationSession.fromFirestore(doc))
          .toList();
      
      // 統計計算
      final totalSessions = sessions.length;
      final totalDuration = sessions.fold<int>(0, (sum, session) => sum + session.totalDuration);
      final averageDuration = totalSessions > 0 ? totalDuration / totalSessions : 0.0;
      
      final aiSessions = sessions.where((s) => s.isAIPartner).length;
      final humanSessions = totalSessions - aiSessions;
      
      return ConversationStats(
        totalSessions: totalSessions,
        totalDurationSeconds: totalDuration,
        averageDurationSeconds: averageDuration,
        aiSessions: aiSessions,
        humanSessions: humanSessions,
      );
    } catch (e) {
      print('統計情報取得エラー: $e');
      return ConversationStats.empty();
    }
  }
  
  /// セッションIDを生成
  String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser!.uid.substring(0, 8)}';
  }
  
  /// セッションのメッセージ数を更新
  Future<void> _updateSessionMessageCount(String sessionId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final sessionRef = _firestore
            .collection('conversation_sessions')
            .doc(sessionId);
        
        final sessionDoc = await transaction.get(sessionRef);
        if (sessionDoc.exists) {
          final currentCount = sessionDoc.data()?['messageCount'] ?? 0;
          transaction.update(sessionRef, {
            'messageCount': currentCount + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('メッセージ数更新エラー: $e');
    }
  }
}

/// 会話タイプ
enum ConversationType {
  voice,    // 音声通話
  video,    // ビデオ通話
  ai,       // AI会話
}

/// 会話ステータス
enum ConversationStatus {
  active,     // 進行中
  completed,  // 完了
  aborted,    // 中断
  error,      // エラー
}

/// 会話終了理由
enum ConversationEndReason {
  timeLimit,      // 時間制限
  userLeft,       // ユーザーが退出
  partnerLeft,    // 相手が退出
  networkError,   // ネットワークエラー
  systemError,    // システムエラー
}

/// 会話セッション
class ConversationSession {
  final String id;
  final String sessionId;
  final List<String> participants;
  final ConversationType type;
  final bool isAIPartner;
  final DateTime startTime;
  final DateTime? endTime;
  final ConversationStatus status;
  final int totalDuration;
  final int messageCount;
  final ConversationEndReason? endReason;
  final Map<String, int>? ratings;
  
  ConversationSession({
    required this.id,
    required this.sessionId,
    required this.participants,
    required this.type,
    required this.isAIPartner,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.totalDuration,
    required this.messageCount,
    this.endReason,
    this.ratings,
  });
  
  factory ConversationSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ConversationSession(
      id: doc.id,
      sessionId: data['sessionId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      type: ConversationType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ConversationType.voice,
      ),
      isAIPartner: data['isAIPartner'] ?? false,
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      status: ConversationStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ConversationStatus.active,
      ),
      totalDuration: data['totalDuration'] ?? 0,
      messageCount: data['messageCount'] ?? 0,
      endReason: data['endReason'] != null 
          ? ConversationEndReason.values.firstWhere(
              (r) => r.name == data['endReason'],
              orElse: () => ConversationEndReason.userLeft,
            )
          : null,
      ratings: data['ratings'] != null 
          ? Map<String, int>.from(data['ratings'])
          : null,
    );
  }
}

/// 会話メッセージ
class ConversationMessage {
  final String id;
  final String sessionId;
  final String speakerId;
  final String transcribedText;
  final double confidence;
  final DateTime timestamp;
  final String? originalAudioUrl;
  final bool isAIGenerated;
  final String? aiPersonalityId;
  final String? voiceCharacter;
  final Map<String, dynamic> metadata;
  
  ConversationMessage({
    required this.id,
    required this.sessionId,
    required this.speakerId,
    required this.transcribedText,
    required this.confidence,
    required this.timestamp,
    this.originalAudioUrl,
    required this.isAIGenerated,
    this.aiPersonalityId,
    this.voiceCharacter,
    required this.metadata,
  });
  
  factory ConversationMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ConversationMessage(
      id: doc.id,
      sessionId: data['sessionId'] ?? '',
      speakerId: data['speakerId'] ?? '',
      transcribedText: data['transcribedText'] ?? '',
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      originalAudioUrl: data['originalAudioUrl'],
      isAIGenerated: data['isAIGenerated'] ?? false,
      aiPersonalityId: data['aiPersonalityId'],
      voiceCharacter: data['voiceCharacter'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
}

/// 会話統計情報
class ConversationStats {
  final int totalSessions;
  final int totalDurationSeconds;
  final double averageDurationSeconds;
  final int aiSessions;
  final int humanSessions;
  
  ConversationStats({
    required this.totalSessions,
    required this.totalDurationSeconds,
    required this.averageDurationSeconds,
    required this.aiSessions,
    required this.humanSessions,
  });
  
  factory ConversationStats.empty() {
    return ConversationStats(
      totalSessions: 0,
      totalDurationSeconds: 0,
      averageDurationSeconds: 0.0,
      aiSessions: 0,
      humanSessions: 0,
    );
  }
  
  String get formattedTotalDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    final seconds = totalDurationSeconds % 60;
    
    if (hours > 0) {
      return '$hours時間$minutes分$seconds秒';
    } else if (minutes > 0) {
      return '$minutes分$seconds秒';
    } else {
      return '$seconds秒';
    }
  }
  
  String get formattedAverageDuration {
    final avgSeconds = averageDurationSeconds.round();
    final minutes = avgSeconds ~/ 60;
    final seconds = avgSeconds % 60;
    
    if (minutes > 0) {
      return '$minutes分$seconds秒';
    } else {
      return '$seconds秒';
    }
  }
}