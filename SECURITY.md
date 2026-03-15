# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**DO NOT** create public GitHub issues for security vulnerabilities.

Please report security issues to: **security@butlery.app**

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Any suggested fixes (optional)
- Your contact information for follow-up

### Response Timeline

| Stage | Timeline |
|-------|----------|
| Initial acknowledgment | 48 hours |
| Status update | 7 days |
| Resolution target | 30-90 days (severity dependent) |

### What to Expect

1. **Acknowledgment**: We will acknowledge receipt within 48 hours
2. **Assessment**: Our security team will assess the vulnerability
3. **Communication**: We will keep you informed of our progress
4. **Resolution**: We will work to resolve the issue promptly
5. **Disclosure**: We will coordinate disclosure timing with you

## Security Measures

Butlery implements the following security measures:

- Firebase Authentication with email/password
- Firestore Security Rules enforcing per-user data isolation
- Server-side rate limiting on social operations
- Input validation on allergen-critical data (tagResult, ingredients)
- HTTPS enforced on all platforms via Firebase SDK
- PII scrubbing before external API calls
- Android backup disabled (android:allowBackup="false")
- Default-deny Firestore rules catch-all

## Recognition

We maintain a hall of fame for security researchers who responsibly disclose vulnerabilities. With your permission, we will acknowledge your contribution.

## Scope

This security policy applies to:

- Butlery mobile application (iOS/Android)
- Butlery web application
- Butlery backend services

Out of scope:

- Third-party services and integrations
- Social engineering attacks
- Physical security
