# [Feature Name] - Context

**Created**: YYYY-MM-DD
**Last Updated**: YYYY-MM-DD
**Current Phase**: Planning | Foundation | Business Logic | UI | Testing | Polish
**Last Session End**: YYYY-MM-DD HH:MM

> **Purpose**: This file captures "where we are" in implementation to prevent context loss when sessions reset.

---

## Current Status Summary

### What's Complete ✅
- [x] Task 1 description
- [x] Task 2 description
- [x] Task 3 description

### What's In Progress 🔄
- [ ] Task currently being worked on
  - Sub-task 1 ✅
  - Sub-task 2 🔄 (currently here)
  - Sub-task 3 ⏳

### What's Pending ⏳
- [ ] Upcoming task 1
- [ ] Upcoming task 2
- [ ] Upcoming task 3

---

## Recent Changes (Last Session)

### Files Modified
**Date**: YYYY-MM-DD

**Created**:
- `path/to/new/file1.dart` - Brief description
- `path/to/new/file2.dart` - Brief description

**Modified**:
- `path/to/modified/file1.dart` - What changed and why
- `path/to/modified/file2.dart` - What changed and why

**Deleted**:
- `path/to/deleted/file.dart` - Why it was removed

### Key Decisions Made
1. **Decision**: [describe decision]
   - **Rationale**: [why this approach]
   - **Alternative Considered**: [what was rejected and why]

2. **Decision**: [describe decision]
   - **Rationale**: [why this approach]
   - **Alternative Considered**: [what was rejected and why]

### Code Patterns Applied
- **Pattern**: [e.g., BaseFirebaseRepository]
  - **Where**: `lib/repositories/feature_repository.dart`
  - **Why**: Standard CRUD operations with permission validation

- **Pattern**: [e.g., AsyncOperationMixin]
  - **Where**: `lib/viewmodels/feature_viewmodel.dart`
  - **Why**: Automatic loading/error state management

---

## Current Implementation State

### Repository Layer ✅ | 🔄 | ⏳
**Status**: [Complete | In Progress | Not Started]

**Files**:
- `lib/repositories/feature_repository.dart` - [status]

**What's Done**:
- [x] Extends BaseFirebaseRepository
- [x] CRUD operations implemented
- [x] Permission validation added
- [x] Tests written (test/unit/repositories/feature_repository_test.dart)

**What's Remaining**:
- [ ] Additional query methods
- [ ] Batch operations

### Service Layer ✅ | 🔄 | ⏳
**Status**: [Complete | In Progress | Not Started]

**Files**:
- `lib/services/feature_service.dart` - [status]

**What's Done**:
- [x] Extends BaseService
- [x] Core business logic methods
- [x] Error handling with ErrorHandlingMixin

**What's Remaining**:
- [ ] Additional business logic
- [ ] Service tests

### ViewModel Layer ✅ | 🔄 | ⏳
**Status**: [Complete | In Progress | Not Started]

**Files**:
- `lib/viewmodels/feature_viewmodel.dart` - [status]

**What's Done**:
- [x] AsyncOperationMixin integration
- [x] State properties defined
- [x] DI registration in UI module

**What's Remaining**:
- [ ] Additional operations
- [ ] ViewModel tests

### UI Layer ✅ | 🔄 | ⏳
**Status**: [Complete | In Progress | Not Started]

**Files**:
- `lib/views/feature_view.dart` - [status]
- `lib/widgets/feature_widget.dart` - [status]

**What's Done**:
- [x] Main view scaffold
- [x] Navigation integration

**What's Remaining**:
- [ ] Reusable widgets
- [ ] Loading/error states
- [ ] UI polish

### Tests ✅ | 🔄 | ⏳
**Status**: [Complete | In Progress | Not Started]

**Coverage**:
- Repository tests: [percentage]
- Service tests: [percentage]
- ViewModel tests: [percentage]
- Integration tests: [status]

---

## Current Working Context

### What I Was Just Doing
[Detailed description of the exact task you were working on when the session ended]

**Specific Code Location**:
- File: `path/to/file.dart`
- Line: ~XXX
- Function/Method: `methodName()`

**What I Was Trying to Accomplish**:
[Detailed explanation of the goal]

**Approach Being Taken**:
[Step-by-step description of the approach]

**Where I Left Off**:
[Exact stopping point - what line of code, what step in the process]

### Next Immediate Steps
1. **First**: [very specific next action]
   - File to open: `path/to/file.dart`
   - What to do: [specific action]

2. **Then**: [second action]
   - File: `path/to/file.dart`
   - Action: [specific action]

