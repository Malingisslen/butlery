/// Thin fake of [PersonalTagViewModel] for the personal-tags view-widget tests
/// (REC-14 / REC-15). It `extends ChangeNotifier implements PersonalTagViewModel`
/// so the views' `Consumer<PersonalTagViewModel>` rebuilds on [setState], while
/// every getter the views actually read is backed by a mutable field. Anything
/// the views do NOT touch routes through [noSuchMethod] — so if a refactor
/// starts reading new VM surface, it surfaces as a test error rather than a
/// silent pass.
library;

import 'package:flutter/foundation.dart';

import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';

class FakePersonalTagViewModel extends ChangeNotifier
    implements PersonalTagViewModel {
  List<PersonalTag> _tags = const [];
  List<PersonalTagGroup> _groups = const [];
  Map<String, int> _usageCounts = const {};
  bool _isLoading = false;
  String? _error;
  String? _selectedTagId;

  int initializeCalls = 0;
  int loadTagStatisticsCalls = 0;
  int loadRuleEffectivenessCalls = 0;

  /// Drive the view into a known state and notify its Consumer to rebuild.
  void setState({
    required List<PersonalTag> tags,
    List<PersonalTagGroup> groups = const [],
    bool isLoading = false,
    String? error,
    Map<String, int> usageCounts = const {},
  }) {
    _tags = tags;
    _groups = groups;
    _isLoading = isLoading;
    _error = error;
    _usageCounts = usageCounts;
    notifyListeners();
  }

  @override
  List<PersonalTag> get tags => List.unmodifiable(_tags);

  @override
  List<PersonalTagGroup> get groups => List.unmodifiable(_groups);

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  bool get hasError => _error != null;

  @override
  bool get hasTags => _tags.isNotEmpty;

  @override
  bool get hasGroups => _groups.isNotEmpty;

  @override
  bool get isLoadingStats => false;

  @override
  bool get isLoadingRuleStats => false;

  @override
  String? get selectedTagId => _selectedTagId;

  @override
  PersonalTag? get selectedTag =>
      _selectedTagId != null ? getTagById(_selectedTagId!) : null;

  @override
  void selectTag(String? tagId) {
    _selectedTagId = tagId;
    notifyListeners();
  }

  @override
  PersonalTag? getTagById(String id) =>
      _tags.where((t) => t.id == id).firstOrNull;

  @override
  List<PersonalTag> getTagsForGroup(String? groupId) =>
      _tags.where((t) => t.groupId == groupId).toList();

  @override
  int getUsageCount(String tagName) => _usageCounts[tagName] ?? 0;

  @override
  int get maxUsageCount =>
      _usageCounts.values.fold(0, (max, v) => v > max ? v : max);

  @override
  int getRuleMatchCount(String ruleId) => 0;

  @override
  List<PersonalTag> get unusedTags =>
      _tags.where((t) => getUsageCount(t.name) == 0).toList();

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<void> loadTagStatistics() async {
    loadTagStatisticsCalls++;
  }

  @override
  Future<void> loadRuleEffectiveness() async {
    loadRuleEffectivenessCalls++;
  }

  // Everything else the views never touch in the tested branches.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
