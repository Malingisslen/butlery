# Natural Language Skill Activation Patterns

**Date**: February 1, 2025
**Purpose**: Comprehensive guide to natural language patterns for skill activation
**Audience**: Non-technical users and developers

---

## Overview

The skill activation system now understands **natural, everyday language** in addition to technical terminology. You can describe features the way you would explain them to a friend, and the system will activate the correct architectural patterns.

**Before Enhancement**:
```
You: "add feature to track cooking history"
→ No skills activated (missing keywords like "repository", "service")
```

**After Enhancement**:
```
You: "I want users to see what they cooked last week"
→ Activates: butlery-architecture, firebase-repository-patterns
→ Claude uses proper MVVM + Repository patterns automatically
```

---

## How It Works

### Three Types of Triggers

1. **Keywords** - Single words that activate skills
   - Example: "save", "offline", "test", "faster"

2. **Intent Patterns** - Natural phrases (regex)
   - Example: "I want users to...", "make it...", "let them..."

3. **File Triggers** - Automatic activation when editing relevant files
   - Example: Editing `lib/repositories/cooking_repository.dart` → activates firebase-repository-patterns

---

## Natural Language Pattern Guide

### 🏗️ Architecture & Features (butlery-architecture)

**Use when**: Asking for any new feature or functionality

#### User-Focused Phrases
```
✓ "I want users to be able to..."
✓ "Let users..."
✓ "Allow users to..."
✓ "Users should be able to..."
✓ "Users need to..."
✓ "Give users the ability to..."
✓ "Make it so users can..."
✓ "Enable users to..."
```

**Examples**:
- "I want users to save their favorite recipes"
- "Let users share their shopping lists"
- "Users should be able to see their cooking history"

#### Feature Addition Phrases
```
✓ "Add a feature to..."
✓ "Implement a feature that..."
✓ "Build functionality to..."
✓ "Create the ability to..."
✓ "Add the capability to..."
```

**Examples**:
- "Add a feature to track what they cook"
- "Implement a feature that remembers their preferences"
- "Build functionality to organize recipes by category"

#### Data Operation Phrases
```
✓ "Save data about..."
✓ "Store information about..."
✓ "Keep track of..."
✓ "Remember when..."
✓ "Record information about..."
```

**Examples**:
- "Save data about user cooking sessions"
- "Keep track of their favorite ingredients"
- "Remember when they last cooked each recipe"

---

### 💾 Data & Firebase (firebase-repository-patterns)

**Use when**: Talking about saving, loading, or managing data

#### Saving Data
```
✓ "Save to the database"
✓ "Store in Firebase"
✓ "Save permanently"
✓ "Keep the data"
✓ "Remember this data"
✓ "Save user data"
✓ "Persist this information"
```

**Examples**:
- "Save their cooking history to the database"
- "Store user preferences in Firebase"
- "Keep this data even after they close the app"

#### Loading Data
```
✓ "Get from the database"
✓ "Fetch from Firebase"
✓ "Load saved data"
✓ "Retrieve the data"
✓ "Show what was saved"
✓ "Display saved information"
✓ "See what they saved"
```

**Examples**:
- "Get their saved recipes from the database"
- "Load all the shopping lists they created"
- "Show what they cooked last week"

#### Modifying Data
```
✓ "Update the saved data"
✓ "Change saved information"
✓ "Edit what was saved"
✓ "Modify the data"
✓ "Delete the data"
✓ "Remove saved information"
```

**Examples**:
- "Update their profile information"
- "Change the recipe they saved yesterday"
- "Delete old cooking history"

---

### 🎨 User Interface (flutter-widget-guidelines)

**Use when**: Describing screens, buttons, lists, or visual elements

#### Screen/Page Creation
```
✓ "Show a screen for..."
✓ "Create a screen that..."
✓ "Display a page where..."
✓ "Add a screen to..."
✓ "Build a view for..."
✓ "Make a screen that shows..."
```

**Examples**:
- "Show a screen with all their recipes"
- "Create a page where they can edit their profile"
- "Add a screen to view cooking statistics"

#### UI Elements
```
✓ "Add a button to..."
✓ "Show a list of..."
✓ "Display a list of..."
✓ "Create a form for..."
✓ "Show a dialog when..."
✓ "Add an input field for..."
```

**Examples**:
- "Add a button to save the recipe"
- "Show a list of all ingredients"
- "Display a form where they can add recipes"

