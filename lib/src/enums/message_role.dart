/// Role of a message author in a Zendesk conversation.
///
/// Maps to native SDK values:
/// - iOS: `ZendeskRole` enum (`.user`, `.business`)
/// - Android: `ZendeskRole` enum (`USER`, `BUSINESS`)
enum ZendeskMessageRole {
  /// Message sent by the end user.
  user,

  /// Message sent by an agent or bot.
  business,

  /// Role is unknown or not recognized.
  unknown;

  /// Parse message role from string.
  ///
  /// Returns [unknown] if the value is null or not recognized.
  static ZendeskMessageRole fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'user' => ZendeskMessageRole.user,
      'business' => ZendeskMessageRole.business,
      _ => ZendeskMessageRole.unknown,
    };
  }
}
