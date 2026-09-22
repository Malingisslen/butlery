// lib/widgets/common/state/delayed_skeleton.dart
//
// Tröskeln för skelettet — en visningströskel, inte en animation.
//
// produktregler.md:304 (§ 6.6 Laddning): "Stillastående skelett endast där
// formen är känd, och **först efter 300 ms** — en snabb start ska aldrig
// blinka." Samma regel står i produktregler.md:163: "Skelett står stilla och
// visas först efter 300 ms."
//
// Båda raderna binder tröskeln till SKELETTET och håller den skild från
// tallrikslinjen och texten. Därför är tröskeln en egen primitiv som bara
// skelettytan sveps i. Tallrikslinjen fördröjs aldrig.

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Visar [child] först när [threshold] har passerat sedan montering.
///
/// Före tröskeln ritas ingenting och ingen semantiknod finns, så en snabb
/// start varken blinkar eller läses upp. Efter tröskeln står skelettet
/// stilla: ingen toning, ingen övergång (beslut B-18, beslutslogg.md:25).
///
/// Tröskeln gäller hela skelettytan en gång, inte varje ruta för sig.
///
/// Prov som renderar ett skelett pumpar förbi tröskeln med
/// `tester.pump(const Duration(milliseconds: 301))`. `pumpAndSettle` räcker
/// inte: det finns ingen animation att vänta ut, bara en timer.
class DelayedSkeleton extends StatefulWidget {
  const DelayedSkeleton({required this.child, super.key});

  /// Skelettytan som visas efter tröskeln.
  final Widget child;

  /// 300 ms enligt produktregler.md:163 och :304. Det är en tröskel mot
  /// blink, inte en animationsvaraktighet, och bor därför inte bland
  /// rörelsetiderna i app_dimensions.dart.
  static const Duration threshold = Duration(milliseconds: 300);

  @override
  State<DelayedSkeleton> createState() => _DelayedSkeletonState();
}

class _DelayedSkeletonState extends State<DelayedSkeleton> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(DelayedSkeleton.threshold, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _visible ? widget.child : const SizedBox.shrink();
  }
}