#### Visual Design
```
✓ "Make it look better"
✓ "Change the appearance"
✓ "Style the..."
✓ "Design the..."
✓ "Improve the look"
✓ "Make it more attractive"
```

**Examples**:
- "Make the recipe cards look better"
- "Change the color scheme"
- "Improve the design of the shopping list"

---

### ⚡ Performance (performance-optimization)

**Use when**: Complaining about speed or lag

#### Speed Requests
```
✓ "Make it faster"
✓ "Speed it up"
✓ "Make it load faster"
✓ "Reduce loading time"
✓ "Improve the speed"
```

**Examples**:
- "Make the app faster"
- "Speed up the recipe loading"
- "The list loads too slowly"

#### Performance Issues
```
✓ "It's too slow"
✓ "Taking too long"
✓ "It lags"
✓ "It stutters"
✓ "It freezes"
✓ "Not smooth"
✓ "Choppy"
✓ "Jerky"
```

**Examples**:
- "The recipe list is too slow"
- "The app freezes when I scroll"
- "The animations are not smooth"

---

### 📴 Offline Support (offline-first-patterns)

**Use when**: Talking about internet connectivity or offline functionality

#### Offline Work
```
✓ "Work without internet"
✓ "Work offline"
✓ "Use without connection"
✓ "When there's no internet"
✓ "In airplane mode"
✓ "No network connection"
```

**Examples**:
- "Let users work offline"
- "Make it work without internet"
- "They should be able to add recipes in airplane mode"

#### Local Storage
```
✓ "Save locally"
✓ "Store on the device"
✓ "Keep on their phone"
✓ "Save on the device"
✓ "Local copy"
```

**Examples**:
- "Save recipes locally so they can access them offline"
- "Keep a copy on their phone"
- "Store shopping lists on the device"

#### Syncing
```
✓ "Sync when online"
✓ "Upload when connected"
✓ "Sync later"
✓ "Send when they have internet"
✓ "Sync automatically"
```

**Examples**:
- "Sync their changes when they get internet back"
- "Upload new recipes when connected"
- "Automatically sync when online"

---

### 🔒 Privacy & GDPR (gdpr-compliance)

**Use when**: Discussing user data control, privacy, or account deletion

#### Account Deletion
```
✓ "Let users delete their account"
✓ "Allow them to delete everything"
✓ "Users can remove their data"
✓ "Delete all user data"
✓ "Erase their information"
✓ "Get rid of their data"
```

**Examples**:
- "Let users delete their account and all data"
- "Allow them to completely remove their information"
- "They should be able to erase everything"

#### Data Export
```
✓ "Let users download their data"
✓ "Export their information"
✓ "Download a copy of their data"
✓ "Get all their information"
✓ "Retrieve their data"
```

**Examples**:
- "Let users download all their recipes"
- "They should be able to export their cooking history"
- "Allow them to get a copy of all their data"

#### Privacy Control
```
✓ "User privacy"
✓ "Protect their privacy"
✓ "Control their data"
✓ "Manage their information"
✓ "Users own their data"
```

**Examples**:
- "Protect user privacy"
- "Let them control what data is shared"
- "Ensure they own their data"

---

### 🔄 Real-time Collaboration (realtime-collaboration)

**Use when**: Discussing instant updates or multiple users working together

#### Immediate Updates
```
✓ "Update immediately"
✓ "Show changes right away"
✓ "Instant updates"
✓ "Automatic updates"
✓ "Live updates"
✓ "Show changes immediately"
✓ "Sync in real-time"
```

**Examples**:
- "Show recipe changes immediately"
- "Update the shopping list in real-time"
- "Display changes as they happen"

#### Collaboration
```
✓ "Work together on..."
✓ "Edit together"
✓ "Multiple users editing"
✓ "Collaborate on..."
✓ "Multiple people working on..."
✓ "See what others are doing"
✓ "Show who is editing"
```

**Examples**:
- "Let multiple people edit the same shopping list"
- "Users can work together on meal planning"
- "Show who else is viewing the recipe"

---

### 🧪 Testing & Verification (testing-patterns)

**Use when**: Asking about quality, correctness, or verification

#### Verification Requests
```
✓ "Make sure it works"
✓ "Verify that..."
✓ "Check if..."
✓ "Ensure it..."
✓ "Test if..."
✓ "Does it work?"
✓ "Is it working?"
✓ "Validate that..."
```

