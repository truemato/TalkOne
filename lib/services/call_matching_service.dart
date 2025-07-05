// lib/services/call_matching_service.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'evaluation_service.dart';
import 'matching_warmup_service.dart';
import 'block_service.dart';

enum CallStatus {
  waiting,      // 待機中
  matched,      // マッチング完了
  calling,      // 通話中
  finished,     // 通話終了
  cancelled,    // キャンセル
}

class CallMatchingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;
  final EvaluationService _evaluationService = EvaluationService();
  final MatchingWarmupService _warmupService = MatchingWarmupService();
  final BlockService _blockService = BlockService();
  
  StreamSubscription? _matchingSubscription;
  String? _currentCallId;
  
  // 通話リクエストを作成（通話ボタンを押したとき）
  Future<String> createCallRequest({
    bool forceAIMatch = false,
    bool enableAIFilter = false,
    bool privacyMode = false,
  }) async {
    // まず古い自分のリクエストをクリーンアップ
    await _cleanupOldRequests();
    
    final callRequestRef = _db.collection('callRequests').doc();
    
    // ユーザーの現在のレーティングを取得
    final userRating = await _evaluationService.getUserRating();
    
    // 多段階AI救済システム
    // 850→880, 700→730, 550→580 の3段階でAI救済
    bool shouldForceAI = forceAIMatch;
    String? autoAIReason;
    
    if (userRating <= 550) {
      shouldForceAI = true;
      autoAIReason = 'multi_stage_rescue_550';
      print('レート$userRatingが550以下のため、AI救済（550→580目標）を実行します');
    } else if (userRating > 550 && userRating <= 580) {
      // 550-580の間はAI練習中
      shouldForceAI = true;
      autoAIReason = 'multi_stage_rescue_550_ongoing';
      print('レート$userRatingが550-580の範囲のため、AI救済継続中（580到達まで）');
    } else if (userRating > 580 && userRating <= 700) {
      shouldForceAI = true;
      autoAIReason = 'multi_stage_rescue_700';
      print('レート$userRatingが700以下のため、AI救済（700→730目標）を実行します');
    } else if (userRating > 700 && userRating <= 730) {
      // 700-730の間はAI練習中
      shouldForceAI = true;
      autoAIReason = 'multi_stage_rescue_700_ongoing';
      print('レート$userRatingが700-730の範囲のため、AI救済継続中（730到達まで）');
    } else if (userRating > 730 && userRating <= 850) {
      shouldForceAI = true;
      autoAIReason = 'multi_stage_rescue_850';
      print('レート$userRatingが850以下のため、AI救済（850→880目標）を実行します');
    } else if (userRating > 850 && userRating <= 880) {
      // 850-880の間はAI練習中
      shouldForceAI = true;
      autoAIReason = 'multi_stage_rescue_850_ongoing';
      print('レート$userRatingが850-880の範囲のため、AI救済継続中（880到達まで）');
    } else if (userRating > 880) {
      // 880を超えたら人間とのマッチングに戻る
      shouldForceAI = false;
      print('レート$userRatingが880を超えたため、人間とのマッチングに戻ります');
    }
    
    // 会話テーマをランダムに選択
    final conversationTheme = _generateRandomTheme();
    
    await callRequestRef.set({
      'userId': _userId,
      'status': CallStatus.waiting.name,
      'createdAt': FieldValue.serverTimestamp(),
      'matchedWith': null,
      'channelName': null,
      'userRating': userRating,
      'forceAIMatch': shouldForceAI,
      'enableAIFilter': enableAIFilter,
      'privacyMode': privacyMode,
      'autoAIReason': autoAIReason, // 多段階AI救済理由を記録
      'conversationTheme': conversationTheme, // 共有話題を追加
    });
    
    _currentCallId = callRequestRef.id;
    return callRequestRef.id;
  }
  
  // 古いリクエストをクリーンアップ
  Future<void> _cleanupOldRequests() async {
    try {
      final oldRequests = await _db
          .collection('callRequests')
          .where('userId', isEqualTo: _userId)
          .get();
      
      for (final doc in oldRequests.docs) {
        await doc.reference.delete();
        print('古いリクエストを削除: ${doc.id}');
      }
    } catch (e) {
      print('古いリクエストクリーンアップエラー: $e');
    }
  }
  
  // マッチング待機を開始
  Stream<CallMatch?> startMatching(String callRequestId) {
    final controller = StreamController<CallMatch?>();
    
    // 他の待機中のリクエストを検索してマッチング
    _findAndMatch(callRequestId);
    
    // リアルタイムでマッチング状況を監視
    _matchingSubscription = _db
        .collection('callRequests')
        .doc(callRequestId)
        .snapshots()
        .listen(
          (snapshot) {
            try {
              if (!snapshot.exists) {
                print('マッチングリスナー: ドキュメントが存在しません');
                controller.add(null);
                return;
              }
              
              final data = snapshot.data()!;
              final statusString = data['status'] as String?;
              
              if (statusString == null) {
                print('マッチングリスナー: ステータスがnullです');
                return;
              }
              
              final status = CallStatus.values.byName(statusString);
              print('マッチングリスナー: ステータス更新 - $status');
              
              if (status == CallStatus.matched) {
                final partnerId = data['matchedWith'] as String?;
                final channelName = data['channelName'] as String?;
                
                if (partnerId != null && channelName != null) {
                  // マッチング成立時のエンジンウォームアップ
                  _warmupService.warmupEnginesOnMatching().then((success) {
                    if (success) {
                      print('VOICEVOX Engineウォームアップ完了');
                    } else {
                      print('VOICEVOX Engineウォームアップ失敗（通話には影響なし）');
                    }
                  });
                  final match = CallMatch(
                    callId: callRequestId,
                    partnerId: partnerId,
                    channelName: channelName,
                    status: status,
                    enableAIFilter: data['enableAIFilter'] ?? false,
                    privacyMode: data['privacyMode'] ?? false,
                    conversationTheme: data['conversationTheme'] as String?,
                  );
                  print('マッチングリスナー: マッチ成功を通知 - $partnerId');
                  controller.add(match);
                } else {
                  print('マッチングリスナー: マッチデータが不完全です');
                }
              } else if (status == CallStatus.cancelled || status == CallStatus.finished) {
                print('マッチングリスナー: マッチング終了/キャンセル');
                controller.add(null);
                controller.close();
              }
            } catch (e) {
              print('マッチングリスナーエラー: $e');
              controller.addError(e);
            }
          },
          onError: (error) {
            print('マッチングリスナー購読エラー: $error');
            controller.addError(error);
          },
        );
    
    return controller.stream;
  }
  
  // 待機中の他のユーザーを検索してマッチング
  Future<void> _findAndMatch(String callRequestId) async {
    try {
      print('通話マッチング: 他のユーザーを検索中... (自分: $_userId)');
      
      await _db.runTransaction((transaction) async {
        // 自分のリクエスト情報を取得
        final myRequestDoc = await transaction.get(_db.collection('callRequests').doc(callRequestId));
        if (!myRequestDoc.exists) {
          print('通話マッチング: 自分のリクエストが存在しません');
          return;
        }
        
        final myData = myRequestDoc.data()!;
        
        // すでにマッチング済みかチェック
        final currentStatus = myData['status'];
        if (currentStatus != CallStatus.waiting.name) {
          print('通話マッチング: 既に状態が変更されています - $currentStatus');
          return;
        }
        
        final myRating = (myData['userRating'] ?? 1000.0).toDouble();
        final forceAIMatch = myData['forceAIMatch'] ?? false;
        
        // AI強制マッチングの場合、即座にAIパートナーを作成
        if (forceAIMatch) {
          print('通話マッチング: AI練習モードを開始');
          await _createAIPartner(callRequestId, transaction);
          return;
        }
        
        // レーティングベースマッチング
        final availablePartners = await _findRatingBasedPartners(myRating);
        
        print('通話マッチング: 利用可能なパートナー数: ${availablePartners.length}');
        
        if (availablePartners.isNotEmpty) {
          final partnerDoc = availablePartners.first;
          final partnerId = partnerDoc['userId'];
          
          // 相手のリクエストも再確認（データ競合防止）
          final partnerRequestDoc = await transaction.get(_db.collection('callRequests').doc(partnerDoc.id));
          if (!partnerRequestDoc.exists || partnerRequestDoc.data()?['status'] != CallStatus.waiting.name) {
            print('通話マッチング: 相手のリクエストが無効です');
            return;
          }
          
          // チャンネル名を生成
          final channelName = _generateChannelName();
          
          // 両方のリクエストをマッチ済みに更新
          final myRequestRef = _db.collection('callRequests').doc(callRequestId);
          final partnerRequestRef = _db.collection('callRequests').doc(partnerDoc.id);
          
          // 自分のconversationThemeを相手にも同期
          final myConversationTheme = myData['conversationTheme'] as String?;
          
          // 更新データ
          final updateData = {
            'status': CallStatus.matched.name,
            'channelName': channelName,
            'matchedAt': FieldValue.serverTimestamp(),
            'conversationTheme': myConversationTheme, // 共有話題を同期
          };
          
          transaction.update(myRequestRef, {
            ...updateData,
            'matchedWith': partnerId,
          });
          
          transaction.update(partnerRequestRef, {
            ...updateData,
            'matchedWith': _userId,
          });
          
          print('マッチング成功: $_userId <-> $partnerId (チャンネル: $channelName)');
        } else {
          print('通話マッチング: 適切なパートナーが見つかりませんでした');
          
          // 段階的マッチング範囲拡大
          _scheduleExpandedMatching(callRequestId, myRating);
        }
      });
    } catch (e) {
      print('マッチングエラー: $e');
    }
  }

  // レーティングベースのパートナー検索
  Future<List<QueryDocumentSnapshot>> _findRatingBasedPartners(double myRating) async {
    try {
      // インデックスが不要なシンプルなクエリに変更
      final waitingRequests = await _db
          .collection('callRequests')
          .where('status', isEqualTo: CallStatus.waiting.name)
          .limit(50)  // 多めに取得してクライアント側でフィルタリング
          .get();
      
      // クライアント側でレーティング範囲フィルタリング（999基準に調整）
      var ratingRange = 50.0;  // ±50ポイント
      const maxRange = 150.0;  // 最大±150ポイント
      
      while (ratingRange <= maxRange) {
        final minRating = myRating - ratingRange;
        final maxRating = myRating + ratingRange;
        
        // 自分以外で、レーティング範囲内、AI強制マッチング以外、ブロックされていないユーザーを検索
        final potentialPartners = waitingRequests.docs
            .where((doc) {
              final data = doc.data();
              final userRating = (data['userRating'] ?? 1000.0).toDouble();
              return doc['userId'] != _userId && 
                     userRating >= minRating &&
                     userRating <= maxRating &&
                     !(data['forceAIMatch'] ?? false);
            })
            .toList();

        // ブロック関係をチェックして最終的な利用可能パートナーを決定
        final availablePartners = <QueryDocumentSnapshot>[];
        for (final partner in potentialPartners) {
          final partnerId = partner['userId'] as String;
          final canMatch = await _blockService.canUsersMatch(_userId, partnerId);
          if (canMatch) {
            availablePartners.add(partner);
          } else {
            print('ブロック関係のためマッチング除外: $partnerId');
          }
        }
        
        if (availablePartners.isNotEmpty) {
          // レーティング差で並び替え
          availablePartners.sort((a, b) {
            final aRating = (a['userRating'] ?? 1000.0).toDouble();
            final bRating = (b['userRating'] ?? 1000.0).toDouble();
            final aDiff = (aRating - myRating).abs();
            final bDiff = (bRating - myRating).abs();
            return aDiff.compareTo(bDiff);
          });
          
          return availablePartners;
        }
        
        // 範囲を拡大して再検索
        ratingRange += 10.0;
      }
    } catch (e) {
      print('レーティングベースパートナー検索エラー: $e');
    }
    
    return [];
  }

  // 段階的マッチング範囲拡大
  void _scheduleExpandedMatching(String callRequestId, double myRating) {
    // 10秒後：範囲を大幅拡大して再検索
    Future.delayed(const Duration(seconds: 10), () async {
      try {
        final stillWaiting = await _db.collection('callRequests').doc(callRequestId).get();
        if (stillWaiting.exists && stillWaiting.data()?['status'] == CallStatus.waiting.name) {
          print('通話マッチング: 拡大範囲で再検索');
          
          // 全レーティング範囲で検索
          final waitingRequests = await _db
              .collection('callRequests')
              .where('status', isEqualTo: CallStatus.waiting.name)
              .limit(20)
              .get();
          
          final potentialPartners = waitingRequests.docs
              .where((doc) => doc['userId'] != _userId)
              .toList();

          // ブロック関係をチェックして最終的な利用可能パートナーを決定
          final availablePartners = <QueryDocumentSnapshot>[];
          for (final partner in potentialPartners) {
            final partnerId = partner['userId'] as String;
            final canMatch = await _blockService.canUsersMatch(_userId, partnerId);
            if (canMatch) {
              availablePartners.add(partner);
            } else {
              print('拡大マッチング - ブロック関係のためマッチング除外: $partnerId');
            }
          }
          
          if (availablePartners.isNotEmpty) {
            final partnerDoc = availablePartners.first;
            final partnerId = partnerDoc['userId'];
            final channelName = _generateChannelName();
            
            await _db.runTransaction((transaction) async {
              // 両方のリクエストの状態を再確認
              final myDoc = await transaction.get(_db.collection('callRequests').doc(callRequestId));
              final partnerRequestDoc = await transaction.get(_db.collection('callRequests').doc(partnerDoc.id));
              
              if (!myDoc.exists || myDoc.data()?['status'] != CallStatus.waiting.name) {
                print('拡大マッチング: 自分のリクエストが無効です');
                return;
              }
              
              if (!partnerRequestDoc.exists || partnerRequestDoc.data()?['status'] != CallStatus.waiting.name) {
                print('拡大マッチング: 相手のリクエストが無効です');
                return;
              }
              
              // 自分のconversationThemeを相手にも同期
              final myConversationTheme = myDoc.data()?['conversationTheme'] as String?;
              
              // 更新データ
              final updateData = {
                'status': CallStatus.matched.name,
                'channelName': channelName,
                'matchedAt': FieldValue.serverTimestamp(),
                'conversationTheme': myConversationTheme, // 共有話題を同期
              };
              
              transaction.update(_db.collection('callRequests').doc(callRequestId), {
                ...updateData,
                'matchedWith': partnerId,
              });
              
              transaction.update(_db.collection('callRequests').doc(partnerDoc.id), {
                ...updateData,
                'matchedWith': _userId,
              });
            });
            
            print('拡大範囲マッチング成功: $_userId <-> $partnerId');
          } else {
            // 20秒後：AI練習パートナーを提案（AI機能無効化のためコメントアウト）
            // Future.delayed(const Duration(seconds: 10), () async {
            //   final stillWaiting2 = await _db.collection('callRequests').doc(callRequestId).get();
            //   if (stillWaiting2.exists && stillWaiting2.data()?['status'] == CallStatus.waiting.name) {
            //     print('通話マッチング: AI練習パートナーを作成');
            //     await _createAIPartner(callRequestId, null);
            //   }
            // });
          }
        }
      } catch (e) {
        print('拡大マッチングエラー: $e');
      }
    });
  }
  
  // AI練習パートナーを作成
  Future<void> _createAIPartner(String callRequestId, Transaction? transaction) async {
    final channelName = _generateChannelName();
    
    // ユーザー設定からAI性格を取得
    final userProfile = await FirebaseFirestore.instance
        .collection('userProfiles')
        .doc(_userId)
        .get();
    
    final aiPersonalityId = userProfile.data()?['aiPersonalityId'] ?? 0; // デフォルト: ずんだもん
    
    final personalityNames = ['zundamon', 'kasukabe_tsumugi', 'shikoku_metan', 'aoyama_ryusei', 'meimei_himari'];
    final selectedPersonality = personalityNames[aiPersonalityId];
    
    final aiPartnerId = 'ai_${selectedPersonality}_${DateTime.now().millisecondsSinceEpoch}';
    
    // 現在のconversationThemeを取得
    String? conversationTheme;
    if (transaction != null) {
      final myRequestDoc = await transaction.get(_db.collection('callRequests').doc(callRequestId));
      conversationTheme = myRequestDoc.data()?['conversationTheme'] as String?;
    } else {
      final myRequestDoc = await _db.collection('callRequests').doc(callRequestId).get();
      conversationTheme = myRequestDoc.data()?['conversationTheme'] as String?;
    }
    
    final updateData = {
      'status': CallStatus.matched.name,
      'matchedWith': aiPartnerId,
      'channelName': channelName,
      'matchedAt': FieldValue.serverTimestamp(),
      'isDummyMatch': true,  // AI練習のフラグ
      'isAIMatch': true,     // AI練習専用フラグ
      'conversationTheme': conversationTheme, // 話題を保持
      'aiPersonalityId': aiPersonalityId, // AI性格ID追加
    };

    if (transaction != null) {
      transaction.update(_db.collection('callRequests').doc(callRequestId), updateData);
    } else {
      await _db.collection('callRequests').doc(callRequestId).update(updateData);
    }
    
    print('AI練習パートナー作成完了: $aiPartnerId (性格ID: $aiPersonalityId, チャンネル: $channelName)');
  }

  // テスト用ダミーパートナーを作成（後方互換性のため残す）（AI機能無効化のためコメントアウト）
  // Future<void> _createDummyPartner(String callRequestId) async {
  //   await _createAIPartner(callRequestId, null);
  // }
  
  // チャンネル名を生成
  String _generateChannelName() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNumber = random.nextInt(9999);
    return 'talkone_${timestamp}_$randomNumber';
  }
  
  // 通話リクエストをキャンセル
  Future<void> cancelCallRequest(String callRequestId) async {
    try {
      await _db.collection('callRequests').doc(callRequestId).update({
        'status': CallStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      print('通話リクエストキャンセル完了: $callRequestId');
    } catch (e) {
      print('通話リクエストキャンセルエラー: $e');
    } finally {
      _matchingSubscription?.cancel();
      _currentCallId = null;
    }
  }
  
  // 通話終了をマーク
  Future<void> finishCall(String callRequestId) async {
    await _db.collection('callRequests').doc(callRequestId).update({
      'status': CallStatus.finished.name,
      'finishedAt': FieldValue.serverTimestamp(),
    });
    
    _matchingSubscription?.cancel();
    _currentCallId = null;
  }
  
  // リソース解放
  void dispose() {
    _matchingSubscription?.cancel();
  }
  
  // ランダムな会話テーマを生成
  String _generateRandomTheme() {
    final conversationThemes = [
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
    
    final random = Random();
    return conversationThemes[random.nextInt(conversationThemes.length)];
  }
}

// マッチング結果を表すクラス
class CallMatch {
  final String callId;
  final String partnerId;
  final String channelName;
  final CallStatus status;
  final bool enableAIFilter;
  final bool privacyMode;
  final String? conversationTheme;
  
  CallMatch({
    required this.callId,
    required this.partnerId,
    required this.channelName,
    required this.status,
    this.enableAIFilter = false,
    this.privacyMode = false,
    this.conversationTheme,
  });
}