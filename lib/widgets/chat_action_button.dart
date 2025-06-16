import 'package:flutter/material.dart';

class ChatActionButton extends StatelessWidget {
  final double size;
  final VoidCallback? onPressed;
  final Animation<double>? scaleAnim;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;

  const ChatActionButton({
    super.key,
    required this.size,
    this.onPressed,
    this.scaleAnim,
    this.icon = Icons.chat_bubble,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFF8BD88B),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8.0,
              spreadRadius: 1.0,
              offset: Offset(0, 4.0),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: size * 0.3,
            color: iconColor ?? const Color(0xFFF3F8B4),
          ),
        ),
      ),
    );

    if (scaleAnim != null) {
      return ScaleTransition(
        scale: scaleAnim!,
        child: button,
      );
    }

    return button;
  }
}