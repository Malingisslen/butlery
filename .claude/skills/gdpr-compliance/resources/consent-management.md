# Consent Management - GDPR Article 7

Comprehensive guide to implementing explicit consent management in Butlery using ConsentService.

## Overview

**GDPR Article 7** requires explicit, informed consent for data processing:
- **Explicit consent** - User must actively opt-in
- **Informed** - User knows what they're consenting to
- **Granular** - Separate consent for different purposes
- **Revocable** - User can withdraw consent anytime
- **Versioned** - Track privacy policy updates

**Implementation**: ConsentService with Firestore storage

## ConsentService

**Location**: `lib/services/account/consent_service.dart`

**Purpose**: Manage user consent for data processing activities

### Key Methods

```dart
class ConsentService {
  // Check if user has consented
  Future<bool> hasConsent(String userId, ConsentType type);

  // Request consent (grant)
  Future<void> requestConsent(String userId, ConsentType type, {required String version});

  // Revoke consent
  Future<void> revokeConsent(String userId, ConsentType type);

  // Get consent record
  Future<ConsentRecord?> getConsent(String userId, ConsentType type);

  // Get all consents for user
  Future<Map<ConsentType, ConsentRecord>> getAllConsents(String userId);
}
```

### Consent Types

```dart
enum ConsentType {
  dataProcessing,  // Required: Basic app functionality
  marketing,       // Optional: Marketing emails, notifications
  analytics,       // Optional: Usage analytics
}
```

**Rules**:
- `dataProcessing` - REQUIRED to use app
- `marketing` - OPTIONAL, can be revoked anytime
- `analytics` - OPTIONAL, can be revoked anytime

### ConsentRecord Model

```dart
class ConsentRecord {
  final String userId;
  final ConsentType type;
  final bool granted;
  final String version;  // Privacy policy version
  final DateTime timestamp;
  final String? revokedAt;  // Timestamp if revoked

  ConsentRecord({
    required this.userId,
    required this.type,
    required this.granted,
    required this.version,
    required this.timestamp,
    this.revokedAt,
  });
}
```

### Firestore Structure

```
users/{userId}/consent/{consentType}
  ├─ type: "data_processing"
  ├─ granted: true
  ├─ version: "1.0"
  ├─ timestamp: Timestamp(2025-01-31T10:00:00Z)
  └─ revokedAt: null
```

## Usage Patterns

### Pattern 1: Check Consent on App Launch

```dart
Future<bool> _checkConsent() async {
  final consentService = ServiceLocator.get<ConsentService>();
  final userId = authService.currentUserId;

  // Check if user has consented to data processing
  final hasConsented = await consentService.hasConsent(
    userId,
    ConsentType.dataProcessing,
  );

  return hasConsented;
}

@override
void initState() {
  super.initState();
  _checkAndRequestConsent();
}

Future<void> _checkAndRequestConsent() async {
  final hasConsented = await _checkConsent();

  if (!hasConsented) {
    // Show consent dialog
    final granted = await showConsentDialog(context);

    if (granted) {
      await _grantConsent();
    } else {
      // User must consent to use app
      Navigator.pushReplacementNamed(context, '/consent-required');
    }
  }
}
```

### Pattern 2: Request Consent

```dart
Future<void> _grantConsent() async {
  final consentService = ServiceLocator.get<ConsentService>();
  final userId = authService.currentUserId;

  // Grant data processing consent (required)
  await consentService.requestConsent(
    userId,
    ConsentType.dataProcessing,
    version: '1.0',
  );

  // Optionally grant marketing consent
  if (userAcceptedMarketing) {
    await consentService.requestConsent(
      userId,
      ConsentType.marketing,
      version: '1.0',
    );
  }
}
```

### Pattern 3: Revoke Consent

```dart
Future<void> _revokeMarketingConsent() async {
  final consentService = ServiceLocator.get<ConsentService>();
  final userId = authService.currentUserId;

  // Revoke marketing consent
  await consentService.revokeConsent(
    userId,
    ConsentType.marketing,
  );

  // Update UI
  setState(() {
    marketingEnabled = false;
  });

  showSnackbar('Marketing consent revoked');
}
```

### Pattern 4: Privacy Policy Update (Re-Consent)

```dart
Future<void> _checkPrivacyPolicyVersion() async {
  final consentService = ServiceLocator.get<ConsentService>();
  final userId = authService.currentUserId;

  const currentVersion = '2.0';  // New privacy policy version

  // Get existing consent
  final consent = await consentService.getConsent(
    userId,
    ConsentType.dataProcessing,
  );

  // Check if version outdated
  if (consent?.version != currentVersion) {
    // Show privacy policy update dialog
    final reConsented = await showPrivacyPolicyUpdateDialog(context);

    if (reConsented) {
      // Re-consent to new version
      await consentService.requestConsent(
        userId,
        ConsentType.dataProcessing,
        version: currentVersion,
      );
    } else {
      // User must re-consent to continue using app
      Navigator.pushReplacementNamed(context, '/consent-required');
    }
  }
}
```

## UI Components

### ConsentDialog Widget

