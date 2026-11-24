import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/viewmodels/recurring_day_rules/recurring_day_rule_store.dart';

/// "Fasta dagar" (BUT-2490): the list and the editor share this model.
class RecurringDayRulesViewModel extends BaseViewModel with ErrorHandlingMixin {
  /// [store] decides whose rules these are; without one it is the signed-in
  /// user's own, read through [reader] and saved through [editor].
  RecurringDayRulesViewModel({
    RecurringDayRuleStore? store,
    OwnProfileReader? reader,
    OwnProfileEditor? editor,
  }) : _store = store ?? ProfileRuleStore(reader: reader, editor: editor) {
    _store.addListener(notifyListeners);
  }

  final RecurringDayRuleStore _store;

  /// False for a member reading their group's rules: every write is refused.
  bool get canEdit => _store.canEdit;

  // A swiped row must leave the tree in the same frame, before the write
  // has reached the profile, so a delete hides its rule while it saves.
  final Set<String> _hiding = {};

  List<RecurringDayRule> get _stored => _store.rules;

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
    if (!canEdit) {
      setError(AppLocale.current.recurringRuleSaveFailed);
      return false;
    }
    final saved = await safeExecute(
      () => _store.write(next),
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
    _store.removeListener(notifyListeners);
    _store.dispose();
    super.dispose();
  }
}
