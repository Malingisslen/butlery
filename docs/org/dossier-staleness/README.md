# Dossier staleness markers

Each `<role-slug>.stale` file here means a role's dossier in
`docs/architecture/ROLE_RESPONSIBILITY_MAP.md` may be out of date because a file
it owns was edited since the dossier was last audited.

- **Written by** `.claude/hooks/dossier-freshness-stamp.sh` (PostToolUse Write|Edit),
  which matches the edited file against `docs/org/role-paths.json` (generated from
  the map by `tools/gen_role_paths.py`).
- **Cleared by** the `/refresh-dossiers` skill, which re-audits only the stale
  roles, updates their dossier sections, and deletes the markers.

Marker format (JSON):

```json
{
  "role": "Security Architect",
  "stale_since": "2026-06-26",
  "last_stamped": "2026-06-26",
  "triggers": ["lib/services/security/cert_pin_config.dart"]
}
```

Markers are committed so staleness survives across sessions and machines. An
empty directory (only this README) means every dossier is considered fresh.
