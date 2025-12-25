# Data Breach Response Procedure

**Document Version**: 1.0
**Last Updated**: YYYY-MM-DD
**GDPR Compliance**: Articles 33-34

## 1. Breach Detection Criteria

A data breach is confirmed when ANY of the following occur:

- Unauthorized access to user data
- Accidental data exposure (public bucket, leaked credentials)
- Data theft or exfiltration
- Ransomware affecting user data
- Unauthorized modification of user data
- Loss of data availability

## 2. Immediate Response (First Hour)

### Step 1: Containment (0-15 minutes)

- [ ] Identify breach scope and type
- [ ] Revoke compromised credentials/tokens
- [ ] Disable compromised services if necessary
- [ ] Preserve evidence (logs, screenshots)

### Step 2: Initial Assessment (15-60 minutes)

- [ ] What data was affected?
- [ ] How many users impacted?
- [ ] Is the breach ongoing?
- [ ] What is the attack vector?

### Evidence Preservation Checklist

```bash
# Export relevant logs immediately
# Cloud Console -> Logging -> Export

# Document timeline
# - When breach started (if known)
# - When detected
# - Actions taken
```

## 3. Breach Assessment (Hours 1-24)

### Data Classification

| Data Type | GDPR Category | Notification Required |
|-----------|--------------|----------------------|
| Email addresses | Personal Data | Yes (if > low risk) |
| User recipes | Personal Data | Likely |
| Shopping lists | Personal Data | Likely |
| Authentication tokens | Technical Data | Yes |
| Payment data | Sensitive Data | Always (N/A for Butlery) |

### Risk Assessment Matrix

| Factor | Low Risk | High Risk |
|--------|----------|-----------|
| Data Volume | < 100 users | > 1000 users |
| Data Type | Non-sensitive | Sensitive |
| Encryption | Data encrypted | Data plaintext |
| Access Duration | < 1 hour | > 24 hours |

## 4. GDPR Notification (72-Hour Requirement)

### Authority Notification

**Deadline**: 72 hours from breach discovery
**Required When**: Breach likely to result in risk to individuals

#### Swedish DPA (IMY) Contact

- Website: imy.se
- Email: imy@imy.se
- Form: https://www.imy.se/verksamhet/dataskydd/personuppgiftsincidenter/

#### Notification Content

1. Nature of the breach
2. Categories and approximate number of data subjects
3. Name and contact details of DPO
4. Likely consequences of the breach
5. Measures taken or proposed

### User Notification Template

**Required When**: High risk to individuals' rights and freedoms

```
Subject: Important Security Notice from Butlery

Dear [User],

We are writing to inform you of a security incident that may have affected your data.

WHAT HAPPENED
[Brief, clear description of the incident]

WHAT DATA WAS INVOLVED
[List specific data types affected]

WHAT WE ARE DOING
[Actions taken to address the breach]

WHAT YOU CAN DO
- [Recommended action 1, e.g., change passwords]
- [Recommended action 2]

HOW TO CONTACT US
If you have questions, please contact: [email]

We sincerely apologize for any concern this may cause.

The Butlery Team
```

## 5. Post-Incident Actions

### Documentation (Within 7 Days)

- [ ] Complete incident report
- [ ] Root cause analysis
- [ ] Timeline of events
- [ ] List of affected users
- [ ] Evidence of notifications sent

### Remediation (Within 30 Days)

- [ ] Fix vulnerability that enabled breach
- [ ] Update security controls
- [ ] Review access permissions
- [ ] Conduct security audit
- [ ] Update this procedure if needed

### Lessons Learned

```markdown
## Post-Incident Review: [DATE]

### What Happened
[Factual description]

### Root Cause
[Technical and process failures]

### What Went Well
[Effective response elements]

### What Could Improve
[Gaps identified]

### Action Items
- [ ] [Improvement 1] - Owner: [Name] - Due: [Date]
- [ ] [Improvement 2] - Owner: [Name] - Due: [Date]
```

## 6. Contact Information

### Internal Contacts

| Role | Name | Phone | Email |
|------|------|-------|-------|
| Data Protection Lead | | | |
| Technical Lead | | | |
| Communications | | | |

### External Contacts

| Organization | Contact | When to Contact |
|--------------|---------|-----------------|
| Swedish DPA (IMY) | imy@imy.se | Within 72 hours of breach |
| Legal Counsel | | If litigation risk |
| Cyber Insurance | | If policy held |

## 7. Breach Log

| Date | Description | Users Affected | Notified | Resolution |
|------|-------------|----------------|----------|------------|
| | | | | |
