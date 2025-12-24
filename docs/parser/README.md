# Parser Documentation

This folder contains the specification and implementation plan for Butlery's recipe parser.

## Files

| File | Description |
|------|-------------|
| `butlery_parser_spec_v34.md` | Complete specification (5500 lines) |
| `START_PROMPT.md` | Prompt to give Claude Code |
| `IMPLEMENTATION_PLAN.md` | Created by Claude Code |

## The specification contains

### Flutter code (~28 files)
- Config and core classes
- Data models (6 total)
- Repositories
- Services and utilities
- 4 parsing tiers (SchemaOrg, SiteConfig, RuleBased, LLM)
- Swedish ingredient parser
- Cache system

### Backend code (~8 files)
- Cloud Functions (TypeScript)
- Firestore security rules
- Rate limiting and utilities

### Security fixes
- P0-1: Cache key poisoning prevention
- P0-2: LLM injection protection
- P1-3: Circuit breaker for writes
- P1-4: Server-side analytics trust

## Getting started

1. Open Claude Code in the Butlery project
2. Copy the contents of `START_PROMPT.md`
3. Paste as your first prompt
4. Claude Code creates `IMPLEMENTATION_PLAN.md` and waits for your OK

## Note on language

The specification contains Swedish comments and some Swedish variable names (e.g., `swedishTextQuantities`, `preparationWords`). The START_PROMPT instructs Claude Code to write all new code and documentation in English, translating Swedish comments as needed.
