import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool mirror;
  final RTCVideoViewObjectFit objectFit;
  final Widget? placeholder;

  const VideoView({
    super.key,
    required this.renderer,
    this.mirror = false,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (renderer.srcObject == null) {
      return placeholder ?? 
        Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(
              Icons.videocam_off,
              size: 60,
              color: Colors.white54,
            ),
          ),
        );
    }

    return RTCVideoView(
      renderer,
      mirror: mirror,
      objectFit: objectFit,
    );
  }
}

class LocalVideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final VoidCallback? onTap;

  const LocalVideoView({
    super.key,
    required this.renderer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: VideoView(
            renderer: renderer,
            mirror: true,
            placeholder: Container(
              color: Colors.grey[800],
              child: const Icon(
                Icons.person,
                color: Colors.white54,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RemoteVideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final String? peerName;
  final bool isConnected;

  const RemoteVideoView({
    super.key,
    required this.renderer,
    this.peerName,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return VideoView(
      renderer: renderer,
      placeholder: Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isConnected ? Icons.person : Icons.wifi_tethering,
                size: 100,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                peerName ?? (isConnected ? 'øKn«áéLOFFgY' : '¥š-...'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}