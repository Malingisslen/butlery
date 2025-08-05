import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../golden_test_configuration.dart';

/// Simple golden tests for basic screens
void main() {
  configureGoldenTests();
  group('Screen Golden Tests', () {
    testWidgets('Login screen golden test', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _LoginScreen(),
        ),
      );

      await expectLater(
        find.byType(_LoginScreen),
        matchesGoldenFile('goldens/screens/login_screen.png'),
      );
    });

    testWidgets('Home screen golden test', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _HomeScreen(),
        ),
      );

      await expectLater(
        find.byType(_HomeScreen),
        matchesGoldenFile('goldens/screens/home_screen.png'),
      );
    });

    testWidgets('Recipe list screen golden test', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _RecipeListScreen(),
        ),
      );

      await expectLater(
        find.byType(_RecipeListScreen),
        matchesGoldenFile('goldens/screens/recipe_list_screen.png'),
      );
    });
  });
}

/// Simple login screen for golden testing
class _LoginScreen extends StatelessWidget {
  const _LoginScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 80, color: Colors.orange),
            const SizedBox(height: 32),
            const Text(
              'Butlery',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            const TextField(
              decoration: InputDecoration(
                labelText: 'E-postadress',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Lösenord',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Logga in'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {},
              child: const Text('Glömt lösenord?'),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Ny användare? '),
                TextButton(
                  onPressed: () {},
                  child: const Text('Registrera dig'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple home screen for golden testing
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Butlery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Utvalda recept',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 100,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.restaurant, size: 40),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Recept ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '${30 + index * 5} min',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Senaste recept',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            3,
            (index) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.restaurant),
                ),
                title: Text('Recept ${index + 6}'),
                subtitle: Text('${25 + index * 10} min • 4 portioner'),
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Hem',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            label: 'Mina recept',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart),
            label: 'Inköpslista',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// Simple recipe list screen for golden testing
class _RecipeListScreen extends StatelessWidget {
  const _RecipeListScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mina recept'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.restaurant, size: 40),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recept ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${30 + index * 5} min',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.orange),
                        Text(
                          '${4.0 + index * 0.1}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
