# Presence Tracking

Comprehensive guide to real-time presence tracking using PresenceService: online status, typing indicators, and activity awareness.

## Overview

**PresenceService** provides real-time user presence awareness:
- **Online status** - Track which users are currently active
- **Typing indicators** - Show when users are typing messages
- **Last seen timestamps** - Display when users were last active
- **Batch querying** - Efficiently query multiple users at once

**Location**: `lib/services/presence_service.dart`

---

## PresenceService

### Key Methods

```dart
class PresenceService extends BaseService {
  // Single user presence
  Stream<UserPresence?> getPresenceStream(String userId);

  // Batch presence (up to 10 users per query due to Firestore 'in' limit)
  Stream<Map<String, UserPresence>> getMultiplePresenceStream(
    List<String> userIds,
  );

  // Check if user is online
  Future<bool> isUserOnline(String userId);

  // Typing indicators
  Future<void> startTyping(String conversationId);
  Future<void> stopTyping(String conversationId);
  Stream<List<UserPresence>> getTypingUsersStream(String conversationId);

  // Update own presence
  Future<void> updatePresence(UserStatus status);

  // Initialize presence tracking
  Future<void> initializePresence();

  // Cleanup on logout
  Future<void> cleanupPresence();
}
```

### UserPresence Model

```dart
class UserPresence {
  final String userId;
  final UserStatus status;  // online, offline, away
  final DateTime lastSeen;
  final Map<String, DateTime> typingIn;  // conversationId -> timestamp

  UserPresence({
    required this.userId,
    required this.status,
    required this.lastSeen,
    required this.typingIn,
  });

  // Check if typing in specific conversation
  bool isTypingIn(String conversationId) {
    final typingTime = typingIn[conversationId];
    if (typingTime == null) return false;

    // Typing indicator expires after 5 seconds
    return DateTime.now().difference(typingTime).inSeconds < 5;
  }
}

enum UserStatus {
  online,
  offline,
  away,
}
```

### Firebase Structure

```
presence/{userId}
  ├─ status: "online"
  ├─ lastSeen: Timestamp(2025-01-31T10:00:00Z)
  └─ typingIn: {
       "conversation-123": Timestamp(2025-01-31T10:00:05Z),
       "conversation-456": Timestamp(2025-01-31T09:58:30Z)
     }
```

---

## Automatic Features

### Heartbeat (1-minute interval)

```dart
// Automatically update presence every minute
Timer.periodic(Duration(minutes: 1), (_) async {
  await _updatePresenceHeartbeat();
});

Future<void> _updatePresenceHeartbeat() async {
  final userId = _authRepository.currentUserId;
  if (userId == null) return;

  await _firestoreRepository.update('presence/$userId', {
    'status': UserStatus.online.toString(),
    'lastSeen': FieldValue.serverTimestamp(),
  });
}
```

### Typing Cleanup (5-second expiry)

```dart
// Remove stale typing indicators
Timer.periodic(Duration(seconds: 5), (_) async {
  await _cleanupStaleTypingIndicators();
});

Future<void> _cleanupStaleTypingIndicators() async {
  final now = DateTime.now();
  final fiveSecondsAgo = now.subtract(Duration(seconds: 5));

  // Remove typing entries older than 5 seconds
  final updates = <String, dynamic>{};
  for (final conversationId in _currentTypingIn.keys) {
    final typingTime = _currentTypingIn[conversationId]!;
    if (typingTime.isBefore(fiveSecondsAgo)) {
      updates['typingIn.$conversationId'] = FieldValue.delete();
    }
  }

  if (updates.isNotEmpty) {
    await _firestoreRepository.update('presence/$userId', updates);
  }
}
```

### Debouncing (500ms for typing)

```dart
Timer? _typingDebounce;

Future<void> startTyping(String conversationId) async {
  // Cancel previous debounce
  _typingDebounce?.cancel();

  // Debounce typing updates (max 1 update per 500ms)
  _typingDebounce = Timer(Duration(milliseconds: 500), () async {
    await _updateTypingStatus(conversationId, isTyping: true);
  });
}
```

---

## Usage Patterns

### Pattern 1: Display Online Status

