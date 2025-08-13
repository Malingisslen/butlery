# Test Templates

This directory contains template files for different types of tests in the Butlery codebase.

## Available Templates

1. **di_heavy_test_template.dart.template**
   - For tests requiring full dependency injection
   - Use for: Repository tests, complex service tests
   - Features: TestServiceLocator, mocks from production_mocks.dart

2. **simple_unit_test_template.dart.template**
   - For pure logic tests with minimal dependencies
   - Use for: Utility classes, pure functions, simple models
   - Features: Minimal setup, no DI required

3. **viewmodel_test_template.dart.template**
   - For ViewModel tests with ChangeNotifier
   - Use for: Any ViewModel that extends ChangeNotifier
   - Features: Production ServiceLocator handling, state management testing

4. **model_test_template.dart.template**
   - For data model tests
   - Use for: Testing model serialization, validation, business logic
   - Features: JSON/Firestore conversion testing, equality testing

## How to Use

1. Copy the appropriate template file
2. Rename it from `.dart.template` to `.dart`
3. Replace placeholder names (YourClass, YourService, etc.) with actual names
4. Remove any sections you don't need
5. Add your test-specific logic

## Template Structure

All templates follow the standard AAA pattern:
- **Arrange**: Set up test data and mocks
- **Act**: Execute the code being tested
- **Assert**: Verify the results

## Best Practices

- Always use `BaseUnitTest.setupUnit()` in `setUpAll()` for consistency
- Use configuration methods on mocks instead of stubbing concrete getters
- Clean up resources in `tearDown()` and `tearDownAll()`
- Group related tests using `group()`
- Use descriptive test names that explain what is being tested

## Note

These files have the `.template` extension to prevent them from being treated as actual test files by the Flutter analyzer and test runner.