**Examples**:
- "Make sure the save function works"
- "Verify that recipes can be deleted"
- "Check if offline mode is working"

---

### 🧭 Navigation (navigation-routing)

**Use when**: Describing user flow between screens

#### Navigation Actions
```
✓ "Go to the... screen"
✓ "Open the... page"
✓ "Show the... screen"
✓ "Take users to..."
✓ "Redirect to..."
✓ "Navigate to..."
✓ "Switch to the... screen"
```

**Examples**:
- "Go to the recipe details screen"
- "Take users to their profile"
- "Show the shopping list screen"

#### User Actions
```
✓ "When users tap..."
✓ "When they click..."
✓ "After they..."
✓ "When users press..."
✓ "On button tap..."
```

**Examples**:
- "When users tap the recipe, show the details"
- "After they save, go back to the list"
- "When they click edit, open the form"

---

### 🔋 Loading & State Management (state-management-patterns)

**Use when**: Discussing loading indicators or error states

#### Loading States
```
✓ "Show loading..."
✓ "Display loading..."
✓ "Show a spinner"
✓ "Show progress"
✓ "While it loads..."
✓ "Waiting for data"
✓ "Loading indicator"
```

**Examples**:
- "Show a spinner while recipes are loading"
- "Display a progress bar during sync"
- "Show loading text while fetching data"

#### Error Handling
```
✓ "Show an error when..."
✓ "Display error message"
✓ "Handle errors"
✓ "When it fails..."
✓ "If something goes wrong..."
✓ "Error message"
```

**Examples**:
- "Show an error if the recipe can't be saved"
- "Display a message when the connection fails"
- "Handle errors gracefully"

---

## Pattern Matching Examples

### Example 1: Complete Feature Request

**Your Request**:
> "I want users to be able to save their favorite recipes and see them later, even without internet"

**Skills Activated**:
1. ✅ **butlery-architecture** (matched: "I want users to")
2. ✅ **firebase-repository-patterns** (matched: "save")
3. ✅ **offline-first-patterns** (matched: "without internet")

**Why It Works**: Three different natural language patterns matched three different skills, giving Claude complete context for implementing this feature properly.

---

### Example 2: Performance Complaint

**Your Request**:
> "The recipe list is too slow and it lags when I scroll"

**Skills Activated**:
1. ✅ **performance-optimization** (matched: "too slow", "lags")
2. ✅ **flutter-widget-guidelines** (matched: "scroll")

**Why It Works**: Performance keywords triggered optimization patterns, while UI keywords ensured widget best practices.

---

### Example 3: Data Privacy

**Your Request**:
> "Let users delete their account and download all their data first"

**Skills Activated**:
1. ✅ **gdpr-compliance** (matched: "delete their account", "download all their data")
2. ✅ **butlery-architecture** (matched: "let users")

**Why It Works**: GDPR patterns matched privacy-related language, architecture patterns ensured proper service structure.

---

### Example 4: Collaborative Feature

**Your Request**:
> "Multiple people should be able to edit the same shopping list and see changes immediately"

**Skills Activated**:
1. ✅ **realtime-collaboration** (matched: "multiple people", "see changes immediately")
2. ✅ **butlery-architecture** (matched: "should be able")
3. ✅ **firebase-repository-patterns** (matched: file triggers)

**Why It Works**: Collaboration and real-time patterns matched, ensuring proper conflict resolution and presence tracking patterns.

---

## Quick Reference: Common Phrases

### I Want To Add Features
| **Say This** | **Skills Activated** |
|-------------|---------------------|
| "I want users to save recipes" | architecture, firebase-repository |
| "Let them share with friends" | architecture, realtime-collaboration |
| "Add a screen to view history" | architecture, flutter-widget |
| "Make it work offline" | offline-first, architecture |
| "Let users delete their account" | gdpr-compliance, architecture |

### I Have Problems
| **Say This** | **Skills Activated** |
|-------------|---------------------|
| "It's too slow" | performance-optimization |
| "It crashes when..." | testing-patterns, state-management |
| "The UI looks bad" | flutter-widget-guidelines |
| "Data isn't saving" | firebase-repository, state-management |
| "It doesn't work offline" | offline-first-patterns |