```dart
class UserOnlineIndicator extends StatelessWidget {
  final String userId;

  @override
  Widget build(BuildContext context) {
    final presenceService = ServiceLocator.get<PresenceService>();

    return StreamBuilder<UserPresence?>(
      stream: presenceService.getPresenceStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(width: 12, height: 12);  // Empty placeholder
        }

        final presence = snapshot.data!;
        final isOnline = presence.status == UserStatus.online;
        final lastSeen = presence.lastSeen;

        return Tooltip(
          message: isOnline
              ? 'Online'
              : 'Senast sedd ${_formatLastSeen(lastSeen)}',
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        );
      },
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'just nu';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min sedan';
    if (difference.inHours < 24) return '${difference.inHours} timmar sedan';
    return '${difference.inDays} dagar sedan';
  }
}
```

### Pattern 2: Batch Presence (Multiple Users)

```dart
class ParticipantAvatars extends StatelessWidget {
  final List<String> userIds;

  @override
  Widget build(BuildContext context) {
    final presenceService = ServiceLocator.get<PresenceService>();

    return StreamBuilder<Map<String, UserPresence>>(
      stream: presenceService.getMultiplePresenceStream(userIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();

        final presences = snapshot.data!;

        return Row(
          children: userIds.map((userId) {
            final presence = presences[userId];
            final isOnline = presence?.status == UserStatus.online;

            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(_getUserAvatar(userId)),
                    radius: 20,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
```

**Note**: Firestore 'in' query limit is 10, so batch queries are automatically split:

```dart
Stream<Map<String, UserPresence>> getMultiplePresenceStream(
  List<String> userIds,
) {
  // Split into chunks of 10 (Firestore 'in' limit)
  final chunks = _chunkList(userIds, 10);

  // Merge streams from all chunks
  return CombineLatestStream(
    chunks.map((chunk) => _getPresenceBatch(chunk)),
    (List<Map<String, UserPresence>> batches) {
      // Merge all batch results
      final merged = <String, UserPresence>{};
      for (final batch in batches) {
        merged.addAll(batch);
      }
      return merged;
    },
  );
}
```

### Pattern 3: Typing Indicators

```dart
class ChatTypingIndicator extends StatelessWidget {
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final presenceService = ServiceLocator.get<PresenceService>();

    return StreamBuilder<List<UserPresence>>(
      stream: presenceService.getTypingUsersStream(conversationId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox.shrink();
        }

        final typingUsers = snapshot.data!;
        final names = typingUsers
            .map((p) => _getUserDisplayName(p.userId))
            .take(3)  // Show max 3 names
            .join(', ');

        final displayText = typingUsers.length > 3
            ? '$names och ${typingUsers.length - 3} andra skriver...'
            : '$names skriver...';

        return Row(
          children: [
            ThreeDotsAnimation(),
            SizedBox(width: 8),
            Text(
              displayText,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }
}

class ThreeDotsAnimation extends StatefulWidget {
  @override
  _ThreeDotsAnimationState createState() => _ThreeDotsAnimationState();
}

class _ThreeDotsAnimationState extends State<ThreeDotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            SizedBox(width: 4),
            _buildDot(1),
            SizedBox(width: 4),
            _buildDot(2),
          ],
        );
      },
    );
  }

  Widget _buildDot(int index) {
    final delay = index * 0.3;
    final opacity = ((_controller.value + delay) % 1.0) < 0.5 ? 1.0 : 0.3;

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}
```

### Pattern 4: Update Typing Status

```dart
class MessageInputField extends StatefulWidget {
  final String conversationId;

  @override
  _MessageInputFieldState createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField> {
  late final PresenceService _presenceService;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _presenceService = ServiceLocator.get<PresenceService>();
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) {
      // Stop typing when input cleared
      _stopTyping();
      return;
    }

    // Start typing indicator
    _presenceService.startTyping(widget.conversationId);

    // Reset timer - stop typing after 3 seconds of inactivity
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 3), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    _presenceService.stopTyping(widget.conversationId);
    _typingTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTyping();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: _onTextChanged,
      decoration: InputDecoration(
        hintText: 'Skriv meddelande...',
      ),
    );
  }
}
```

---

## Initialization and Cleanup

