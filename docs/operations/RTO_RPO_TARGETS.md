# Recovery Time & Point Objectives

**Approved By**: [Name]
**Approval Date**: YYYY-MM-DD
**Review Schedule**: Quarterly

## Definitions

- **RTO (Recovery Time Objective)**: Maximum acceptable downtime
- **RPO (Recovery Point Objective)**: Maximum acceptable data loss

## Targets by Service Tier

### Tier 1: Critical Services

| Service | RTO | RPO | Current Capability |
|---------|-----|-----|-------------------|
| User Authentication | 4 hours | 0 (no data) | 24 hours |
| Recipe Read Access | 4 hours | 24 hours | 24 hours |
| Recipe Write Access | 8 hours | 24 hours | 24 hours |

### Tier 2: Important Services

| Service | RTO | RPO | Current Capability |
|---------|-----|-----|-------------------|
| Shopping Lists | 8 hours | 24 hours | Unknown |
| Image Display | 12 hours | 24 hours | Unknown |

### Tier 3: Standard Services

| Service | RTO | RPO | Current Capability |
|---------|-----|-----|-------------------|
| Social Features | 24 hours | 24 hours | Unknown |
| Analytics | 48 hours | 7 days | Unknown |

## Gap Analysis

| Gap | Impact | Remediation |
|-----|--------|-------------|
| Current RTO unknown | Can't measure recovery | Test and document |
| Current RPO = infinity | Complete data loss possible | Daily backups (P1-01) |

## Measurement

### How We Measure RTO

1. Start timer when incident declared
2. Stop timer when service restored
3. Compare against target

### How We Measure RPO

1. Identify last backup timestamp
2. Calculate time since last backup
3. Compare against target
