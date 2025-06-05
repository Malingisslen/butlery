import 'package:flutter/material.dart';
import '../widgets/main_layout_menu.dart';

class LaggTillReceptView extends StatelessWidget {
  const LaggTillReceptView({super.key});

  void _navigate(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: const TextStyle(fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayoutMenu(
      currentIndex: 1,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              'Hur vill du lägga till ditt recept?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('INSTAGRAM'),
              onPressed: () => _navigate(context, '/franSocialaMedier'),
              style: _buttonStyle(),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.facebook),
              label: const Text('FACEBOOK'),
              onPressed: () => _navigate(context, '/franSocialaMedier'),
              style: _buttonStyle(),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.music_note),
              label: const Text('TIKTOK'),
              onPressed: () => _navigate(context, '/franSocialaMedier'),
              style: _buttonStyle(),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.photo),
              label: const Text('FOTO'),
              onPressed: () => _navigate(context, '/photoImport'),
              style: _buttonStyle(),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('LÄNK'),
              onPressed: () => _navigate(context, '/importViaUrl'),
              style: _buttonStyle(),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('SKRIV SJÄLV'),
              onPressed: () => _navigate(context, '/skrivSjalv'),
              style: _buttonStyle(),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.archive),
              label: const Text('FRÅN BUTLERYS ARKIV'),
              onPressed: () => _navigate(context, '/importFranArkiv'),
              style: _buttonStyle(),
            ),
          ],
        ),
      ),
    );
  }
}
