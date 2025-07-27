import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

// Generate mocks with: dart run build_runner build
@GenerateMocks([FirebaseAuth, User, UserCredential])
import 'firebase_auth_repository_test.mocks.dart';

void main() {
  group('FirebaseAuthRepository', () {
    late FirebaseAuthRepository repository;
    late MockFirebaseAuth mockFirebaseAuth;
    late MockUser mockUser;
    late MockUserCredential mockUserCredential;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockUserCredential = MockUserCredential();
      
      // Inject mock into repository
      repository = FirebaseAuthRepository(firebaseAuth: mockFirebaseAuth);
    });

    group('Authentication Flow', () {
      test('getCurrentUser returns user when authenticated', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-uid');
        when(mockUser.email).thenReturn('test@example.com');
        when(mockUser.displayName).thenReturn('Test User');

        // Act
        final user = repository.currentUser;

        // Assert
        expect(user, isNotNull);
        // Note: In actual test, you'd verify the user properties
      });

      test('getCurrentUser returns null when not authenticated', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act
        final user = repository.currentUser;

        // Assert
        expect(user, isNull);
      });

      test('currentUserId returns correct UID when authenticated', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-uid-123');

        // Act
        final userId = repository.currentUserId;

        // Assert
        expect(userId, equals('test-uid-123'));
      });

      // Note: isAuthenticated property removed - not part of AuthRepository interface
    });

    group('Sign In Operations', () {
      test('login succeeds with valid credentials', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await repository.login(email, password);

        // Assert
        expect(result, isNotNull);
        verify(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).called(1);
      });

      test('login throws on invalid credentials', () async {
        // Arrange
        const email = 'invalid@example.com';
        const password = 'wrongpassword';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found for that email.',
        ));

        // Act & Assert
        expect(
          () => repository.login(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
      });
    });

    group('Sign Up Operations', () {
      test('createUser succeeds with valid data', () async {
        // Arrange
        const email = 'newuser@example.com';
        const password = 'securepassword';
        
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await repository.createUser(email, password);

        // Assert
        expect(result, isNotNull);
        verify(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).called(1);
      });

      test('createUser throws on existing email', () async {
        // Arrange
        const email = 'existing@example.com';
        const password = 'password123';
        
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The account already exists for that email.',
        ));

        // Act & Assert
        expect(
          () => repository.createUser(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
      });
    });

    group('Sign Out Operations', () {
      test('signOut completes successfully', () async {
        // Arrange
        when(mockFirebaseAuth.signOut()).thenAnswer((_) async {});

        // Act
        await repository.signOut();

        // Assert
        verify(mockFirebaseAuth.signOut()).called(1);
      });

      test('signOut handles errors gracefully', () async {
        // Arrange
        when(mockFirebaseAuth.signOut()).thenThrow(Exception('Network error'));

        // Act & Assert
        expect(
          () => repository.signOut(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('User Stream', () {
      test('authStateChanges provides user stream', () {
        // Arrange
        final userStream = Stream<User?>.fromIterable([null, mockUser, null]);
        when(mockFirebaseAuth.authStateChanges()).thenAnswer((_) => userStream);

        // Act
        final stream = repository.authStateChanges();

        // Assert
        expect(stream, isA<Stream<User?>>());
        
        // Test the stream values
        expectLater(
          stream,
          emitsInOrder([null, mockUser, null]),
        );
      });
    });

    group('Password Reset', () {
      test('sendPasswordResetEmail succeeds with valid email', () async {
        // Arrange
        const email = 'user@example.com';
        when(mockFirebaseAuth.sendPasswordResetEmail(email: email))
            .thenAnswer((_) async {});

        // Act
        await repository.sendPasswordResetEmail(email);

        // Assert
        verify(mockFirebaseAuth.sendPasswordResetEmail(email: email)).called(1);
      });

      test('sendPasswordResetEmail throws on invalid email', () async {
        // Arrange
        const email = 'invalid-email';
        when(mockFirebaseAuth.sendPasswordResetEmail(email: email))
            .thenThrow(FirebaseAuthException(
          code: 'invalid-email',
          message: 'The email address is badly formatted.',
        ));

        // Act & Assert
        expect(
          () => repository.sendPasswordResetEmail(email),
          throwsA(isA<FirebaseAuthException>()),
        );
      });
    });

    group('Error Handling', () {
      test('handles network errors appropriately', () async {
        // Arrange
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(FirebaseAuthException(
          code: 'network-request-failed',
          message: 'A network error has occurred.',
        ));

        // Act & Assert
        expect(
          () => repository.login('test@example.com', 'password'),
          throwsA(
            allOf(
              isA<FirebaseAuthException>(),
              predicate<FirebaseAuthException>((e) => e.code == 'network-request-failed'),
            ),
          ),
        );
      });

      test('handles too-many-requests errors appropriately', () async {
        // Arrange
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(FirebaseAuthException(
          code: 'too-many-requests',
          message: 'Too many unsuccessful login attempts.',
        ));

        // Act & Assert
        expect(
          () => repository.login('test@example.com', 'password'),
          throwsA(
            allOf(
              isA<FirebaseAuthException>(),
              predicate<FirebaseAuthException>((e) => e.code == 'too-many-requests'),
            ),
          ),
        );
      });
    });

    group('Repository Interface Compliance', () {
      test('implements AuthRepository interface correctly', () {
        // Act & Assert
        expect(repository, isA<AuthRepository>());
      });

      test('provides all required interface methods', () {
        // This test verifies that all methods from AuthRepository interface
        // are properly implemented. Since Dart has compile-time checking,
        // if this compiles, the interface is correctly implemented.
        
        expect(repository.currentUser, isA<User?>());
        expect(repository.currentUserId, isA<String?>());
        // Note: isAuthenticated removed - not part of AuthRepository interface
        expect(() => repository.authStateChanges(), returnsNormally);
      });
    });
  });
}