/// P8-U02: the accessibility checks that fail today.
///
/// Shrink-only, as known_state_findings.dart: keys are
/// `view::STATE::mode::width::scale::CODE`, values the registered Linear
/// ticket (BUT-nnnn; package 8 titles in registeredTickets there).
library;

import 'dart:io';

/// Today's failures on every host, from test_results/design-states-a11y.json.
/// Failures that only one host's glyph rasteriser shows are in
/// [knownA11yFindingsLinuxOnly] and [knownA11yFindingsWindowsOnly].
const Map<String, String> knownA11yFindings = {
  'auth-otp::DEFAULT::light::320::2.0::ELLIPSIS': 'BUT-2193',
  'auth-otp::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'auth-otp::DEFAULT::light::360::2.0::ELLIPSIS': 'BUT-2193',
  'auth-otp::DEFAULT::light::412::2.0::ELLIPSIS': 'BUT-2193',
  'auth-otp::DEFAULT::dark::320::2.0::ELLIPSIS': 'BUT-2193',
  'auth-otp::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'auth-otp::DEFAULT::dark::360::2.0::ELLIPSIS': 'BUT-2193',
  'auth-otp::DEFAULT::dark::412::2.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::light::320::1.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'inköpslista::DEFAULT::light::320::1.5::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::light::320::2.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::light::360::1.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::light::360::1.5::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::light::360::2.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::light::412::1.5::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::light::412::2.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::dark::320::1.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::dark::320::1.5::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::dark::320::2.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::dark::360::1.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::dark::360::1.5::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::dark::360::2.0::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::dark::412::1.5::ELLIPSIS': 'BUT-2193',
  'inköpslista::DEFAULT::dark::412::2.0::ELLIPSIS': 'BUT-2193',
  'matlagningsläge::DEFAULT::light::320::1.0::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::light::320::1.5::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::light::360::1.0::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::light::360::1.5::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::light::412::1.0::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::light::412::1.5::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::dark::320::1.0::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::dark::320::1.5::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::dark::360::1.0::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::dark::360::1.5::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::dark::412::1.0::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::DEFAULT::dark::412::1.5::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::light::320::1.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::light::320::1.5::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::light::320::2.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::light::360::1.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'receptdetalj::DEFAULT::light::360::1.5::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::light::360::2.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::light::412::1.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::light::412::1.5::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::light::412::2.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::dark::320::1.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::dark::320::1.5::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::dark::320::2.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::dark::360::1.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'receptdetalj::DEFAULT::dark::360::1.5::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::dark::360::2.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::dark::412::1.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::dark::412::1.5::TAP_TARGET': 'BUT-2194',
  'receptdetalj::DEFAULT::dark::412::2.0::TAP_TARGET': 'BUT-2194',
  'recepteditor::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'receptlista-sök::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'receptlista-sök::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'veckogenerering::DEFAULT::light::320::1.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::light::320::1.5::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::light::320::2.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::light::360::1.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'veckogenerering::DEFAULT::light::360::1.5::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::light::360::2.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::light::412::1.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::light::412::1.5::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::light::412::2.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::dark::320::1.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::dark::320::1.5::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::dark::320::2.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::dark::360::1.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'veckogenerering::DEFAULT::dark::360::1.5::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::dark::360::2.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::dark::412::1.0::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::dark::412::1.5::ELLIPSIS': 'BUT-2193',
  'veckogenerering::DEFAULT::dark::412::2.0::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::light::320::1.5::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::light::320::2.0::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'veckomeny::DEFAULT::light::360::1.5::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::light::360::2.0::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::light::412::1.5::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::light::412::2.0::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::dark::320::1.5::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::dark::320::2.0::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'veckomeny::DEFAULT::dark::360::1.5::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::dark::360::2.0::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::dark::412::1.5::ELLIPSIS': 'BUT-2193',
  'veckomeny::DEFAULT::dark::412::2.0::ELLIPSIS': 'BUT-2193',
  'matlagningsläge::OFFLINE::light::360::1.0::TAP_TARGET': 'BUT-2194',
  'matlagningsläge::OFFLINE::dark::360::1.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::OFFLINE::light::360::1.0::TAP_TARGET': 'BUT-2194',
  'receptdetalj::OFFLINE::dark::360::1.0::TAP_TARGET': 'BUT-2194',
  'vänner-grupp::OFFLINE::light::360::1.0::TAP_LABEL': 'BUT-2195',
  'vänner-grupp::OFFLINE::dark::360::1.0::TAP_LABEL': 'BUT-2195',
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
/// the other. The rendered shortfall is BUT-2196's; these lists only say on
/// which host the check sees it. Only TEXT_CONTRAST may be host-bound: every
/// other check reads layout and semantics, which do not depend on pixels.
///
/// chatt: "Du kan inte skicka meddelanden till denna person", bodyMedium in
/// colorScheme.onSurfaceVariant on surface, measured under 4.5:1 on Linux
/// (run 36389253529).
///
/// inköpslista: the root bar's count line in dark measures under its floor
/// on Linux (run 36689482984) and over it on Windows.
const Map<String, String> knownA11yFindingsLinuxOnly = {
  'chatt::DEFAULT::light::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'chatt::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
  'inköpslista::DEFAULT::dark::360::1.0::TEXT_CONTRAST': 'BUT-2196',
};

/// TEXT_CONTRAST findings that only the Windows test host shows; see
/// [knownA11yFindingsLinuxOnly] for why.
const Map<String, String> knownA11yFindingsWindowsOnly = {};

/// The findings expected on the host running the tests. Other hosts (macOS)
/// have not been measured and get the shared list only.
Map<String, String> knownA11yFindingsOnThisHost() => {
  ...knownA11yFindings,
  if (Platform.isLinux) ...knownA11yFindingsLinuxOnly,
  if (Platform.isWindows) ...knownA11yFindingsWindowsOnly,
};

/// The most entries the three lists may hold together. Lower it when an
/// entry goes.
const int knownA11yFindingsCeiling = 103;