### I Need To...
| **Say This** | **Skills Activated** |
|-------------|---------------------|
| "...save user data" | firebase-repository, architecture |
| "...show a loading spinner" | state-management, flutter-widget |
| "...make it faster" | performance-optimization |
| "...let multiple users edit" | realtime-collaboration |
| "...export user data" | gdpr-compliance |

---

## Advanced: Pattern Precedence

When multiple patterns match, skills are ordered by **priority**:

1. **🔴 CRITICAL** (shown first)
   - butlery-architecture
   - firebase-repository-patterns
   - testing-patterns

2. **🟡 HIGH** (shown second)
   - flutter-widget-guidelines
   - state-management-patterns
   - code-deduplication-utilities
   - dependency-injection-patterns

3. **🟢 MEDIUM** (shown last)
   - gdpr-compliance
   - realtime-collaboration
   - offline-first-patterns
   - performance-optimization
   - navigation-routing

**Why This Matters**: Critical skills contain foundational patterns (MVVM, repositories, testing) that should always be considered first.

---

## Technical Details

### Pattern Types

#### 1. Simple Keywords
```json
"keywords": ["save", "offline", "test", "faster"]
```
- Case-insensitive
- Exact word match
- Fast to process

#### 2. Regex Intent Patterns
```json
"intentPatterns": [
  "i.*want.*users.*to",
  "make.*it.*faster",
  "let.*users"
]
```
- More flexible
- Matches phrases
- Captures natural language

#### 3. File Path Patterns
```json
"fileTriggers": {
  "pathPatterns": [
    "lib/repositories/**/*.dart",
    "lib/viewmodels/**/*.dart"
  ]
}
```
- Automatic activation when editing files
- Glob pattern matching
- Context-aware

---

## Statistics

### Pattern Coverage

| Skill | Keywords | Intent Patterns | Total Triggers |
|-------|----------|----------------|----------------|
| butlery-architecture | 13 | 25 | 38 |
| firebase-repository-patterns | 12 | 18 | 30 |
| flutter-widget-guidelines | 14 | 15 | 29 |
| performance-optimization | 10 | 12 | 22 |
| offline-first-patterns | 7 | 10 | 17 |
| gdpr-compliance | 9 | 12 | 21 |
| realtime-collaboration | 6 | 10 | 16 |
| state-management-patterns | 7 | 8 | 15 |
| navigation-routing | 6 | 10 | 16 |
| testing-patterns | 9 | 5 | 14 |
| dependency-injection-patterns | 6 | 5 | 11 |
| code-deduplication-utilities | 7 | 7 | 14 |

**Total Natural Language Triggers**: ~240 patterns across all 12 skills

---

## Tips for Best Results

### ✅ DO Use Natural Language

- ✅ "I want users to save recipes"
- ✅ "Make the app faster"
- ✅ "Let them work offline"
- ✅ "Show a loading spinner"

### ❌ DON'T Worry About Technical Terms

- ❌ You don't need to say "repository"
- ❌ You don't need to say "ViewModel"
- ❌ You don't need to say "Firebase Firestore"
- ❌ You don't need to say "AsyncOperationMixin"

**Just describe what you want in plain English!**

### 💡 Be Specific About User Actions

Instead of: "Add a feature"
Say: "Let users save their favorite recipes"

Instead of: "Make it better"
Say: "Make the recipe list load faster"

Instead of: "Add offline"
Say: "Let users view recipes without internet"

---

## Maintenance

### Adding New Patterns

If you discover phrases that should trigger skills but don't, they can be added to `.claude/skill-rules.json`:

```json
{
  "skill-name": {
    "promptTriggers": {
      "keywords": ["new", "keywords"],
      "intentPatterns": ["new.*pattern"]
    }
  }
}
```

### Testing Patterns

Test if your phrase activates skills:

```bash
echo "your natural language request" | .claude/hooks/skill-activation-prompt.sh
```

---

## Conclusion

You can now request features in **natural, everyday language** without knowing any technical terminology. The skill activation system understands:

- How non-technical users describe features
- Common complaints and issues
- User-focused language ("I want users to...", "Let them...")
- Action-oriented phrases ("save", "show", "make it...")

**Just describe what you want, and the right architectural patterns will be applied automatically!**

---

**Created**: 2025-02-01
**Pattern Count**: ~240 natural language triggers
**Skills Covered**: All 12 Butlery architecture skills
**Maintained By**: Butlery Development Team
