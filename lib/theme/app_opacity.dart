// The opacity ladder (BUT-2376), named after its steps in design/tokens.json
// `opacityLadder`. onPaper steps are ink-tinted layers over a light ground;
// onInk steps are paper-tinted layers over a dark ground or a photo. A value
// that sits on both ladders (0.4) is the one to use for a colour that flips
// with the mode. test/unit/theme/app_opacity_test.dart holds this file to
// tokens.json.
library;

abstract final class AppOpacity {
  static const double onPaper02 = 0.02;
  static const double onPaper04 = 0.04;
  static const double onPaper10 = 0.1;
  static const double onPaper20 = 0.2;
  static const double onPaper40 = 0.4;

  static const double onInk18 = 0.18;
  static const double onInk35 = 0.35;
  static const double onInk40 = 0.4;
  static const double onInk54 = 0.54;
  static const double onInk60 = 0.6;

  static const List<double> onPaper = [
    onPaper02,
    onPaper04,
    onPaper10,
    onPaper20,
    onPaper40,
  ];

  static const List<double> onInk = [
    onInk18,
    onInk35,
    onInk40,
    onInk54,
    onInk60,
  ];
}
