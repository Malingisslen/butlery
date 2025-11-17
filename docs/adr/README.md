# Architectural Decision Records (ADRs)

**Last Updated**: 2025-11-17
**Total ADRs**: 5
**Status**: All Accepted

---

## What are ADRs?

Architectural Decision Records (ADRs) document the **key architectural decisions** made throughout the project, including:

- **Context**: What problem were we solving?
- **Decision**: What did we choose to do?
- **Alternatives**: What other options did we consider?
- **Consequences**: What are the trade-offs?

ADRs provide **historical context** for future developers, explaining **why** architectural choices were made.

---

## Index of ADRs

| ADR | Title | Status | Date | Summary |
|-----|-------|--------|------|---------|
| [ADR-001](ADR-001-mvvm-repository-pattern.md) | Use MVVM + Repository Pattern | ✅ Accepted | 2024-Q3 | Clean 4-layer architecture: Views → ViewModels → Services → Repositories → Firebase |
| [ADR-002](ADR-002-getit-dependency-injection.md) | Use GetIt for Dependency Injection | ✅ Accepted | 2024-Q3 | Service locator pattern with lazy singletons for 240+ registrations |
| [ADR-003](ADR-003-firebase-backend-platform.md) | Use Firebase as Backend Platform | ✅ Accepted | 2024-Q2 | Comprehensive Firebase backend (Firestore, Auth, Storage, FCM, Analytics) |
| [ADR-004](ADR-004-seven-domain-modules.md) | Organize DI into 7 Domain Modules | ✅ Accepted | 2024-Q3 | Modular DI organization: Core, Content, Social, Messaging, Collaboration, Performance, UI |
| [ADR-005](ADR-005-500-line-file-limit.md) | Enforce 500-Line File Size Limit | ✅ Accepted | 2024-Q4 | Target 500 lines per file, use facade pattern for complex features (SRP enforcement) |

---

## Quick Reference

### Core Architecture Decisions

**[ADR-001: MVVM + Repository Pattern](ADR-001-mvvm-repository-pattern.md)**
- **Why**: Clean separation of concerns, testability, scalability
- **Key Benefit**: 66.5% test coverage, 87% health score
- **Trade-off**: More files (240+ logic files), learning curve

**[ADR-002: GetIt for DI](ADR-002-getit-dependency-injection.md)**
- **Why**: Type-safe service locator for 240+ services
- **Key Benefit**: Simple API, no code generation, excellent testability
- **Trade-off**: Manual registration, service locator anti-pattern

**[ADR-003: Firebase Backend](ADR-003-firebase-backend-platform.md)**
- **Why**: Scalable backend without infrastructure management
- **Key Benefit**: Fast development, real-time, offline support, GDPR compliant
- **Trade-off**: Vendor lock-in, cost at scale, NoSQL limitations

### Organizational Decisions

**[ADR-004: 7 Domain Modules](ADR-004-seven-domain-modules.md)**
- **Why**: Organize 240+ DI registrations, prevent circular dependencies
- **Key Benefit**: Clear organization, lazy loading, maintainability
- **Trade-off**: 7 files vs 1, module dependency complexity

**[ADR-005: 500-Line Limit](ADR-005-500-line-file-limit.md)**
- **Why**: Enforce Single Responsibility Principle, prevent "god classes"
- **Key Benefit**: Maintainability, faster reviews, easier testing
- **Trade-off**: More files, facade pattern overhead

---

## How to Read ADRs

**1. Start with Core Decisions**:
- [ADR-001 (MVVM)](ADR-001-mvvm-repository-pattern.md) - Foundation architecture
- [ADR-003 (Firebase)](ADR-003-firebase-backend-platform.md) - Backend platform

**2. Understand Dependency Management**:
- [ADR-002 (GetIt)](ADR-002-getit-dependency-injection.md) - How services are wired
- [ADR-004 (7 Modules)](ADR-004-seven-domain-modules.md) - How DI is organized

**3. Learn Code Quality Standards**:
- [ADR-005 (500-Line Limit)](ADR-005-500-line-file-limit.md) - File size enforcement

---

## ADR Numbering Convention

- **ADR-001 to ADR-010**: Core architecture decisions (MVVM, DI, Backend)
- **ADR-011 to ADR-020**: Feature architecture (Social, Messaging, Collaboration)
- **ADR-021 to ADR-030**: Infrastructure and DevOps
- **ADR-031+**: Future decisions

---

## Creating New ADRs

When making a new architectural decision:

### 1. Create ADR File

```markdown
# ADR-XXX: [Decision Title]

**Status**: Proposed | Accepted | Deprecated | Superseded
**Date**: YYYY-MM-DD
**Deciders**: [Who made the decision]

## Context
[What is the issue we're addressing?]

## Decision
[What is the change we're making?]

## Alternatives Considered
1. **[Alternative 1]**: [Why not chosen]
2. **[Alternative 2]**: [Why not chosen]

## Consequences

**Positive**:
- [Benefit 1]

**Negative**:
- [Trade-off 1]

## References
- [Related documentation]
```

### 2. Update This README

Add entry to ADR Index table above.

### 3. Link from Related ADRs

Cross-reference in "Related ADRs" section of affected ADRs.

---

## ADR Status Definitions

- **Proposed**: Decision under consideration, not yet implemented
- **Accepted**: Decision approved and implemented
- **Deprecated**: Decision no longer recommended, but still in use
- **Superseded**: Decision replaced by newer ADR (link to replacement)

---

## Related Documentation

### Architecture Guides
- [Architecture Overview](../architecture/ARCHITECTURE_OVERVIEW.md) - Complete architectural reference
- [MVVM Pattern Guide](../architecture/MVVM_PATTERN.md) - Implementation details for ADR-001
- [DI System Guide](../architecture/DI_SYSTEM.md) - Implementation details for ADR-002 & ADR-004
- [Firebase Integration Guide](../architecture/FIREBASE_INTEGRATION.md) - Implementation details for ADR-003
- [Best Practices](../architecture/BEST_PRACTICES.md) - Coding standards and patterns

### Project Guidelines
- [CLAUDE.md](../../CLAUDE.md) - Project configuration and standards (references ADRs)
- [MASTERPLAN.md](../ultimate/MASTERPLAN.md) - Issue tracking and remediation plan

---

## Why ADRs Matter

**For Current Developers**:
- Understand **why** decisions were made (not just **what**)
- Learn architectural patterns and trade-offs
- Make consistent future decisions

**For New Developers**:
- Quick onboarding to architectural choices
- Historical context for codebase structure
- Understand alternatives that were considered

**For Future Refactoring**:
- Know what trade-offs were accepted
- Understand when to revisit decisions
- Have migration paths documented

---

## External Resources

- **ADR Templates**: [Joel Parker Henderson's ADR Repository](https://github.com/joelparkerhenderson/architecture-decision-record)
- **ADR Best Practices**: [Thoughtworks Technology Radar](https://www.thoughtworks.com/radar/techniques/lightweight-architecture-decision-records)
- **Martin Fowler on ADRs**: [Architecture Decision Records](https://adr.github.io/)

---

**Maintained by**: Butlery Core Development Team
**Questions?**: See [CLAUDE.md](../../CLAUDE.md) for project maintainers
