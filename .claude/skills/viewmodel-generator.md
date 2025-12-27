# ViewModel Generator

> Använd denna skill när du skapar nya ViewModels.

## Enkel ViewModel

```dart
import 'package:flutter/foundation.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';

class {Entity}ViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final {Entity}Service _service;

  {Entity}? _entity;
  bool _isLoading = false;
  String? _errorMessage;

  {Entity}ViewModel({
    {Entity}Service? service,
  }) : _service = service ?? ServiceLocator.get<{Entity}Service>();

  // Getters
  {Entity}? get entity => _entity;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  // Load
  Future<void> load(String id) async {
    _setLoading(true);
    try {
      _entity = await _service.getById(id);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Kunde inte ladda: $e';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cleanup
    super.dispose();
  }
}
```

## Komplex ViewModel (>300 rader)

Delegera till managers:

```dart
class {Entity}FormViewModel extends ChangeNotifier
    with ErrorHandlingMixin, ErrorCoordinatorMixin {

  // Managers för olika ansvarsområden
  late final {Entity}FormState _state;
  late final {Entity}ValidationManager _validationManager;
  late final {Entity}PersistenceManager _persistenceManager;
  late final {Entity}ImageManager _imageManager;

  {Entity}FormViewModel() {
    _state = {Entity}FormState();
    _validationManager = {Entity}ValidationManager(_state);
    _persistenceManager = {Entity}PersistenceManager();
    _imageManager = {Entity}ImageManager();
  }

  // Exponera managers
  {Entity}FormState get state => _state;
  {Entity}ImageManager get imageManager => _imageManager;

  // Koordinera operationer
  Future<bool> save() async {
    if (!_validationManager.validate()) return false;
    return await _persistenceManager.save(_state.toEntity());
  }

  @override
  void dispose() {
    _imageManager.dispose();
    super.dispose();
  }
}
```

## Manager-mönster

```dart
// State manager
class {Entity}FormState {
  String title = '';
  String description = '';
  List<String> items = [];

  bool get isValid => title.isNotEmpty;

  {Entity} toEntity() => {Entity}(title: title, ...);
}

// Validation manager
class {Entity}ValidationManager {
  final {Entity}FormState _state;

  {Entity}ValidationManager(this._state);

  bool validate() {
    return _state.title.isNotEmpty;
  }
}

// Persistence manager
class {Entity}PersistenceManager {
  final _service = ServiceLocator.get<{Entity}Service>();

  Future<bool> save({Entity} entity) async {
    try {
      await _service.create(entity);
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

## Checklista

- [ ] `extends ChangeNotifier`
- [ ] `with ErrorHandlingMixin`
- [ ] ServiceLocator för dependencies
- [ ] `dispose()` för cleanup
- [ ] `notifyListeners()` efter state-ändringar
- [ ] Om >300 rader → delegera till managers

## Registrera i DI (om factory)

```dart
// I UIModule eller relevant module
container.registerFactory<{Entity}ViewModel>(
  () => {Entity}ViewModel(),
);
```

## Nyckelfilar

- `lib/core/mixins/error_handling_mixin.dart`
- `lib/viewmodels/recipe_form/` - Exemplar på manager-delegation
