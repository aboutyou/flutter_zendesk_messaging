import '../enums/message_role.dart';

/// Message data from Zendesk SDK events.
///
/// Represents a single message in a conversation.
class ZendeskMessage {
  /// Creates a new [ZendeskMessage] instance.
  const ZendeskMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.timestamp,
  });

  /// The unique message ID.
  final String id;

  /// The ID of the conversation this message belongs to.
  final String conversationId;

  /// The role of the message author (user or business).
  final ZendeskMessageRole role;

  /// The timestamp when the message was received.
  final DateTime? timestamp;

  /// Creates a [ZendeskMessage] from a map.
  ///
  /// Used for deserializing data from the native platform.
  factory ZendeskMessage.fromMap(Map<String, dynamic> map) {
    return ZendeskMessage(
      id: map['id'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      role: ZendeskMessageRole.fromString(map['role'] as String?),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : null,
    );
  }

  @override
  String toString() {
    return 'ZendeskMessage(id: $id, conversationId: $conversationId, '
        'role: $role, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZendeskMessage &&
        other.id == id &&
        other.conversationId == conversationId &&
        other.role == role &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(id, conversationId, role, timestamp);
}
