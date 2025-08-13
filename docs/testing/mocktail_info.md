# Detaljerad Guide för Mocktail i Flutter/Dart

## Innehållsförteckning
1. [Vad är Mocktail?](#vad-är-mocktail)
2. [Installation och Setup](#installation-och-setup)
3. [Grundläggande koncept](#grundläggande-koncept)
4. [Skapa din första mock](#skapa-din-första-mock)
5. [Stubbing - Att definiera beteenden](#stubbing---att-definiera-beteenden)
6. [Verifiering - Kontrollera anrop](#verifiering---kontrollera-anrop)
7. [Argument Matchers](#argument-matchers)
8. [Hantera asynkrona metoder](#hantera-asynkrona-metoder)
9. [Avancerade tekniker](#avancerade-tekniker)
10. [Vanliga problem och lösningar](#vanliga-problem-och-lösningar)
11. [Komplett exempel](#komplett-exempel)

## Vad är Mocktail?

Mocktail är ett mockning-bibliotek för Dart som gör det enkelt att skapa "fejkade" versioner av klasser för testning. Till skillnad från Mockito behöver Mocktail ingen kodgenerering - allt fungerar direkt med Dart's null-safety.

### Varför använda Mocktail?
- **Ingen kodgenerering krävs** - Du behöver inte köra build_runner
- **Enkel API** - Lätt att lära sig och använda
- **Null-safety stöd** - Fungerar perfekt med modern Dart
- **Bättre felmeddelanden** - Lättare att felsöka tester

## Installation och Setup

### Steg 1: Lägg till beroendet

Öppna din `pubspec.yaml` fil och lägg till mocktail under `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.3  # Kontrollera senaste version på pub.dev
```

### Steg 2: Installera paketet

Kör följande kommando i terminalen:

```bash
flutter pub get
```

### Steg 3: Importera i din testfil

```dart
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
```

## Grundläggande koncept

### Vad är en Mock?

En mock är en "fejkad" version av en klass som du kan kontrollera helt. Du bestämmer:
- Vad metoderna ska returnera
- Hur de ska bete sig
- Om de ska kasta undantag

### Tre huvudsteg i mocktestning:

1. **Arrange (Förbered)**: Skapa mocks och definiera deras beteende
2. **Act (Utför)**: Kör koden som ska testas
3. **Assert (Verifiera)**: Kontrollera att rätt saker hände

## Skapa din första mock

### Exempel: En enkel klass att mocka

```dart
// Den riktiga klassen
class AuthenticationService {
  Future<bool> login(String email, String password) async {
    // Riktig implementation som pratar med servern
    return true;
  }
  
  Future<User> getCurrentUser() async {
    // Hämtar användaren från servern
    return User(name: 'John', email: 'john@example.com');
  }
}

class User {
  final String name;
  final String email;
  
  User({required this.name, required this.email});
}
```

### Skapa en mock av klassen

```dart
// I din testfil
import 'package:mocktail/mocktail.dart';

// Skapa mock genom att utöka Mock och implementera din klass
class MockAuthenticationService extends Mock implements AuthenticationService {}

// Nu kan du använda din mock i tester!
```

## Stubbing - Att definiera beteenden

Stubbing betyder att du bestämmer vad en metod ska returnera när den anropas.

### Grundläggande stubbing med `when` och `thenReturn`

```dart
void main() {
  test('Login returnerar true för giltiga uppgifter', () async {
    // Arrange - Skapa mock
    final mockAuth = MockAuthenticationService();
    
    // Stubba metoden - säg vad den ska returnera
    when(() => mockAuth.login('test@email.com', '123456'))
        .thenReturn(true);
    
    // Act - Anropa metoden
    final result = await mockAuth.login('test@email.com', '123456');
    
    // Assert - Verifiera resultatet
    expect(result, true);
  });
}
```

### Olika sätt att stubba

#### 1. `thenReturn` - För synkrona värden

```dart
// För enkla returvärden
when(() => mockService.getValue()).thenReturn(42);

// För objekt
when(() => mockService.getUser()).thenReturn(
  User(name: 'Test', email: 'test@test.com')
);
```

#### 2. `thenAnswer` - För asynkrona värden (Future/Stream)

```dart
// För Future
when(() => mockService.fetchData())
    .thenAnswer((_) async => 'Data från server');

// För Future med fördröjning
when(() => mockService.slowOperation())
    .thenAnswer((_) async {
      await Future.delayed(Duration(seconds: 2));
      return 'Klar!';
    });

// För Stream
when(() => mockService.getDataStream())
    .thenAnswer((_) => Stream.value('Stream data'));
```

#### 3. `thenThrow` - För att kasta undantag

```dart
// Kasta ett undantag
when(() => mockService.riskyOperation())
    .thenThrow(Exception('Något gick fel!'));

// Kasta specifikt undantag
when(() => mockService.networkCall())
    .thenThrow(NetworkException('Ingen internetanslutning'));
```

## Verifiering - Kontrollera anrop

Efter att din kod har körts vill du ofta verifiera att rätt metoder anropades.

### Grundläggande verifiering med `verify`

```dart
test('Användaren sparas när registrering lyckas', () async {
  // Arrange
  final mockDatabase = MockDatabase();
  final mockAuth = MockAuthenticationService();
  final controller = RegistrationController(mockDatabase, mockAuth);
  
  // Stubba
  when(() => mockAuth.register(any(), any()))
      .thenAnswer((_) async => true);
  when(() => mockDatabase.saveUser(any()))
      .thenAnswer((_) async => true);
  
  // Act
  await controller.registerUser('test@test.com', 'password123');
  
  // Assert - Verifiera att saveUser anropades exakt en gång
  verify(() => mockDatabase.saveUser(any())).called(1);
});
```

### Olika verifieringsalternativ

```dart
// Verifiera att metoden anropades minst en gång
verify(() => mock.method()).called(greaterThan(0));

// Verifiera att metoden INTE anropades
verifyNever(() => mock.method());

// Verifiera ordningen på anrop
verifyInOrder([
  () => mock.firstMethod(),
  () => mock.secondMethod(),
  () => mock.thirdMethod(),
]);

// Verifiera att inga fler interaktioner skedde
verifyNoMoreInteractions(mock);
```

## Argument Matchers

Argument matchers låter dig vara flexibel med vilka argument som accepteras.

### `any()` - Matchar vilket värde som helst

```dart
// För positionsargument
when(() => mock.method(any())).thenReturn('resultat');

// För namngivna argument
when(() => mock.method(
  id: any(named: 'id'),
  name: any(named: 'name')
)).thenReturn(true);
```

### `any(that:)` - Matchar med villkor

```dart
// Matcha endast sträng som innehåller 'test'
when(() => mock.method(
  any(that: contains('test'))
)).thenReturn(true);

// Matcha endast nummer större än 10
when(() => mock.calculate(
  any(that: greaterThan(10))
)).thenReturn(100);

// Använd isA för typkontroll
when(() => mock.process(
  any(that: isA<String>().having((s) => s.length, 'length', greaterThan(5)))
)).thenReturn('OK');
```

### `captureAny()` - Fånga argumentvärden

```dart
test('Fånga argument som skickades', () {
  // Arrange
  final mock = MockService();
  when(() => mock.save(captureAny())).thenReturn(true);
  
  // Act
  mock.save('första');
  mock.save('andra');
  mock.save('tredje');
  
  // Assert - Fånga alla värden som skickades
  final captured = verify(() => mock.save(captureAny())).captured;
  expect(captured, ['första', 'andra', 'tredje']);
});
```

## Hantera asynkrona metoder

### Future-metoder

```dart
class UserRepository {
  Future<User?> fetchUser(int id) async {
    // Hämtar från API
  }
  
  Future<void> updateUser(User user) async {
    // Uppdaterar användare
  }
}

// Mock
class MockUserRepository extends Mock implements UserRepository {}

// Test
test('Hämta användare asynkront', () async {
  // Arrange
  final mockRepo = MockUserRepository();
  final testUser = User(id: 1, name: 'Test');
  
  // Stubba med thenAnswer för Future
  when(() => mockRepo.fetchUser(1))
      .thenAnswer((_) async => testUser);
  
  // Act
  final user = await mockRepo.fetchUser(1);
  
  // Assert
  expect(user, testUser);
  verify(() => mockRepo.fetchUser(1)).called(1);
});
```

### Stream-metoder

```dart
test('Lyssna på dataström', () async {
  // Arrange
  final mockService = MockDataService();
  final testData = [1, 2, 3, 4, 5];
  
  // Stubba stream
  when(() => mockService.dataStream)
      .thenAnswer((_) => Stream.fromIterable(testData));
  
  // Act & Assert
  await expectLater(
    mockService.dataStream,
    emitsInOrder(testData),
  );
});
```

### Void Future-metoder

```dart
test('Hantera void Future metoder', () async {
  // Arrange
  final mock = MockService();
  
  // VIKTIGT: Du måste explicit stubba void Future metoder!
  when(() => mock.performAction())
      .thenAnswer((_) async {});  // Tom Future för void
  
  // Act
  await mock.performAction();
  
  // Assert
  verify(() => mock.performAction()).called(1);
});
```

## Avancerade tekniker

### RegisterFallbackValue för egna typer

När du använder `any()` med egna typer måste du registrera fallback-värden:

```dart
// Din egen klass
class CustomRequest {
  final String data;
  CustomRequest(this.data);
}

// Fake implementation för testing
class FakeCustomRequest extends Fake implements CustomRequest {}

// I din test
void main() {
  // Registrera en gång i setUpAll
  setUpAll(() {
    registerFallbackValue(FakeCustomRequest());
  });
  
  test('Använd any() med egen typ', () {
    final mock = MockService();
    
    // Nu kan du använda any() med CustomRequest
    when(() => mock.process(any())).thenReturn('OK');
    
    mock.process(CustomRequest('test'));
    
    verify(() => mock.process(any())).called(1);
  });
}
```

### Flera stubbar för samma metod

```dart
test('Olika svar för olika anrop', () async {
  final mock = MockService();
  int callCount = 0;
  
  // Returnera olika värden baserat på antal anrop
  when(() => mock.getValue()).thenAnswer((_) {
    callCount++;
    if (callCount == 1) return 'första';
    if (callCount == 2) return 'andra';
    return 'resten';
  });
  
  expect(mock.getValue(), 'första');
  expect(mock.getValue(), 'andra');
  expect(mock.getValue(), 'resten');
  expect(mock.getValue(), 'resten');
});
```

### Mocka exceptions efter flera anrop

```dart
test('Först fel, sedan framgång', () async {
  final mock = MockHttpClient();
  final responses = [
    () => throw SocketException('Nätverksfel'),
    () => Response('{"success": true}', 200),
  ];
  
  when(() => mock.get(any()))
      .thenAnswer((_) => responses.removeAt(0)());
  
  // Första anropet kastar exception
  expect(() => mock.get(Uri.parse('test.com')), 
         throwsA(isA<SocketException>()));
  
  // Andra anropet lyckas
  final response = mock.get(Uri.parse('test.com'));
  expect(response.statusCode, 200);
});
```

## Vanliga problem och lösningar

### Problem 1: "Null is not a subtype of Future<void>"

**Orsak**: Du har inte stubbat en void Future-metod.

**Lösning**:
```dart
// Fel ❌
final mock = MockService();
await mock.voidAsyncMethod(); // Kastar fel!

// Rätt ✅
final mock = MockService();
when(() => mock.voidAsyncMethod()).thenAnswer((_) async {});
await mock.voidAsyncMethod(); // Fungerar!
```

### Problem 2: "Bad state: No method stub was called"

**Orsak**: Du försöker verifiera en metod som aldrig anropades.

**Lösning**:
```dart
// Kontrollera att metoden verkligen anropas
verify(() => mock.method()).called(1);

// Eller använd verifyNever om den inte ska anropas
verifyNever(() => mock.method());
```

### Problem 3: Type inference problem med generics

**Orsak**: Dart kan inte avgöra typen för generiska metoder.

**Lösning**:
```dart
// Specificera typen explicit
when(() => mock.genericMethod<String>(any()))
    .thenReturn('resultat');
```

### Problem 4: "Null is not a subtype of Future<List<String>>"

**Orsak**: Du har inte stubbat en metod som returnerar Future<List> eller liknande.

**Lösning**:
```dart
// Fel ❌
final mock = MockCacheHelper();
await mock.getAllKeys(); // Kastar fel!

// Rätt ✅
final mock = MockCacheHelper();
when(() => mock.getAllKeys()).thenAnswer((_) async => <String>[]);
await mock.getAllKeys(); // Fungerar!
```

### Problem 5: Verifiering av metoder som anropas flera gånger

**Orsak**: Produktionskoden anropar samma metod flera gånger (t.ex. i konstruktor och sedan igen i en metod).

**Lösning**:
```dart
// Om setCurrentUser anropas i konstruktor OCH i onAuthStateChanged:
verify(() => mockCacheHelper.setCurrentUser('user-123')).called(1); // Konstruktor
verify(() => mockCacheHelper.setCurrentUser('new-user')).called(1); // onAuthStateChanged

// Eller använd greaterThanOrEqualTo för flexibilitet:
verify(() => mockCacheHelper.setCurrentUser(any())).called(greaterThanOrEqualTo(2));
```

### Problem 6: Hantera nesad JSON-struktur i tester

**Orsak**: Recipe.toJson() returnerar nesad struktur med 'core' objekt.

**Lösning**:
```dart
// Fel ❌ - Recipe har nesad struktur
expect(recipeJson['id'], equals('recipe-id'));

// Rätt ✅ - Åtkomst via core
expect(recipeJson['core']['id'], equals('recipe-id'));
expect(recipeJson['core']['title'], equals('Recipe Title'));
```

### Problem 7: Konfigurationsmönster för komplexa mockar

**Best Practice**: Använd konfigurationsmetoder istället för att stubba getters.

**Lösning**:
```dart
// Skapa mock med konfigurationsmetoder
class MockRecipeService extends Mock implements RecipeService {
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  
  void setRecipeState({required List<Recipe> recipes, bool isLoading = false}) {
    _recipes = recipes;
    _isLoading = isLoading;
  }
  
  @override
  List<Recipe> get recipes => _recipes;
  
  @override
  bool get isLoading => _isLoading;
}

// Användning i test
final mockService = MockRecipeService();
mockService.setRecipeState(
  recipes: [testRecipe1, testRecipe2],
  isLoading: false,
);
```

## Komplett exempel

Här är ett fullständigt exempel som visar alla koncept tillsammans:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// === Produktionskod ===

class User {
  final int id;
  final String name;
  final String email;
  
  User({
    required this.id,
    required this.name,
    required this.email,
  });
}

class AuthService {
  Future<bool> login(String email, String password) async {
    // Riktig implementation
    throw UnimplementedError();
  }
  
  Future<User?> getCurrentUser() async {
    // Riktig implementation
    throw UnimplementedError();
  }
  
  Future<void> logout() async {
    // Riktig implementation
    throw UnimplementedError();
  }
}

class UserRepository {
  Future<void> saveUser(User user) async {
    // Riktig implementation
    throw UnimplementedError();
  }
  
  Future<User?> getUser(int id) async {
    // Riktig implementation
    throw UnimplementedError();
  }
}

class LoginController {
  final AuthService authService;
  final UserRepository userRepository;
  
  LoginController({
    required this.authService,
    required this.userRepository,
  });
  
  Future<bool> performLogin(String email, String password) async {
    try {
      // Försök logga in
      final success = await authService.login(email, password);
      
      if (success) {
        // Hämta användardata
        final user = await authService.getCurrentUser();
        
        if (user != null) {
          // Spara användaren lokalt
          await userRepository.saveUser(user);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Login failed: $e');
      return false;
    }
  }
  
  Future<void> performLogout() async {
    await authService.logout();
  }
}

// === Testkod ===

// Skapa mocks
class MockAuthService extends Mock implements AuthService {}
class MockUserRepository extends Mock implements UserRepository {}

// Fake för User (behövs för any())
class FakeUser extends Fake implements User {}

void main() {
  // Deklarera variabler
  late LoginController controller;
  late MockAuthService mockAuthService;
  late MockUserRepository mockUserRepository;
  
  // Setup som körs innan varje test
  setUp(() {
    mockAuthService = MockAuthService();
    mockUserRepository = MockUserRepository();
    controller = LoginController(
      authService: mockAuthService,
      userRepository: mockUserRepository,
    );
  });
  
  // Registrera fake en gång för alla tester
  setUpAll(() {
    registerFallbackValue(FakeUser());
  });
  
  group('LoginController', () {
    test('Lyckas login sparar användare och returnerar true', () async {
      // Arrange
      final testUser = User(
        id: 1,
        name: 'Test User',
        email: 'test@example.com',
      );
      
      // Stubba alla metoder
      when(() => mockAuthService.login(any(), any()))
          .thenAnswer((_) async => true);
      
      when(() => mockAuthService.getCurrentUser())
          .thenAnswer((_) async => testUser);
      
      when(() => mockUserRepository.saveUser(any()))
          .thenAnswer((_) async {});
      
      // Act
      final result = await controller.performLogin(
        'test@example.com',
        'password123',
      );
      
      // Assert
      expect(result, true);
      
      // Verifiera att alla metoder anropades i rätt ordning
      verifyInOrder([
        () => mockAuthService.login('test@example.com', 'password123'),
        () => mockAuthService.getCurrentUser(),
        () => mockUserRepository.saveUser(testUser),
      ]);
    });
    
    test('Misslyckad login returnerar false', () async {
      // Arrange
      when(() => mockAuthService.login(any(), any()))
          .thenAnswer((_) async => false);
      
      // Act
      final result = await controller.performLogin(
        'wrong@example.com',
        'wrongpass',
      );
      
      // Assert
      expect(result, false);
      
      // Verifiera att saveUser aldrig anropades
      verifyNever(() => mockUserRepository.saveUser(any()));
    });
    
    test('Exception under login returnerar false', () async {
      // Arrange
      when(() => mockAuthService.login(any(), any()))
          .thenThrow(Exception('Nätverksfel'));
      
      // Act
      final result = await controller.performLogin(
        'test@example.com',
        'password',
      );
      
      // Assert
      expect(result, false);
    });
    
    test('Logout anropar auth service', () async {
      // Arrange
      when(() => mockAuthService.logout())
          .thenAnswer((_) async {});
      
      // Act
      await controller.performLogout();
      
      // Assert
      verify(() => mockAuthService.logout()).called(1);
      verifyNoMoreInteractions(mockAuthService);
    });
  });
}
```

## Sammanfattning

Mocktail är ett kraftfullt verktyg för att testa Flutter/Dart-kod. Kom ihåg:

1. **Skapa mocks** genom att utöka `Mock` och implementera din klass
2. **Stubba beteenden** med `when()` och `thenReturn()`/`thenAnswer()`/`thenThrow()`
3. **Verifiera anrop** med `verify()` och dess varianter
4. **Använd argument matchers** som `any()` för flexibilitet
5. **Registrera fallback-värden** för egna typer med `registerFallbackValue()`
6. **Stubba alltid void Future-metoder** explicit

Med denna guide har du en solid grund för att börja använda Mocktail i dina Flutter-projekt. Börja med enkla tester och bygg gradvis upp din förståelse!