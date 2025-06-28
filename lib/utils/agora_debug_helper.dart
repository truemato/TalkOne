// lib/utils/agora_debug_helper.dart

import 'package:flutter/material.dart';

class AgoraDebugHelper {
  static void showDebugInfo(BuildContext context, {
    required String channelName,
    required String userId,
    required String partnerId,
    required bool isConnected,
    String? connectionState,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agora Debug Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Channel: $channelName'),
            Text('Your ID: ${userId.substring(0, 8)}...'),
            Text('Partner ID: ${partnerId.substring(0, 8)}...'),
            Text('Connected: $isConnected'),
            if (connectionState != null)
              Text('State: $connectionState'),
            const SizedBox(height: 16),
            const Text('トラブルシューティング:', 
              style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('1. マイク権限を確認'),
            const Text('2. 両方のデバイスが同じチャンネルか確認'),
            const Text('3. ネットワーク接続を確認'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}