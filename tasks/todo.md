# BUT-2142: two-step verification with an authenticator app (2026-10-10)

Malin's decisions on 2026-10-10:
- "Autentiseringsapp" on the card about how the codes are delivered, so SMS is out.
- "Stryk mejlet" on the card about the security e-mail.

PR #641 (branch claude/project-thread-6qjbff) built two-step verification around SMS and a Resend security e-mail. This plan changes it to TOTP: codes from an app such as Google Authenticator. The backup codes, recovery and server checks stay as they are.

Measured: firebase_auth 6.5.4 has `TotpMultiFactorGenerator`, which provides `generateSecret`, `getAssertionForEnrollment` and `getAssertionForSignIn`. It also has `TotpSecret.generateQrCodeUrl` and `TotpSecret.openInOtpApp`, and `TotpMultiFactorInfo`. firebase_auth_web 6.2.3 has the interop for all of these.

- [x] Server: strip the security e-mail (`mfa-security-email.ts` and its test, the notify deps, the `FEEDBACK_EMAIL_API_KEY` secret on the callables, and the deploy step).
- [x] Service (`auth_mfa_service.dart`):
  - Replace phone enrollment and sign-in with TOTP: start enrollment returns the secret key and the otpauth URL, and complete enrollment takes the six-digit code.
  - Sign-in resolves with the `TotpMultiFactorInfo` hint's uid plus the code.
  - No phone path is kept, because no account can have a phone factor: Identity Platform was never enabled.
- [x] `mfa_types.dart`:
  - Drop the phone parsing, `maskedPhoneTail` and `phoneHint`.
  - Add an opaque `MfaTotpSetup` (secret key, otpauth URL, wrapped `TotpSecret`).
- [x] Settings view (`mfa_settings_view.dart`), in this order:
  1. The enroll form is a "Slå på" button.
  2. Re-authentication.
  3. Ten backup codes, shown and acknowledged.
  4. A setup step with "Öppna i autentiseringsapp" (`openInOtpApp`, on mobile) and the key shown in groups with a copy button.
  5. A six-digit code field and "Bekräfta".

  No new package, so no QR image. The key can be typed into any authenticator app.
- [x] Challenge view (`mfa_challenge_view.dart`):
  - It asks for "koden från din autentiseringsapp". There is no resend, no auto-verify and no phone hint.
  - Backup-code recovery stays.
- [x] `auth_service.dart`, `auth_repository` and `firebase_auth_repository`:
  - The resolver uses the TOTP hint.
  - Remove `verifyPhoneNumber` if nothing else calls it.
- [x] Export (`compliance_export_manager.dart`): the factor's type is reported without a phone number.
- [x] l10n sv/en: new strings, and the SMS strings removed.
- [ ] Tests: service, challenge, settings and export tests are rewritten for TOTP.
- [x] Census:
  - `automatisk-verifiering` and `utmaning-maskerad-ledtrad` become RESTING, because they describe SMS behaviour that Malin replaced on 2026-10-10.
  - The other three MFA rows stay TESTED, pointing at the new test names.
- [x] Privacy text:
  - Remove the mobile-number and Resend parts, and say "autentiseringsapp".
  - `PrivacyInfo.xcprivacy` goes back to main (no PhoneNumber).
  - Malin reads the changed text before merge.
- [ ] Console:
  - Identity Platform upgrade (a card, waiting on Malin's yes).
  - Then enable the TOTP provider (`mfa.providerConfigs[].totpProviderConfig.adjacentIntervals`).
  - No SMS and no region rule. The budget alarm stays.

Acceptance:
- analyze is clean.
- The changed suites pass, along with the census and flow-coverage tests.
- functions tsc and the functions tests pass.
- Every gate passes.
- Malin's phone test happens before merge.

## For Malin

Tvåstegsverifieringen byggs om så att koden kommer från en app som Google Authenticator i stället för sms. Det kostar inget per inloggning. Reservkoderna och skydden finns kvar, och säkerhetsmejlet tas bort. Integritetstexten ändras så att den inte längre nämner mobilnummer eller Resend, och du får läsa den innan något mergas.