3. **After That**: [third action]
   - File: `path/to/file.dart`
   - Action: [specific action]

---

## Open Questions & Blockers

### Questions Needing Answers
1. **Question**: [describe question]
   - **Impact**: High | Medium | Low
   - **Blocking**: Yes | No
   - **Notes**: [additional context]

2. **Question**: [describe question]
   - **Impact**: High | Medium | Low
   - **Blocking**: Yes | No
   - **Notes**: [additional context]

### Known Blockers
1. **Blocker**: [describe blocker]
   - **Type**: Technical | Design | External
   - **Impact**: [how it affects progress]
   - **Workaround**: [temporary solution if any]
   - **Resolution Path**: [how to unblock]

### Technical Debt Introduced
1. **Debt**: [describe technical debt]
   - **Location**: `path/to/file.dart:line`
   - **Why**: [reason for compromise]
   - **TODO**: [how to fix properly later]

---

## Testing Notes

### Manual Testing Done
**Scenarios Tested**:
- [x] Scenario 1: [result]
- [x] Scenario 2: [result]
- [ ] Scenario 3: [not tested yet]

**Bugs Found**:
1. **Bug**: [description]
   - **Severity**: High | Medium | Low
   - **Status**: Open | Fixed | Deferred
   - **Fix**: [solution if fixed]

### Automated Testing Status
**Unit Tests**:
- Total: XX tests
- Passing: XX
- Failing: XX (if any, list them)

**Integration Tests**:
- Total: XX tests
- Passing: XX
- Failing: XX (if any, list them)

---

## Dependencies & Integration Points

### Services Used
- `ServiceName` - Used for [purpose]
  - Methods called: `method1()`, `method2()`
  - Status: ✅ Working | 🔄 Integration in progress | ⚠️ Issues

### Repositories Used
- `RepositoryName` - Used for [purpose]
  - Methods called: `method1()`, `method2()`
  - Status: ✅ Working | 🔄 Integration in progress | ⚠️ Issues

### External Dependencies
- **Package**: `package_name`
  - **Purpose**: [what it's used for]
  - **Version**: X.Y.Z
  - **Issues**: [any known issues]

### Other Features This Depends On
- **Feature Name**
  - **What We Need**: [specific requirement]
  - **Status**: ✅ Available | 🔄 In development | ⚠️ Blocked

---

## Performance & Security Notes

### Performance Considerations
- **Cache Strategy**: [what's being cached and why]
- **Offline Support**: [offline behavior implemented]
- **Known Performance Issues**: [any performance concerns]

### Security Considerations
- **Permission Checks**: [where and how permissions are validated]
- **Audit Logging**: [what's being logged for GDPR Article 30]
- **Data Sensitivity**: [any PII or sensitive data handling]
- **Encryption**: [any encryption requirements]

---

## UI/UX Notes

### Design Decisions
- **Color Scheme**: [any custom colors used]
- **Spacing**: [notable spacing decisions]
- **Animations**: [any animations implemented]

### Accessibility
- [ ] Screen reader support
- [ ] Keyboard navigation
- [ ] Color contrast (WCAG AA)
- [ ] Font scaling

### Localization
- **Language**: Swedish primary, English fallback
- **Strings Needing Translation**: [list any hardcoded strings to localize]

---

## Firebase Structure (Current State)

### Collections Created
```
collection_name/
├─ {documentId}/
│  ├─ field1: "value" (type)
│  ├─ field2: 123 (type)
│  └─ nested_collection/
│     └─ {nestedDocId}/
│        └─ field: "value"
```

### Security Rules Status
- [ ] Rules written for this feature
- [ ] Rules tested
- [ ] Rules deployed

### Indexes Created
- Index 1: `collection.field1_asc_field2_desc`
- Index 2: `collection.field3_asc`

---

## Links & References

### Related Code
- Similar implementation: `path/to/similar/file.dart`
- Pattern reference: [link to skill or doc]

### Documentation
- API docs: [link]
- Design doc: [link]
- User story: [link]

### Related Issues
- GitHub issue: #XXX
- Slack discussion: [link]
- Design review: [link]

---

## Session Handoff Checklist

Before ending session, update:
- [ ] "What's Complete" section with latest completions
- [ ] "Current Working Context" with exact stopping point
- [ ] "Next Immediate Steps" with clear actions
- [ ] "Recent Changes" with all file modifications
- [ ] "Open Questions" with any new uncertainties
- [ ] Date stamp at top of file

**Quick Resume Instructions for Next Session**:
[One paragraph summary of how to quickly get back into context - what to read first, what to do first]

---

**Notes**: [Any additional context that helps resume work efficiently]
