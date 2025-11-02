# UI Integration

Guide to offline UI patterns: indicators, sync buttons, user feedback, and reactive updates using Consumer pattern.

## Overview

**Location**: `lib/widgets/common/layout/status_indicators.dart`

**Key Components**:
- **OfflineIndicator** - Full-width banner for offline status
- **OfflineStatusIcon** - Small app bar icon
- **SyncButton** - Manual sync trigger with progress
- **QueueBadge** - Display pending changes count

**Pattern**: Consumer<OfflineService> for reactive updates

---

## OfflineIndicator Banner

### Full Implementation

```dart
class OfflineIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final offlineService = ServiceLocator.get<OfflineService>();

    return Consumer<OfflineService>(
      builder: (context, service, child) {
        // Hide if online
        if (service.isOnline) return SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          color: Colors.orange,
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline - Ändringar kommer synkas när du är online igen',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Queue badge
              if (service.hasQueuedChanges)
                Chip(
                  label: Text(
                    '${service.queuedChangesCount}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                ),
            ],
          ),
        );
      },
    );
  }
}
```

### Usage in Scaffold

```dart
class MyScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recept'),
        actions: [OfflineStatusIcon()],
      ),
      body: Column(
        children: [
          OfflineIndicator(),  // Show at top
          Expanded(child: RecipeList()),
        ],
      ),
    );
  }
}
```

---

## OfflineStatusIcon (App Bar)

```dart
class OfflineStatusIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, service, child) {
        if (service.isOnline && !service.hasQueuedChanges) {
          return SizedBox.shrink();
        }

        return Stack(
          children: [
            IconButton(
              icon: Icon(
                service.isOnline ? Icons.cloud_upload : Icons.cloud_off,
                color: service.isOnline ? Colors.blue : Colors.orange,
              ),
              onPressed: () {
                showOfflineStatusDialog(context, service);
              },
            ),
            // Badge for queue count
            if (service.hasQueuedChanges)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${service.queuedChangesCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

---

## Sync Button with Progress

```dart
class SyncButton extends StatefulWidget {
  @override
  _SyncButtonState createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> {
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    final offlineService = ServiceLocator.get<OfflineService>();

    // Check if online
    if (!offlineService.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Du är offline. Anslut till internet för att synka.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final result = await offlineService.syncNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            action: !result.success
                ? SnackBarAction(
                    label: 'Försök igen',
                    onPressed: _syncNow,
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, service, child) {
        final hasQueue = service.hasQueuedChanges;
        final isEnabled = service.isOnline && hasQueue && !_isSyncing;

        return ElevatedButton.icon(
          onPressed: isEnabled ? _syncNow : null,
          icon: _isSyncing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Icon(Icons.sync),
          label: Text(
            _isSyncing
                ? 'Synkar...'
                : hasQueue
                    ? 'Synka (${service.queuedChangesCount})'
                    : 'Allt synkat',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? Colors.blue : Colors.grey,
          ),
        );
      },
    );
  }
}
```

---

## Offline Status Dialog

```dart
void showOfflineStatusDialog(BuildContext context, OfflineService service) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Row(
        children: [
          Icon(
            service.isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: service.isOnline ? Colors.green : Colors.orange,
          ),
          SizedBox(width: 8),
          Text(service.isOnline ? 'Online' : 'Offline'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!service.isOnline)
            Text(
              'Du är offline. Ändringar sparas lokalt och synkas när du är online igen.',
            ),
          SizedBox(height: 16),
          Text(
            'Väntande ändringar: ${service.queuedChangesCount}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (service.hasQueuedChanges)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Dessa kommer synkas automatiskt när du är online.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
        if (service.isOnline && service.hasQueuedChanges)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              service.syncNow();
            },
            child: Text('Synka nu'),
          ),
      ],
    ),
  );
}
```

---

## Recipe Offline Status Badge

```dart
class RecipeOfflineBadge extends StatelessWidget {
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    if (!recipe.isModifiedOffline && !recipe.offlineData.isNeverSynced) {
      return SizedBox.shrink();
    }

    final isModified = recipe.isModifiedOffline;
    final icon = isModified ? Icons.cloud_upload : Icons.cloud_queue;
    final color = isModified ? Colors.orange : Colors.blue;
    final text = isModified
        ? 'Ändrat offline'
        : 'Väntar på synk';

    return Tooltip(
      message: text,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Sync Progress Overlay

```dart
class SyncProgressOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, service, child) {
        if (!service.isSyncing) return SizedBox.shrink();

        return Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Synkar recept...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Vänta medan dina ändringar synkas',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Usage in Stack
Stack(
  children: [
    RecipeList(),
    SyncProgressOverlay(),
  ],
)
```

---

## Auto-Sync Notification

```dart
class AutoSyncListener extends StatefulWidget {
  final Widget child;

  @override
  _AutoSyncListenerState createState() => _AutoSyncListenerState();
}

class _AutoSyncListenerState extends State<AutoSyncListener> {
  @override
  void initState() {
    super.initState();

    final offlineService = ServiceLocator.get<OfflineService>();
    offlineService.addListener(_onOfflineServiceChange);
  }

  @override
  void dispose() {
    final offlineService = ServiceLocator.get<OfflineService>();
    offlineService.removeListener(_onOfflineServiceChange);
    super.dispose();
  }

  void _onOfflineServiceChange() {
    final offlineService = ServiceLocator.get<OfflineService>();

    // Show snackbar when auto-sync completes
    if (!offlineService.isSyncing && offlineService.hasQueuedChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Automatisk synk klar'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
```

---

## Connectivity State Indicator

```dart
class ConnectivityIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, service, child) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          height: 3,
          color: service.isOnline ? Colors.green : Colors.red,
        );
      },
    );
  }
}

// Usage at top of screen
Column(
  children: [
    ConnectivityIndicator(),
    Expanded(child: MyContent()),
  ],
)
```

---

## Best Practices

1. **Use Consumer pattern** - Reactive updates when OfflineService changes
2. **Show queue count** - Let users know pending changes
3. **Disable sync when offline** - Prevent frustration
4. **Auto-sync notification** - Inform when background sync completes
5. **Visual feedback** - Colors, icons, animations for all states
6. **Clear messaging** - Swedish localized user-friendly text

---

## Complete Example: Recipe List with Offline Support

```dart
class OfflineRecipeList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mina Recept'),
        actions: [
          OfflineStatusIcon(),
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  content: SyncButton(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectivityIndicator(),
          OfflineIndicator(),
          Expanded(
            child: Stack(
              children: [
                RecipeListView(),
                SyncProgressOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];

        return ListTile(
          title: Text(recipe.title),
          subtitle: Row(
            children: [
              RecipeOfflineBadge(recipe: recipe),
              SizedBox(width: 8),
              SyncAgeDisplay(recipe: recipe),
            ],
          ),
          trailing: recipe.needsSync
              ? Icon(Icons.sync, color: Colors.orange)
              : Icon(Icons.cloud_done, color: Colors.green),
        );
      },
    );
  }
}
```

---

## Related Resources

- [offline-service.md](offline-service.md) - OfflineService API
- [offline-models.md](offline-models.md) - RecipeOfflineData structure
- [sync-mechanisms.md](sync-mechanisms.md) - Sync logic

---

**Components**: OfflineIndicator, OfflineStatusIcon, SyncButton
**Pattern**: Consumer<OfflineService> for reactive updates
**Status**: ✅ Production-ready