```dart
class ConsentDialog extends StatefulWidget {
  @override
  _ConsentDialogState createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool dataProcessingConsent = false;  // Required
  bool marketingConsent = false;        // Optional
  bool analyticsConsent = false;        // Optional

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Privacy & Data Processing'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We need your consent to process your data'),
            SizedBox(height: 16),

            // Data Processing (required)
            CheckboxListTile(
              value: dataProcessingConsent,
              onChanged: (value) {
                setState(() => dataProcessingConsent = value ?? false);
              },
              title: Text('Data Processing (Required)'),
              subtitle: Text('Store recipes, menus, and settings'),
            ),

            // Marketing (optional)
            CheckboxListTile(
              value: marketingConsent,
              onChanged: (value) {
                setState(() => marketingConsent = value ?? false);
              },
              title: Text('Marketing (Optional)'),
              subtitle: Text('Receive recipe suggestions and tips'),
            ),

            // Analytics (optional)
            CheckboxListTile(
              value: analyticsConsent,
              onChanged: (value) {
                setState(() => analyticsConsent = value ?? false);
              },
              title: Text('Analytics (Optional)'),
              subtitle: Text('Help us improve the app'),
            ),

            SizedBox(height: 16),
            TextButton(
              onPressed: () => _showPrivacyPolicy(),
              child: Text('Read Privacy Policy'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: dataProcessingConsent ? () {
            Navigator.pop(context, {
              ConsentType.dataProcessing: dataProcessingConsent,
              ConsentType.marketing: marketingConsent,
              ConsentType.analytics: analyticsConsent,
            });
          } : null,  // Disabled if required consent not given
          child: Text('Accept'),
        ),
      ],
    );
  }
}
```

### ConsentSettings Widget

```dart
class ConsentSettingsView extends StatefulWidget {
  @override
  _ConsentSettingsViewState createState() => _ConsentSettingsViewState();
}

class _ConsentSettingsViewState extends State<ConsentSettingsView> {
  late final ConsentService _consentService;
  Map<ConsentType, bool> _consents = {};

  @override
  void initState() {
    super.initState();
    _consentService = ServiceLocator.get<ConsentService>();
    _loadConsents();
  }

  Future<void> _loadConsents() async {
    final userId = authService.currentUserId;
    final consents = await _consentService.getAllConsents(userId);

    setState(() {
      _consents = consents.map(
        (type, record) => MapEntry(type, record.granted),
      );
    });
  }

  Future<void> _toggleConsent(ConsentType type, bool value) async {
    final userId = authService.currentUserId;

    if (value) {
      await _consentService.requestConsent(userId, type, version: '1.0');
    } else {
      // Prevent revoking required consent
      if (type == ConsentType.dataProcessing) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Cannot Revoke'),
            content: Text('Data processing consent is required to use the app'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      await _consentService.revokeConsent(userId, type);
    }

    await _loadConsents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Consent Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            value: _consents[ConsentType.dataProcessing] ?? false,
            onChanged: null,  // Cannot toggle (required)
            title: Text('Data Processing'),
            subtitle: Text('Required to use the app'),
          ),
          SwitchListTile(
            value: _consents[ConsentType.marketing] ?? false,
            onChanged: (value) => _toggleConsent(ConsentType.marketing, value),
            title: Text('Marketing'),
            subtitle: Text('Receive recipe suggestions'),
          ),
          SwitchListTile(
            value: _consents[ConsentType.analytics] ?? false,
            onChanged: (value) => _toggleConsent(ConsentType.analytics, value),
            title: Text('Analytics'),
            subtitle: Text('Help us improve the app'),
          ),
        ],
      ),
    );
  }
}
```

## Testing Consent Management

```dart
group('ConsentService', () {
  late ConsentService service;
  late MockAuthRepository mockAuthRepo;
  late FakeFirebaseFirestore fakeFirestore;

  setUp() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuthRepo = MockAuthRepository();

    when(() => mockAuthRepo.currentUserId).thenReturn('user-123');

    service = ConsentService(
      firestore: fakeFirestore,
      authRepository: mockAuthRepo,
    );
  });

  test('user can grant consent', () async {
    await service.requestConsent(
      'user-123',
      ConsentType.dataProcessing,
      version: '1.0',
    );

    final hasConsent = await service.hasConsent(
      'user-123',
      ConsentType.dataProcessing,
    );

    expect(hasConsent, isTrue);
  });

  test('user can revoke consent', () async {
    await service.requestConsent('user-123', ConsentType.marketing, version: '1.0');
    await service.revokeConsent('user-123', ConsentType.marketing);

    final hasConsent = await service.hasConsent('user-123', ConsentType.marketing);
    expect(hasConsent, isFalse);
  });

  test('consent tracks version', () async {
    await service.requestConsent(
      'user-123',
      ConsentType.dataProcessing,
      version: '1.0',
    );

    final consent = await service.getConsent('user-123', ConsentType.dataProcessing);
    expect(consent?.version, '1.0');
  });
});
```

## Best Practices

1. **Always require explicit opt-in** - No pre-checked boxes
2. **Granular controls** - Separate consent for different purposes
3. **Version tracking** - Re-consent after privacy policy updates
4. **Easy revocation** - User can withdraw consent anytime
5. **Audit logging** - Log all consent changes
6. **UI clarity** - Clear explanations of what user is consenting to

## Related Resources

- [data-export.md](data-export.md) - Article 15 compliance
- [account-deletion.md](account-deletion.md) - Article 17 compliance
- [audit-logging.md](audit-logging.md) - Article 30 compliance

---

**Impact**: GDPR Article 7 compliance
**Benefit**: User control over data processing
**Status**: ✅ Production-ready