### Initialize on App Start

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializePresence();
  }

  Future<void> _initializePresence() async {
    final presenceService = ServiceLocator.get<PresenceService>();
    await presenceService.initializePresence();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(...);
  }
}
```

### Cleanup on Logout

```dart
Future<void> logout() async {
  final presenceService = ServiceLocator.get<PresenceService>();
  final authService = ServiceLocator.get<AuthService>();

  // Set status to offline
  await presenceService.cleanupPresence();

  // Sign out
  await authService.signOut();

  // Navigate to login
  Navigator.pushReplacementNamed(context, '/login');
}
```

---

## Testing

```dart
group('PresenceService', () {
  late PresenceService service;
  late MockFirestoreRepository mockFirestore;
  late MockAuthRepository mockAuth;

  setUp() {
    mockFirestore = MockFirestoreRepository();
    mockAuth = MockAuthRepository();

    when(() => mockAuth.currentUserId).thenReturn('user-123');

    service = PresenceService(
      firestoreRepository: mockFirestore,
      authRepository: mockAuth,
    );
  });

  test('initializePresence sets user online', () async {
    await service.initializePresence();

    verify(() => mockFirestore.update(
      'presence/user-123',
      argThat(containsPair('status', 'online')),
    )).called(1);
  });

  test('startTyping updates typingIn field', () async {
    await service.startTyping('conversation-123');

    verify(() => mockFirestore.update(
      'presence/user-123',
      argThat(contains('typingIn.conversation-123')),
    )).called(1);
  });

  test('stopTyping removes typingIn entry', () async {
    await service.stopTyping('conversation-123');

    verify(() => mockFirestore.update(
      'presence/user-123',
      argThat(containsPair(
        'typingIn.conversation-123',
        FieldValue.delete(),
      )),
    )).called(1);
  });

  test('getPresenceStream emits user presence', () async {
    final stream = service.getPresenceStream('user-456');

    expect(
      stream,
      emits(isA<UserPresence>().having(
        (p) => p.userId,
        'userId',
        'user-456',
      )),
    );
  });

  test('isTypingIn returns true for recent typing', () {
    final presence = UserPresence(
      userId: 'user-123',
      status: UserStatus.online,
      lastSeen: DateTime.now(),
      typingIn: {
        'conversation-123': DateTime.now(),  // Just now
      },
    );

    expect(presence.isTypingIn('conversation-123'), isTrue);
  });

  test('isTypingIn returns false for stale typing', () {
    final presence = UserPresence(
      userId: 'user-123',
      status: UserStatus.online,
      lastSeen: DateTime.now(),
      typingIn: {
        'conversation-123': DateTime.now().subtract(Duration(seconds: 10)),  // 10 seconds ago
      },
    );

    expect(presence.isTypingIn('conversation-123'), isFalse);
  });
});
```

---

## Best Practices

1. **Initialize presence on app start**
   - Call `initializePresence()` in main app widget
   - Set up heartbeat timer
   - Handle app lifecycle (foreground/background)

2. **Clean up on logout**
   - Set status to offline
   - Clear typing indicators
   - Cancel heartbeat timer

3. **Debounce typing indicators**
   - Don't send updates on every keystroke
   - Use 500ms debounce
   - Stop typing after 3 seconds of inactivity

4. **Batch presence queries**
   - Use `getMultiplePresenceStream()` for lists
   - Firestore limits 'in' queries to 10 items
   - Service automatically chunks requests

5. **Expire stale data**
   - Typing indicators expire after 5 seconds
   - Heartbeat updates every 1 minute
   - Clean up stale presence on app startup

6. **Handle offline state gracefully**
   - Show last seen timestamp when offline
   - Don't assume presence data is always available
   - Provide fallback UI for missing presence

---

## Related Resources

- [realtime-services.md](realtime-services.md) - RealtimeRecipeService, RealtimeMenuService
- [ui-integration.md](ui-integration.md) - StreamBuilder patterns and UI components
- [realtime-models.md](realtime-models.md) - RealtimeResource models

---

**Features**: Online status, typing indicators, last seen
**Performance**: Debounced updates, batched queries, automatic cleanup
**Status**: ✅ Production-ready
