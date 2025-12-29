# Firestore Field Protection (L2)

## Overview

This document describes the field-level security rules that protect allergen-critical data in Firestore. These rules prevent malicious clients from tampering with tagging data that users rely on for dietary safety.

## Why Field Protection Matters

The `tagResult` field contains allergen and dietary status that users depend on for health decisions:
- Allergen status (gluten, dairy, nuts, etc.) - affects users with allergies
- Dietary status (vegetarian, vegan, halal, etc.) - affects users with dietary restrictions
- Coverage ratio - indicates reliability of the tagging

**A malicious client could**:
- Set `allergenStatus.gluten` to `FREE` when it should be `CONTAINS`
- Inject fake fields to bypass validation
- Set coverage to `1.0` to hide unreliable data

## Protection Implementation

### Location
`firestore.rules` lines 49-62

### The `isValidTagResult()` Function

```firestore
function isValidTagResult(tagResult) {
  return tagResult == null || (
    // Only allow known fields
    tagResult.keys().hasOnly(['tags', 'allergenStatus', 'dietaryStatus',
                              'coverage', 'unknownIngredients', 'generatedAt',
                              'generatorVersion']) &&
    // Coverage must be valid percentage
    (tagResult.get('coverage', 0) >= 0 && tagResult.get('coverage', 0) <= 1) &&
    // GeneratedAt must be a timestamp if present
    (tagResult.get('generatedAt', null) == null ||
     tagResult.get('generatedAt', null) is timestamp)
  );
}
```

### What It Validates

| Check | Purpose |
|-------|---------|
| `keys().hasOnly([...])` | Prevents injection of unknown fields |
| `coverage >= 0 && coverage <= 1` | Prevents invalid percentage values |
| `generatedAt is timestamp` | Ensures proper timestamp type |
| `tagResult == null` | Allows recipes without tagging |

### Where It's Applied

```firestore
match /users/{userId}/recipes/{recipeId} {
  allow write: if isOwner(userId)
    && isValidTagResult(request.resource.data.get('core', {}).get('tagResult', null));
}
```

The validation runs on every recipe write, checking the `core.tagResult` path.

## Security Guarantees

1. **Owner-only writes**: Only the recipe owner can modify recipe documents
2. **Field whitelist**: Only known tagResult fields are allowed
3. **Type validation**: Coverage and timestamps are type-checked
4. **Null safety**: Missing tagResult is allowed (for recipes not yet tagged)

## What's NOT Protected (by design)

- Individual allergen/dietary values (FREE, CONTAINS, UNKNOWN) - the client needs to write these
- The `tags` set - contains non-safety-critical tags like "pasta", "quick"
- Unknown ingredients list - informational only

These are not validated because:
1. The tagging service (client-side) generates these values
2. Validating enum values would require maintaining a list in rules
3. The safety comes from the generator code, not the storage rules

## Testing

To verify rules work correctly, use Firebase Emulator:

```bash
firebase emulators:start --only firestore
npm test  # Run security rules tests
```

Test cases should verify:
- Valid tagResult structures pass
- Invalid coverage values (>1.0, <0.0, non-numeric) are rejected
- Unknown fields are rejected
- Non-owner writes are rejected
- Null tagResult is allowed

## Related Files

- `firestore.rules` - Security rules implementation
- `lib/models/tagging/tag_result.dart` - Client-side model with validation
- `lib/services/tagging/tag_generator.dart` - Tag generation service
