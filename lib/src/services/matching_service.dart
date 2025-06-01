import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'webrtc_service.dart';

class MatchingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final WebRTCService _webrtc = WebRTCService();
  static StreamSubscription? _matchSubscription;
  static StreamSubscription? _signalSubscription;
  
  static String? _currentRoomId;
  static String? _currentUserId;
  
  static Function(String roomId, String peerId)? onMatchFound;
  static Function(String error)? onError;
  static Function()? onMatchCancelled;

  /// Starts looking for a match for the given user
  static Future<void> startMatching(String userId) async {
    try {
      _currentUserId = userId;
      
      // Initialize WebRTC first
      await _webrtc.initialize();
      
      // Check if there's an existing waiting room
      final waitingRooms = await _firestore
          .collection('waiting_rooms')
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (waitingRooms.docs.isNotEmpty) {
        // Join existing room
        final roomDoc = waitingRooms.docs.first;
        final roomId = roomDoc.id;
        final peerId = roomDoc.data()['user_id'] as String;
        
        await _joinRoom(roomId, userId, peerId);
      } else {
        // Create new waiting room
        await _createWaitingRoom(userId);
      }
    } catch (e) {
      onError?.call('マッチング開始エラー: $e');
    }
  }

  static Future<void> _createWaitingRoom(String userId) async {
    try {
      final roomRef = _firestore.collection('waiting_rooms').doc();
      _currentRoomId = roomRef.id;
      
      await roomRef.set({
        'user_id': userId,
        'status': 'waiting',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Listen for someone joining this room
      _matchSubscription = roomRef.snapshots().listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          if (data['status'] == 'matched' && data['peer_id'] != null) {
            final peerId = data['peer_id'] as String;
            _handleMatchFound(_currentRoomId!, peerId, isHost: true);
          }
        }
      });

      // Set timeout for waiting
      Timer(const Duration(seconds: 30), () {
        if (_matchSubscription != null && _currentRoomId == roomRef.id) {
          cancelMatching();
          onError?.call('マッチングタイムアウト（30秒）');
        }
      });
    } catch (e) {
      onError?.call('待機ルーム作成エラー: $e');
    }
  }

  static Future<void> _joinRoom(String roomId, String userId, String peerId) async {
    try {
      _currentRoomId = roomId;
      
      // Update room status to matched
      await _firestore.collection('waiting_rooms').doc(roomId).update({
        'status': 'matched',
        'peer_id': userId,
        'matched_at': FieldValue.serverTimestamp(),
      });

      _handleMatchFound(roomId, peerId, isHost: false);
    } catch (e) {
      onError?.call('ルーム参加エラー: $e');
    }
  }

  static void _handleMatchFound(String roomId, String peerId, {required bool isHost}) {
    _currentRoomId = roomId;
    
    // Start signaling
    _setupSignaling(roomId, isHost);
    
    onMatchFound?.call(roomId, peerId);
  }

  static void _setupSignaling(String roomId, bool isHost) {
    final signalingRef = _firestore.collection('signaling').doc(roomId);
    
    _webrtc.onIceCandidate = (candidate) {
      try {
        signalingRef.collection('candidates').add({
          'candidate': candidate,
          'sender': _currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Failed to add ICE candidate: $e');
      }
    };

    _webrtc.onError = (error) {
      onError?.call(error);
    };

    // Listen for ICE candidates from peer with error handling
    _signalSubscription = signalingRef.collection('candidates')
        .orderBy('timestamp')
        .snapshots()
        .listen(
          (snapshot) {
            try {
              for (var change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added) {
                  final data = change.doc.data() as Map<String, dynamic>;
                  if (data['sender'] != _currentUserId) {
                    _webrtc.addIceCandidate(data['candidate']);
                  }
                }
              }
            } catch (e) {
              print('ICE candidate processing error: $e');
            }
          },
          onError: (error) {
            print('Signaling subscription error: $error');
            onError?.call('シグナリングエラー: $error');
          },
        );

    // Set signaling timeout
    Timer(const Duration(seconds: 45), () {
      if (_signalSubscription != null && _currentRoomId == roomId) {
        onError?.call('シグナリングタイムアウト');
      }
    });

    if (isHost) {
      _startCall(signalingRef);
    } else {
      _listenForOffer(signalingRef);
    }
  }

  static void _startCall(DocumentReference signalingRef) async {
    final offer = await _webrtc.createOffer();
    if (offer != null) {
      await signalingRef.set({
        'offer': offer,
        'type': 'offer',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Listen for answer
      signalingRef.snapshots().listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          if (data['answer'] != null && data['type'] == 'answer') {
            _webrtc.setRemoteDescription(data['answer'], 'answer');
          }
        }
      });
    }
  }

  static void _listenForOffer(DocumentReference signalingRef) {
    signalingRef.snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['offer'] != null && data['type'] == 'offer') {
          await _webrtc.setRemoteDescription(data['offer'], 'offer');
          
          final answer = await _webrtc.createAnswer();
          if (answer != null) {
            await signalingRef.update({
              'answer': answer,
              'type': 'answer',
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    });
  }

  static void cancelMatching() {
    _matchSubscription?.cancel();
    _signalSubscription?.cancel();
    _matchSubscription = null;
    _signalSubscription = null;
    
    if (_currentRoomId != null) {
      _firestore.collection('waiting_rooms').doc(_currentRoomId!).delete();
      _firestore.collection('signaling').doc(_currentRoomId!).delete();
    }
    
    _currentRoomId = null;
    _currentUserId = null;
    onMatchCancelled?.call();
  }

  static void endCall() {
    _webrtc.hangUp();
    cancelMatching();
  }

  static void dispose() {
    cancelMatching();
    _webrtc.dispose();
    onMatchFound = null;
    onError = null;
    onMatchCancelled = null;
  }
}