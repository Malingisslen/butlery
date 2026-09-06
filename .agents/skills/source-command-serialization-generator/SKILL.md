---
name: "source-command-serialization-generator"
description: "Generates fromFirestore/toFirestore methods using SerializationUtils. Use when creating or modifying Firestore model serialization, adding fields to models, or fixing direct data['field'] access."
---

# source-command-serialization-generator

Use this skill when the user asks to run the migrated source command `serialization-generator`.

## Command Template

# Serialization Generator

> Generate fromFirestore/toFirestore using SerializationUtils.

## fromFirestore Pattern

```dart
factory {Model}.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return {Model}(
    id: doc.id,
    // Strings
    title: SerializationUtils.safeString(data, 'title'),
    description: SerializationUtils.safeNullableString(data, 'description'),

    // Numbers
    count: SerializationUtils.safeInt(data, 'count', defaultValue: 0),
    price: SerializationUtils.safeDouble(data, 'price', defaultValue: 0.0),

    // Booleans
    isActive: SerializationUtils.safeBool(data, 'isActive', defaultValue: false),

    // DateTime
    createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
    updatedAt: SerializationUtils.safeNullableDateTime(data, 'updatedAt'),

    // Lists
    tags: SerializationUtils.safeStringList(data, 'tags'),
    items: SerializationUtils.safeList<Map<String, dynamic>>(data, 'items')
        .map((e) => Item.fromMap(e))
        .toList(),

    // Nested objects
    author: data['author'] != null
        ? Author.fromMap(data['author'] as Map<String, dynamic>)
        : null,
  );
}
```

## toFirestore Pattern

```dart
Map<String, dynamic> toFirestore() {
  return {
    'title': title,
    'description': description,
    'count': count,
    'price': price,
    'isActive': isActive,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    'tags': tags,
    'items': items.map((e) => e.toMap()).toList(),
    'author': author?.toMap(),
  };
}
```

## SerializationUtils Metoder

| Metod | Returnerar | Default |
|-------|------------|---------|
| `safeString(data, key)` | `String` | `''` |
| `safeNullableString(data, key)` | `String?` | `null` |
| `safeInt(data, key, defaultValue:)` | `int` | `0` |
| `safeDouble(data, key, defaultValue:)` | `double` | `0.0` |
| `safeBool(data, key, defaultValue:)` | `bool` | `false` |
| `safeRequiredDateTime(data, key)` | `DateTime` | `DateTime.now()` |
| `safeNullableDateTime(data, key)` | `DateTime?` | `null` |
| `safeStringList(data, key)` | `List<String>` | `[]` |
| `safeList<T>(data, key)` | `List<T>` | `[]` |
| `safeMap(data, key)` | `Map<String, dynamic>` | `{}` |

## Kritiska Regler

❌ **Direkt access**
```dart
title: data['title'], // Kan krascha på null
```

✅ **SerializationUtils**
```dart
title: SerializationUtils.safeString(data, 'title'),
```

---

❌ **Timestamp utan konvertering**
```dart
createdAt: data['createdAt'], // Firestore Timestamp, inte DateTime
```

✅ **DateTime-parsing**
```dart
createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
```

## Import

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
```

## Nyckelfilar

- `lib/core/utils/serialization_utils.dart`
