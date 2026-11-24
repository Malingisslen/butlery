import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// "Fasta dagar" (BUT-2490): the list and the editor share this model.
class RecurringDayRulesViewModel extends BaseViewModel with ErrorHandlingMixin {
  RecurringDayRulesViewModel({
    OwnProfileReader? reader,
    OwnProfileEditor? editor,
  }) : _reader = reader ?? ServiceLocator.get<OwnProfileReader>(),
       _editor = editor ?? ServiceLocator.get<OwnProfileEditor>() {
    _reader.addListener(notifyListeners);
  }

  final OwnProfileReader _reader;
  final OwnProfileEditor _editor;

  // A swiped row must leave the tree in the same frame, before the write
  // has reached the profile, so a delete hides its rule while it saves.
  final Set<String> _hiding = {};

  List<RecurringDayRule> get _stored =>
      _reader.currentUserProfile?.recurringDayRules ?? const [];

  List<RecurringDayRule> get rules => _hiding.isEmpty
      ? _stored
      : [
          for (final rule in _stored)
            if (!_hiding.contains(rule.id)) rule,
        ];

  RecurringDayRule? ruleAt(DayOfWeek day, MealSlot meal) {
    final id = RecurringDayRule.idFor(day, meal);
    for (final rule in rules) {
      if (rule.id == id) return rule;
    }
    return null;
  }

  /// Saves [rule] over the one on the same day and meal. False when it was
  /// refused or did not save; [error] then holds the Swedish message.
  Future<bool> save(RecurringDayRule rule) async {
    final next = RecurringDayRules.upsert(_stored, rule);
    if (next == null) {
      setError(
        AppLocale.current.recurringRuleLimit(RecurringDayRules.maxRules),
      );
      return false;
    }
    return _write(next);
  }

  Future<bool> setPaused(RecurringDayRule rule, bool paused) async {
    final next = RecurringDayRules.upsert(
      _stored,
      rule.copyWith(paused: paused),
    );
    if (next == null) {
      setError(AppLocale.current.recurringRuleSaveFailed);
      return false;
    }
    return _write(next);
  }

  Future<bool> delete(RecurringDayRule rule) async {
    _hiding.add(rule.id);
    notifyListeners();
    final ok = await _write(RecurringDayRules.remove(_stored, rule.id));
    _hiding.remove(rule.id);
    notifyListeners();
    return ok;
  }

  Future<bool> _write(List<RecurringDayRule> next) async {
    clearError();
    final saved = await safeExecute(
      () => _editor.setRecurringDayRules(next),
      operationName: 'Save recurring day rules',
      defaultValue: false,
    );
    if (isDisposed) return saved ?? false;
    if (saved != true) {
      setError(AppLocale.current.recurringRuleSaveFailed);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _reader.removeListener(notifyListeners);
    super.dispose();
  }
}
