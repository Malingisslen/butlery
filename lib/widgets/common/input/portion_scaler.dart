// lib/widgets/common/input/portion_scaler.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/widgets/common/input/portion_scaler_logic.dart';
import 'package:butlery/widgets/common/input/portion_scaler_ui.dart';

/// Smart portion scaler with ingredient scaling and unit conversion
/// This widget provides portion scaling functionality with support for both
/// Swedish and American units, automatic unit detection, and conversion capabilities.
class PortionScaler extends StatefulWidget {
  final int originalPortions;
  final List<String> originalIngredients;
  final Function(int newPortions, List<String> scaledIngredients)
      onPortionChanged;
  final int minPortions;
  final int maxPortions;

  const PortionScaler({
    super.key,
    required this.originalPortions,
    required this.originalIngredients,
    required this.onPortionChanged,
    this.minPortions = 1,
    this.maxPortions = 20,
  });

  @override
  State<PortionScaler> createState() => _PortionScalerState();
}

class _PortionScalerState extends State<PortionScaler>
    with SingleTickerProviderStateMixin {
  late int _currentPortions;
  late List<String> _scaledIngredients;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _convertToSwedish = false;
  bool _hasAmericanUnits = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _currentPortions = widget.originalPortions;
    _scaledIngredients = List.from(widget.originalIngredients);
    _hasAmericanUnits =
        PortionScalerLogic.detectAmericanUnits(widget.originalIngredients);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updatePortions(int newPortions) {
    if (newPortions < widget.minPortions || newPortions > widget.maxPortions) {
      return;
    }

    if (mounted) {
      setState(() {
        _currentPortions = newPortions;
        _scaledIngredients = PortionScalerLogic.scaleIngredients(
          widget.originalIngredients,
          widget.originalPortions,
          newPortions,
          _convertToSwedish,
        );
      });
    }

    // Skip animation when reduced motion is enabled
    if (!_reduceMotion) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }

    HapticFeedback.lightImpact();
    widget.onPortionChanged(_currentPortions, _scaledIngredients);
  }

  void _toggleUnitConversion() {
    if (mounted) {
      setState(() {
        _convertToSwedish = !_convertToSwedish;
        _scaledIngredients = PortionScalerLogic.scaleIngredients(
          widget.originalIngredients,
          widget.originalPortions,
          _currentPortions,
          _convertToSwedish,
        );
      });
    }

    HapticFeedback.mediumImpact();
    widget.onPortionChanged(_currentPortions, _scaledIngredients);
  }

  @override
  Widget build(BuildContext context) {
    return PortionScalerUI.buildScaler(
      context: context,
      currentPortions: _currentPortions,
      originalPortions: widget.originalPortions,
      scaledIngredients: _scaledIngredients,
      originalIngredients: widget.originalIngredients,
      convertToSwedish: _convertToSwedish,
      hasAmericanUnits: _hasAmericanUnits,
      minPortions: widget.minPortions,
      maxPortions: widget.maxPortions,
      scaleAnimation: _scaleAnimation,
      onUpdatePortions: _updatePortions,
      onToggleUnitConversion: _toggleUnitConversion,
    );
  }
}
