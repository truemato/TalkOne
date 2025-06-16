import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final double rating;
  final int totalCalls;
  final bool isAI;
  final DateTime? lastActive;
  final Map<String, dynamic>? metadata;

  UserModel({
    required this.uid,
    required this.displayName,
    this.rating = 3.0,
    this.totalCalls = 0,
    this.isAI = false,
    this.lastActive,
    this.metadata,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 3.0).toDouble(),
      totalCalls: data['totalCalls'] ?? 0,
      isAI: data['isAI'] ?? false,
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] as Timestamp).toDate()
          : null,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'rating': rating,
      'totalCalls': totalCalls,
      'isAI': isAI,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'metadata': metadata,
    };
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    double? rating,
    int? totalCalls,
    bool? isAI,
    DateTime? lastActive,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      rating: rating ?? this.rating,
      totalCalls: totalCalls ?? this.totalCalls,
      isAI: isAI ?? this.isAI,
      lastActive: lastActive ?? this.lastActive,
      metadata: metadata ?? this.metadata,
    );
  }

  // AI Bot用のファクトリーメソッド
  factory UserModel.aiBot({
    required String personalityId,
    String? displayName,
  }) {
    return UserModel(
      uid: 'ai_$personalityId',
      displayName: displayName ?? 'AI Assistant',
      rating: 5.0,
      totalCalls: 0,
      isAI: true,
      metadata: {
        'personalityId': personalityId,
        'type': 'ai_bot',
      },
    );
  }
}