/// P8-U02: the accessibility checks that fail today.
///
/// Shrink-only, as known_state_findings.dart: keys are
/// `view::STATE::mode::width::scale::CODE`, values the registered Linear
/// ticket (BUT-nnnn; package 8 titles in registeredTickets there).
///
/// The known lists hold failures still to be fixed. The accepted lists hold
/// failures Malin has accepted (BUT-2196, 2026-10-03), which the census
/// counts apart from the known failures (D5 = B, 2026-10-04).
library;

import 'dart:io';

/// Today's failures on every host, from test_results/design-states-a11y.json.
/// Failures that only one host's glyph rasteriser shows are in
/// [knownA11yFindingsLinuxOnly] and [knownA11yFindingsWindowsOnly].
const Map<String, String> knownA11yFindings = {};

/// Accepted failures on every host. Host-bound accepted failures are in
/// [acceptedA11yFindingsLinuxOnly] and [acceptedA11yFindingsWindowsOnly].
const Map<String, String> acceptedA11yFindings = {
  'inköpslista::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'receptdetalj::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'receptdetalj::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'receptlista-sök::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'receptlista-sök::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'veckogenerering::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'veckogenerering::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'veckomeny::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'veckomeny::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
};

/// TEXT_CONTRAST findings that only the Linux test host shows (CI, views
/// (ubuntu)).
///
/// textContrastGuideline renders the screen and takes the most frequent
/// colour on each side of the text's mean lightness. Glyph edges are
/// antialiased, so on small text that mode is often a blend of text and
/// background, not the text colour itself, and which blend wins depends on
/// the glyph rasteriser: FreeType on Linux, DirectWrite on Windows. The same
/// token pair can then measure over its floor on one host and under it on
/// the other. Only TEXT_CONTRAST may be host-bound: every other check reads
/// layout and semantics, which do not depend on pixels.
const Map<String, String> knownA11yFindingsLinuxOnly = {};

/// TEXT_CONTRAST findings that only the Windows test host shows; see
/// [knownA11yFindingsLinuxOnly] for why.
const Map<String, String> knownA11yFindingsWindowsOnly = {};

/// Accepted host-bound failures that only the Linux test host shows.
///
/// chatt: "Du kan inte skicka meddelanden till denna person", bodyMedium in
/// colorScheme.onSurfaceVariant on surface, measured under 4.5:1 on Linux
/// (run 36389253529).
///
/// inköpslista: the root bar's count line in dark measures under its floor
/// on Linux (run 36689482984) and over it on Windows.
const Map<String, String> acceptedA11yFindingsLinuxOnly = {
  'chatt::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'chatt::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'inköpslista::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
};

/// Accepted host-bound failures that only the Windows test host shows.
const Map<String, String> acceptedA11yFindingsWindowsOnly = {};

/// The findings, known and accepted, expected on the host running the tests.
/// Other hosts (macOS) have not been measured and get the shared lists only.
Map<String, String> expectedA11yFindingsOnThisHost() => {
  ...knownA11yFindings,
  ...acceptedA11yFindings,
  if (Platform.isLinux) ...knownA11yFindingsLinuxOnly,
  if (Platform.isLinux) ...acceptedA11yFindingsLinuxOnly,
  if (Platform.isWindows) ...knownA11yFindingsWindowsOnly,
  if (Platform.isWindows) ...acceptedA11yFindingsWindowsOnly,
};

/// The most entries the three known lists may hold together. Lower it when
/// an entry goes.
const int knownA11yFindingsCeiling = 0;

/// The most entries the three accepted lists may hold together. Lower it when
/// an entry goes; an accepted failure is never added without Malin's decision.
const int acceptedA11yFindingsCeiling = 12;
