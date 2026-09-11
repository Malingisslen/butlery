/// The group-chat history cut-off (BUT-1838), as one comparison.
///
/// Its own file because it belongs to neither caller. `Conversation` needs it
/// for the list row and the search filter; the Art. 15 export
/// (`SocialExportManager`, BUT-1854) needs it for a raw sanitised map it never
/// builds a `Conversation` from.
library;

/// Whether a message sent at [sentAt] falls inside the history a group member
/// joined into, given their own [memberSince] stamp.
///
/// Mirrors `firestore.rules`, which refuses `sentAt < memberSince[uid]` for
/// every member of a group — so the boundary itself is readable and this is
/// `!isBefore` rather than `isAfter`.
///
/// Fails CLOSED, matching the rule's `.get(uid, request.time)`.
///
/// The DIRECT-chat case, where no cut-off applies at all, is the CALLER's to
/// answer. This function is only reached once the conversation is known to be a
/// group, and answering `true` for a direct chat here would put that decision
/// in two places.
///
/// The message QUERY is deliberately NOT a caller and must not become one: it
/// needs the cut-off as a Firestore range bound rather than a boolean, and
/// `Conversation.historyQueryStartFor`'s null means "no filter" where this
/// answers false.
bool isWithinJoinedHistory({
  required DateTime sentAt,
  required DateTime? memberSince,
}) {
  if (memberSince == null) return false;
  return !sentAt.isBefore(memberSince);
}
