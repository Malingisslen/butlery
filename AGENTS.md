# Repository Guidelines

## Project Structure & Module Organization
Butlery is a Flutter app with a layered MVVM + Repository architecture.

- `lib/`: production code (`core/`, `repositories/`, `services/`, `viewmodels/`, `views/`, `widgets/`, `theme/`, `models/`).
- `test/`: automated tests by scope (`unit/`, `widget/`, `views/`, `integration/`, `e2e/`, `architecture/`), plus shared helpers in `test_support/` and `infrastructure/`.
- `assets/`: app assets (`fonts/`, `illustrations/`, `legal/`).
- `docs/`: architecture, testing, security, and operational docs.
- `tools/validate_architecture.dart`: architecture compliance checker.
- `scripts/`: setup scripts and commit message validation.

## Build, Test, and Development Commands
- `flutter pub get`: install Dart/Flutter dependencies.
- `flutter run`: run locally (use `-d chrome`, `-d windows`, etc. for target platform).
- `flutter analyze --no-fatal-infos`: static analysis used in local hooks.
- `dart format --set-exit-if-changed lib test`: formatting check used in CI.
- `flutter test`: run all tests.
- `flutter test test/unit test/widget test/views --coverage --reporter=expanded`: CI-style test run with coverage.
- `flutter test test/integration --reporter=expanded`: integration suite.
- `dart run tools/validate_architecture.dart`: architecture validation.
- `npx lefthook install` then `npx lefthook run pre-commit`: install/run git hooks.

## Coding Style & Naming Conventions
- Follow Dart/Flutter style with 2-space indentation and snake_case file names (for example `recipe_builder.dart`).
- Test files use `*_test.dart`.
- Lints are enforced in `analysis_options.yaml` (`flutter_lints` + custom rules): prefer single quotes, package imports, const/final, and avoid `print`.
- Keep architectural boundaries intact: use repositories/services via DI (`ServiceLocator.get<T>()`), avoid direct `FirebaseFirestore.instance`.
- Keep files under ~500 lines unless already documented as an accepted exception.

## Testing Guidelines
- Primary frameworks: `flutter_test`, `integration_test`, `mocktail`.
- Add tests in the matching folder for the layer you change.
- Coverage gates in `codecov.yml`: project target 60%, patch target 70%.
- For E2E, use `scripts/run_e2e_tests.sh --tier mock --verbose` (or `--tier emulator`).

## Commit & Pull Request Guidelines
- Commit format is validated by hook: `type(scope): description` (scope optional).  
  Example: `fix(auth): handle token refresh timeout`.
- Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`.
- PRs should follow `.github/PULL_REQUEST_TEMPLATE.md`: summary, type of change, testing notes, related issues, and screenshots for UI changes.
- Before opening a PR, run `flutter analyze` and relevant tests locally.

## Security & Configuration Tips
- Copy `.env.example` to `.env.development` for local setup.
- Never commit secrets; use environment files and Firebase project configuration per environment.
