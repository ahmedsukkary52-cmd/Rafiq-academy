import 'package:flutter/rendering.dart';

/// WhatsApp-like bubble placement for the RTL Chat room.
///
/// The Chat page is wrapped in [TextDirection.rtl], so **start = right**.
/// Outgoing (`isMine`) sits on the start side; incoming sits on the end side.
class ChatMessageAlignment {
  const ChatMessageAlignment._();

  static AlignmentGeometry bubbleAlignment({required bool isMine}) {
    return isMine
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd;
  }

  static CrossAxisAlignment contentCrossAxis({required bool isMine}) {
    return isMine ? CrossAxisAlignment.start : CrossAxisAlignment.end;
  }

  /// Tail (tight corner) on the side the bubble sits on.
  static BorderRadiusGeometry bubbleBorderRadius({required bool isMine}) {
    return BorderRadiusDirectional.only(
      topStart: const Radius.circular(18),
      topEnd: const Radius.circular(18),
      bottomStart: Radius.circular(isMine ? 4 : 18),
      bottomEnd: Radius.circular(isMine ? 18 : 4),
    );
  }

  static double maxBubbleWidth(double screenWidth) => screenWidth * 0.78;
}
